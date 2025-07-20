// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../library/SafeTransfer.sol";
import "../interface/IDebtToken.sol";
import "../interface/IBscPledgeOracle.sol";
import "../interface/IUniswapV2Router02.sol";
import "../multiSignature/multiSignatureClient.sol";

contract PledgePool is ReentrancyGuard, SafeTransfer, multiSignatureClient {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // default decimal

    uint256 internal constant calDecimal = 1e18;
    // Based on the decimal of the commission and interest
    uint256 internal constant baseDecimal = 1e8;
    uint256 public minAmount = 100e6;
    // one years
    uint256 constant baseYear = 365 days;

    enum PoolState {
        MATCH,
        EXECUTION,
        FINISH,
        LIQUIDATION,
        UNDONE
    }

    PoolState constant defaultChoice = PoolState.MATCH;

    bool public globalPaused = false;
    // pancake swap router
    address public swapRouter;
    // receiving fee address
    address payable public feeAddress;
    // oracle address
    IBscPledgeOracle public oracle;
    // fee
    uint256 public lendFee;
    uint256 public borrowFee;

    // base info of every pool
    struct PoolBaseInfo {
        uint256 settleTime;
        uint256 endTime;
        uint256 interestRate; // interest rate (1e8)
        uint256 maxSupply;
        uint256 lendSupply;
        uint256 borrowSupply; // current actual borrow amount
        uint256 mortgageRate; // mortgage ratio (1e8)
        address lendToken; // lend token address (like BUSD..)
        address borrowToken; // borrow token address (like BTC..)
        PoolState state; // 'MATCH, EXECUTION, FINISH, LIQUIDATION, UNDONE'
        // use token to represent the liquidation amount and the settle amount
        IDebtToken spCoin; // sp_token address (like spBUSD_1..)
        IDebtToken jpCoin; // jp_token address (like jpBTC_1..)
        uint256 autoLiquidateThreshold; // auto liquidate threshold (trigger liquidate threshold)
    }
    // record base info of every pool

    PoolBaseInfo[] public poolBaseInfo;

    // lend amount and borrow amount of every state
    struct PoolDataInfo {
        uint256 settleAmountLend;
        uint256 settleAmountBorrow;
        uint256 finishAmountLend;
        uint256 finishAmountBorrow;
        uint256 liquidationAmountLend;
        uint256 liquidationAmountBorrow;
    }
    // record lend amount and borrow amount of every pool

    PoolDataInfo[] public poolDataInfo;

    // borrow info of every user
    struct BorrowInfo {
        uint256 stakeAmount; // current borrow amount
        uint256 refundAmount; // extra refund amount
        bool hasNoRefund; // default is false, false = not refund, true = refund
        bool hasNoClaim; // default is false, false = not claim, true = claim
    }

    // Info of each user that stakes tokens.  {user.address : {pool.index : user.borrowInfo}}
    mapping(address => mapping(uint256 => BorrowInfo)) public userBorrowInfo;

    // lend info of every usee
    struct LendInfo {
        uint256 stakeAmount; // current borrow amount
        uint256 refundAmount; // extra refund amount
        bool hasNoRefund; // default is false, false = not refund, true = refund
        bool hasNoClaim; // default is false, false = not claim, true = claim
    }

    // Info of each user that stakes tokens.  {user.address : {pool.index : user.lendInfo}}
    mapping(address => mapping(uint256 => LendInfo)) public userLendInfo;

    // events
    // deposit lend event, from is the lender address, token is the lend token address, amount is the lend amount, mintAmount is the mint amount
    event DepositLend(address indexed from, address indexed token, uint256 amount, uint256 mintAmount);
    // refund lend event, from is the refund address, token is the refund token address, refund is the refund amount
    event RefundLend(address indexed from, address indexed token, uint256 refund);
    // claim lend event, from is the claimer address, token is the claim token address, amount is the claim amount
    event ClaimLend(address indexed from, address indexed token, uint256 amount);
    // withdraw lend event, from is the withdrawer address, token is the withdraw token address, amount is the withdraw amount, burnAmount is the burn amount
    event WithdrawLend(address indexed from, address indexed token, uint256 amount, uint256 burnAmount);
    // deposit borrow event, from is the borrower address, token is the borrow token address, amount is the borrow amount, mintAmount is the mint amount
    event DepositBorrow(address indexed from, address indexed token, uint256 amount, uint256 mintAmount);
    // refund borrow event, from is the refund address, token is the refund token address, refund is the refund amount
    event RefundBorrow(address indexed from, address indexed token, uint256 refund);
    // claim borrow event, from is the claimer address, token is the claim token address, amount is the claim amount
    event ClaimBorrow(address indexed from, address indexed token, uint256 amount);
    // withdraw borrow event, from is the withdrawer address, token is the withdraw token address, amount is the withdraw amount, burnAmount is the burn amount
    event WithdrawBorrow(address indexed from, address indexed token, uint256 amount, uint256 burnAmount);
    // swap event, fromCoin is the from token address, toCoin is the to token address, fromValue is the from amount, toValue is the to amount
    event Swap(address indexed fromCoin, address indexed toCoin, uint256 fromValue, uint256 toValue);
    // emergency borrow withdrawal event, from is the withdrawer address, token is the withdraw token address, amount is the withdraw amount
    event EmergencyBorrowWithdrawal(address indexed from, address indexed token, uint256 amount);
    // emergency lend withdrawal event, from is the withdrawer address, token is the withdraw token address, amount is the withdraw amount
    event EmergencyLendWithdrawal(address indexed from, address indexed token, uint256 amount);
    // state change event, pid is the project id, beforeState is the before state, afterState is the after state
    event StateChange(uint256 indexed pid, uint256 indexed beforeState, uint256 indexed afterState);
    // set fee event, newLendFee is the new lend fee, newBorrowFee is the new borrow fee
    event SetFee(uint256 indexed newLendFee, uint256 indexed newBorrowFee);
    // set swap router address event, oldSwapAddress is the old swap address, newSwapAddress is the new swap address
    event SetSwapRouterAddress(address indexed oldSwapAddress, address indexed newSwapAddress);
    // set fee address event, oldFeeAddress is the old fee address, newFeeAddress is the new fee address
    event SetFeeAddress(address indexed oldFeeAddress, address indexed newFeeAddress);
    // set min amount event, oldMinAmount is the old min amount, newMinAmount is the new min amount
    event SetMinAmount(uint256 indexed oldMinAmount, uint256 indexed newMinAmount);

    // _oracle: oracle address used for getting price of every token
    // _swapRouter: swap router address used for swapping token
    // _feeAddress: fee address used for receiving fee
    // _multiSignature: multi signature address used for multi signature
    constructor(address _oracle, address _swapRouter, address payable _feeAddress, address _multiSignature)
        public
        multiSignatureClient(_multiSignature)
    {
        require(_oracle != address(0), "Is zero address");
        require(_swapRouter != address(0), "Is zero address");
        require(_feeAddress != address(0), "Is zero address");

        oracle = IBscPledgeOracle(_oracle);
        swapRouter = _swapRouter;
        feeAddress = _feeAddress;
        lendFee = 0;
        borrowFee = 0;
    }

    /**
     * @dev Set the lend fee and borrow fee
     * @notice Only allow administrators to operate
     */
    function setFee(uint256 _lendFee, uint256 _borrowFee) external validCall {
        lendFee = _lendFee;
        borrowFee = _borrowFee;
        emit SetFee(_lendFee, _borrowFee);
    }

    /**
     * @dev Set swap router address, example pancakeswap or babyswap..
     * @notice Only allow administrators to operate
     */
    function setSwapRouterAddress(address _swapRouter) external validCall {
        require(_swapRouter != address(0), "Is zero address");
        emit SetSwapRouterAddress(swapRouter, _swapRouter);
        swapRouter = _swapRouter;
    }

    /**
     * @dev Set up the address to receive the handling fee
     * @notice Only allow administrators to operate
     */
    function setFeeAddress(address payable _feeAddress) external validCall {
        require(_feeAddress != address(0), "Is zero address");
        emit SetFeeAddress(feeAddress, _feeAddress);
        feeAddress = _feeAddress;
    }

    /**
     * @dev Set the min amount
     */
    function setMinAmount(uint256 _minAmount) external validCall {
        emit SetMinAmount(minAmount, _minAmount);
        minAmount = _minAmount;
    }

    /**
     * @dev Query pool length
     */
    function poolLength() external view returns (uint256) {
        return poolBaseInfo.length;
    }

    /**
     * @dev create a new pool
     * @notice only allow administrators to operate
     * @param _settleTime: settle time
     * @param _endTime: end time
     * @param _interestRate: interest rate
     * @param _maxSupply: max supply
     * @param _mortgageRate: mortgage rate
     *  Can only be called by the owner.
     */
    function createPoolInfo(
        uint256 _settleTime,
        uint256 _endTime,
        uint64 _interestRate,
        uint256 _maxSupply,
        uint256 _mortgageRate,
        address _lendToken,
        address _borrowToken,
        address _spToken,
        address _jpToken,
        uint256 _autoLiquidateThreshold
    ) public validCall {
        // check if the token is set
        require(_endTime > _settleTime, "createPool:end time grate than settle time");
        require(_jpToken != address(0), "createPool:is zero address");
        require(_spToken != address(0), "createPool:is zero address");

        // push the base pool info
        poolBaseInfo.push(
            PoolBaseInfo({
                settleTime: _settleTime,
                endTime: _endTime,
                interestRate: _interestRate,
                maxSupply: _maxSupply,
                lendSupply: 0,
                borrowSupply: 0,
                mortgageRate: _mortgageRate,
                lendToken: _lendToken,
                borrowToken: _borrowToken,
                state: defaultChoice,
                spCoin: IDebtToken(_spToken),
                jpCoin: IDebtToken(_jpToken),
                autoLiquidateThreshold: _autoLiquidateThreshold
            })
        );
        // push the pool data info
        poolDataInfo.push(
            PoolDataInfo({
                settleAmountLend: 0,
                settleAmountBorrow: 0,
                finishAmountLend: 0,
                finishAmountBorrow: 0,
                liquidationAmountLend: 0,
                liquidationAmountBorrow: 0
            })
        );
    }
    /**
     * @dev Get pool state
     * @notice returned is an int integer
     */

    function getPoolState(uint256 _pid) public view returns (uint256) {
        PoolBaseInfo storage pool = poolBaseInfo[_pid];
        return uint256(pool.state);
    }

    /**
     * @dev lender deposit
     * @notice pool state must be MATCH
     * @param _pid is the pool index
     * @param _stakeAmount is the user's stake amount
     */
    function depositLend(uint256 _pid, uint256 _stakeAmount)
        external
        payable
        nonReentrant
        notPause
        timeBefore(_pid)
        stateMatch(_pid)
    {
        // base info
        PoolBaseInfo storage pool = poolBaseInfo[_pid];
        LendInfo storage lendInfo = userLendInfo[msg.sender][_pid];
        // ensure the accumulated stake amount is less than the max supply
        require(_stakeAmount <= (pool.maxSupply).sub(pool.lendSupply), "depositLend: amount over limit");
        // get the payable amount, if the token is erc20, it transfer the amount from msg.sender to contract
        uint256 amount = getPayableAmount(pool.lendToken, _stakeAmount);
        // ensure the amount is greater than the min amount
        require(amount > minAmount, "depositLend: amount less than min amount");
        // update the lend info
        lendInfo.hasNoClaim = false;
        lendInfo.hasNoRefund = false;
        // process native token
        if (pool.lendToken == address(0)) {
            lendInfo.stakeAmount = lendInfo.stakeAmount.add(msg.value);
            pool.lendSupply = pool.lendSupply.add(msg.value);
        } else {
            lendInfo.stakeAmount = lendInfo.stakeAmount.add(_stakeAmount);
            pool.lendSupply = pool.lendSupply.add(_stakeAmount);
        }
        emit DepositLend(msg.sender, pool.lendToken, _stakeAmount, amount);
    }

    /**
     * @dev refund the excess deposit to the lender if the lend supply is greater than the settle amount
     * @notice the pool state must not be MATCH or UNDONE
     * @param _pid is the pool index
     */
    function refundLend(uint256 _pid) external nonReentrant notPause timeAfter(_pid) stateNotMatchUndone(_pid) {
        PoolBaseInfo storage pool = poolBaseInfo[_pid];
        PoolDataInfo storage data = poolDataInfo[_pid];
        LendInfo storage lendInfo = userLendInfo[msg.sender][_pid];
        require(lendInfo.stakeAmount > 0, "refundLend: not pledged");
        require(pool.lendSupply.sub(data.settleAmountLend) > 0, "refundLend: not refund");
        require(!lendInfo.hasNoRefund, "refundLend: repeat refund");

        // calculate the refund amount
        uint256 userShare = lendInfo.stakeAmount.mul(calDecimal).div(pool.lendSupply);
        uint256 refundAmount = (pool.lendSupply.sub(data.settleAmountLend)).mul(userShare).div(calDecimal);

        _redeem(msg.sender, pool.lendToken, refundAmount);
        // update the user info
        lendInfo.hasNoRefund = true;
        lendInfo.refundAmount = lendInfo.refundAmount.add(refundAmount);
        emit RefundLend(msg.sender, pool.lendToken, refundAmount);
    }

    /**
     * @dev lender claim the sp token
     * @notice the pool state must not be MATCH or UNDONE
     * @param _pid is the pool index
     */
    function claimLend(uint256 _pid) external nonReentrant notPause timeAfter(_pid) stateNotMatchUndone(_pid) {
        PoolBaseInfo storage pool = poolBaseInfo[_pid];
        PoolDataInfo storage data = poolDataInfo[_pid];
        LendInfo storage lendInfo = userLendInfo[msg.sender][_pid];
        // ensure the stake amount is greater than 0
        require(lendInfo.stakeAmount > 0, "claimLend: not pledged");
        // ensure the user has not claimed
        require(!lendInfo.hasNoClaim, "claimLend: repeat claim");
        // user share = current stake amount / total amount
        uint256 userShare = lendInfo.stakeAmount.mul(calDecimal).div(pool.lendSupply);
        // totalSpAmount = settleAmountLend
        uint256 totalSpAmount = data.settleAmountLend;
        // user sp amount = totalSpAmount * user share represent the share
        uint256 spAmount = totalSpAmount.mul(userShare).div(calDecimal);
        // mint the sp token
        pool.spCoin.mint(msg.sender, spAmount);
        // update the claim flag
        lendInfo.hasNoClaim = true;
        emit ClaimLend(msg.sender, pool.borrowToken, spAmount);
    }

    /**
     * @dev lender withdraw the principal and interest
     * @notice the pool state must be FINISH or LIQUIDATION
     * @param _pid is the pool index
     * @param _spAmount is the amount of sp token to burn
     */
    function withdrawLend(uint256 _pid, uint256 _spAmount)
        external
        nonReentrant
        notPause
        stateFinishLiquidation(_pid)
    {
        PoolBaseInfo storage pool = poolBaseInfo[_pid];
        PoolDataInfo storage data = poolDataInfo[_pid];
        // ensure the sp amount is greater than 0
        require(_spAmount > 0, "withdrawLend: withdraw amount is zero");
        // burn the sp token
        pool.spCoin.burn(msg.sender, _spAmount);
        // calculate the sp share
        uint256 totalSpAmount = data.settleAmountLend;
        // sp share = _spAmount/totalSpAmount
        uint256 spShare = _spAmount.mul(calDecimal).div(totalSpAmount);
        // finish state: use data.settleAmount
        if (pool.state == PoolState.FINISH) {
            // ensure the current time is greater than the end time
            require(block.timestamp > pool.endTime, "withdrawLend: less than end time");
            // redeem amount = finishAmountLend * sp share
            uint256 redeemAmount = data.finishAmountLend.mul(spShare).div(calDecimal);
            // redeem the amount to the user
            _redeem(msg.sender, pool.lendToken, redeemAmount);
            emit WithdrawLend(msg.sender, pool.lendToken, redeemAmount, _spAmount);
        }
        // liquidation state: use data.liquidationAmountBorrow
        if (pool.state == PoolState.LIQUIDATION) {
            // ensure the current time is greater than the settle time
            require(block.timestamp > pool.settleTime, "withdrawLend: less than settle time");
            // redeem amount = liquidationAmountLend * sp share
            uint256 redeemAmount = data.liquidationAmountLend.mul(spShare).div(calDecimal);
            // redeem the amount to the user
            _redeem(msg.sender, pool.lendToken, redeemAmount);
            emit WithdrawLend(msg.sender, pool.lendToken, redeemAmount, _spAmount);
        }
    }

    /**
     * @dev emergency withdraw user's all lend token
     * @notice the pool state must be UNDONE
     * @param _pid is the pool index
     */
    function emergencyLendWithdrawal(uint256 _pid) external nonReentrant notPause stateUndone(_pid) {
        PoolBaseInfo storage pool = poolBaseInfo[_pid];
        // ensure the lend supply is greater than 0
        require(pool.lendSupply > 0, "emergencLend: not withdrawal");
        // get the lend info
        LendInfo storage lendInfo = userLendInfo[msg.sender][_pid];
        // ensure the stake amount is greater than 0
        require(lendInfo.stakeAmount > 0, "refundLend: not pledged");
        // ensure the user has not refunded
        require(!lendInfo.hasNoRefund, "refundLend: again refund");
        // redeem the amount to the user
        _redeem(msg.sender, pool.lendToken, lendInfo.stakeAmount);
        // update the user info
        lendInfo.hasNoRefund = true;
        emit EmergencyLendWithdrawal(msg.sender, pool.lendToken, lendInfo.stakeAmount);
    }

    /**
     * @dev borrower deposit
     * @param _pid is the pool index
     * @param _stakeAmount is the user's stake amount
     */
    function depositBorrow(uint256 _pid, uint256 _stakeAmount)
        external
        payable
        nonReentrant
        notPause
        timeBefore(_pid)
        stateMatch(_pid)
    {
        PoolBaseInfo storage pool = poolBaseInfo[_pid];
        BorrowInfo storage borrowInfo = userBorrowInfo[msg.sender][_pid];
        // get the payable amount
        uint256 amount = getPayableAmount(pool.borrowToken, _stakeAmount);
        require(amount > 0, "depositBorrow: deposit amount is zero");
        borrowInfo.hasNoClaim = false;
        borrowInfo.hasNoRefund = false;
        // process native token
        if (pool.borrowToken == address(0)) {
            borrowInfo.stakeAmount = borrowInfo.stakeAmount.add(msg.value);
            pool.borrowSupply = pool.borrowSupply.add(msg.value);
        } else {
            // process erc20 token
            borrowInfo.stakeAmount = borrowInfo.stakeAmount.add(_stakeAmount);
            pool.borrowSupply = pool.borrowSupply.add(_stakeAmount);
        }
        emit DepositBorrow(msg.sender, pool.borrowToken, _stakeAmount, amount);
    }

    /**
     * @dev refund the excess deposit to the borrower if the borrow supply is greater than the settle amount
     * @notice the pool state must not be MATCH or UNDONE
     * @param _pid is the pool index
     */
    function refundBorrow(uint256 _pid) external nonReentrant notPause timeAfter(_pid) stateNotMatchUndone(_pid) {
        PoolBaseInfo storage pool = poolBaseInfo[_pid];
        PoolDataInfo storage data = poolDataInfo[_pid];
        BorrowInfo storage borrowInfo = userBorrowInfo[msg.sender][_pid];

        // ensure the borrow supply is greater than the settle amount
        require(pool.borrowSupply.sub(data.settleAmountBorrow) > 0, "refundBorrow: not refund");
        require(borrowInfo.stakeAmount > 0, "refundBorrow: not pledged");
        require(!borrowInfo.hasNoRefund, "refundBorrow: again refund");
        // calculate the user share
        uint256 userShare = borrowInfo.stakeAmount.mul(calDecimal).div(pool.borrowSupply);
        uint256 refundAmount = (pool.borrowSupply.sub(data.settleAmountBorrow)).mul(userShare).div(calDecimal);
        _redeem(msg.sender, pool.borrowToken, refundAmount);
        borrowInfo.refundAmount = borrowInfo.refundAmount.add(refundAmount);
        borrowInfo.hasNoRefund = true;
        emit RefundBorrow(msg.sender, pool.borrowToken, refundAmount);
    }

    /**
     * @dev borrower want to borrow the lend token, give him specific jp token (debt) and borrow amount(lend token)
     * @notice the pool state must not be MATCH or UNDONE
     * @param _pid is the pool index
     */
    function claimBorrow(uint256 _pid) external nonReentrant notPause timeAfter(_pid) stateNotMatchUndone(_pid) {
        PoolBaseInfo storage pool = poolBaseInfo[_pid];
        PoolDataInfo storage data = poolDataInfo[_pid];
        BorrowInfo storage borrowInfo = userBorrowInfo[msg.sender][_pid];
        require(borrowInfo.stakeAmount > 0, "claimBorrow: not pledged");
        require(!borrowInfo.hasNoClaim, "claimBorrow: again claim");

        // user share is represented by the ratio of user's stake amount divided by borrow supply
        uint256 userShare = borrowInfo.stakeAmount.mul(calDecimal).div(pool.borrowSupply);
        // because the mortgage rate, the amount of jp token is increased
        uint256 totalJpAmount = data.settleAmountLend.mul(pool.mortgageRate).div(baseDecimal);
        uint256 jpAmount = totalJpAmount.mul(userShare).div(calDecimal);
        // mint the jp token
        pool.jpCoin.mint(msg.sender, jpAmount);
        // borrow amount = settleAmountLend * user share
        uint256 borrowAmount = data.settleAmountLend.mul(userShare).div(calDecimal);
        _redeem(msg.sender, pool.lendToken, borrowAmount);
        // update the user info
        borrowInfo.hasNoClaim = true;
        emit ClaimBorrow(msg.sender, pool.borrowToken, jpAmount);
    }

    /**
     * @dev borrower withdraw the remaining margin, this function first checks if the withdrawal amount is greater than 0, then burns the corresponding amount of JP token. Then, it calculates the share of JP token, and performs the corresponding operation according to the state of the pool (finish or liquidation). If the pool state is finish, it checks if the current time is greater than the end time, then calculates the redemption amount and redeems it. If the pool state is liquidation, it checks if the current time is greater than the match time, then calculates the redemption amount and redeems it.
     * @param _pid is the pool index
     * @param _jpAmount is the amount of jp token to burn
     */
    function withdrawBorrow(uint256 _pid, uint256 _jpAmount)
        external
        nonReentrant
        notPause
        stateFinishLiquidation(_pid)
    {
        PoolBaseInfo storage pool = poolBaseInfo[_pid];
        PoolDataInfo storage data = poolDataInfo[_pid];
        require(_jpAmount > 0, "withdrawBorrow: withdraw amount is zero");
        // burn the jp token
        pool.jpCoin.burn(msg.sender, _jpAmount);
        // calculate the jp share
        uint256 totalJpAmount = data.settleAmountLend.mul(pool.mortgageRate).div(baseDecimal);
        uint256 jpShare = _jpAmount.mul(calDecimal).div(totalJpAmount);
        // finish state
        if (pool.state == PoolState.FINISH) {
            // ensure the current time is greater than the end time
            require(block.timestamp > pool.endTime, "withdrawBorrow: less than end time");
            uint256 redeemAmount = jpShare.mul(data.finishAmountBorrow).div(calDecimal);
            _redeem(msg.sender, pool.borrowToken, redeemAmount);
            emit WithdrawBorrow(msg.sender, pool.borrowToken, _jpAmount, redeemAmount);
        }
        // liquidation state
        if (pool.state == PoolState.LIQUIDATION) {
            // ensure the current time is greater than the settle time
            require(block.timestamp > pool.settleTime, "withdrawBorrow: less than match time");
            uint256 redeemAmount = jpShare.mul(data.liquidationAmountBorrow).div(calDecimal);
            _redeem(msg.sender, pool.borrowToken, redeemAmount);
            emit WithdrawBorrow(msg.sender, pool.borrowToken, _jpAmount, redeemAmount);
        }
    }
    /**
     * @dev emergency withdraw the borrow token
     * @notice in some extreme cases, if the total deposit is 0 or the total margin is 0, the borrower can perform an emergency withdrawal. First, the code will get the basic information of the pool and the borrow information of the borrower, then check if the borrow supply and the stake amount of the borrower are greater than 0, and whether the borrower has already performed a refund. If these conditions are met, the redemption operation will be performed, and the borrower will be marked as having refunded. Finally, an emergency borrow withdrawal event will be triggered.
     * @param _pid index of pool
     */

    function emergencyBorrowWithdrawal(uint256 _pid) external nonReentrant notPause stateUndone(_pid) {
        PoolBaseInfo storage pool = poolBaseInfo[_pid];
        require(pool.borrowSupply > 0, "emergencyBorrow: not withdrawal");
        // get the borrow info
        BorrowInfo storage borrowInfo = userBorrowInfo[msg.sender][_pid];
        // ensure the stake amount is greater than 0
        require(borrowInfo.stakeAmount > 0, "refundBorrow: not pledged");
        // ensure the user has not refunded
        require(!borrowInfo.hasNoRefund, "refundBorrow: again refund");
        // redeem the amount to the user
        _redeem(msg.sender, pool.borrowToken, borrowInfo.stakeAmount);
        // update the user info
        borrowInfo.hasNoRefund = true;
        // emit the event
        emit EmergencyBorrowWithdrawal(msg.sender, pool.borrowToken, borrowInfo.stakeAmount);
    }

    /**
     * @dev Can it be settle
     * @param _pid is pool index
     */
    function checkoutSettle(uint256 _pid) public view returns (bool) {
        return block.timestamp > poolBaseInfo[_pid].settleTime;
    }

    /**
     * @dev settle the pool
     * @param _pid is the pool index
     */
    function settle(uint256 _pid) public validCall {
        PoolBaseInfo storage pool = poolBaseInfo[_pid];
        PoolDataInfo storage data = poolDataInfo[_pid];
        // check time
        require(block.timestamp > poolBaseInfo[_pid].settleTime, "settle: less than settle time");
        // check state
        require(pool.state == PoolState.MATCH, "settle: pool state must be match");
        if (pool.lendSupply > 0 && pool.borrowSupply > 0) {
            // get the price
            uint256[2] memory prices = getUnderlyingPriceView(_pid);
            // total value = borrow supply * borrow price
            uint256 totalValue = pool.borrowSupply.mul(prices[1].mul(calDecimal).div(prices[0])).div(calDecimal);
            // convert to stable coin value
            uint256 actualValue = totalValue.mul(baseDecimal).div(pool.mortgageRate);
            if (pool.lendSupply > actualValue) {
                // we need to use actual borrow value to calculate
                data.settleAmountLend = actualValue;
                data.settleAmountBorrow = pool.borrowSupply;
            } else {
                // we need to use actual lend value to calculate
                data.settleAmountLend = pool.lendSupply;
                data.settleAmountBorrow =
                    pool.lendSupply∑.mul(pool.mortgageRate).div(prices[1].mul(baseDecimal).div(prices[0]));
            }
            // update the pool state
            pool.state = PoolState.EXECUTION;
            // emit the event
            emit StateChange(_pid, uint256(PoolState.MATCH), uint256(PoolState.EXECUTION));
        } else {
            // extreme case, borrow or lend is 0
            pool.state = PoolState.UNDONE;
            data.settleAmountLend = pool.lendSupply;
            data.settleAmountBorrow = pool.borrowSupply;
            // emit the event
            emit StateChange(_pid, uint256(PoolState.MATCH), uint256(PoolState.UNDONE));
        }
    }

    /**
     * @dev Can it be finish
     * @param _pid is pool index
     */
    function checkoutFinish(uint256 _pid) public view returns (bool) {
        return block.timestamp > poolBaseInfo[_pid].endTime;
    }

    /**
     * @dev finish a pool, including calculating interest, executing swap, redeeming fees and updating pool state
     * @param _pid is the pool index
     */
    function finish(uint256 _pid) public validCall {
        PoolBaseInfo storage pool = poolBaseInfo[_pid];
        PoolDataInfo storage data = poolDataInfo[_pid];
        require(block.timestamp > poolBaseInfo[_pid].endTime, "finish: less than end time");
        require(pool.state == PoolState.EXECUTION, "finish: pool state must be execution");

        // get the token
        (address token0, address token1) = (pool.borrowToken, pool.lendToken);

        // calculate the time ratio = ((end time - settle time) * base decimal) / 365 days
        uint256 timeRatio = ((pool.endTime.sub(pool.settleTime)).mul(baseDecimal)).div(baseYear);

        // calculate the interest = time ratio * interest rate * settle amount lend
        uint256 interest = timeRatio.mul(pool.interestRate.mul(data.settleAmountLend)).div(1e16);

        // calculate the lend amount = settle amount lend + interest
        uint256 lendAmount = data.settleAmountLend.add(interest);

        // calculate the sell amount = lend amount * (1 + lend fee)
        uint256 sellAmount = lendAmount.mul(lendFee.add(baseDecimal)).div(baseDecimal);

        // use uniswap to calculate how much token0 is need to sell
        // amountSell: the actual amount of borrow token to sell, amountIn: the actual amount of lend token to be received
        (uint256 amountSell, uint256 amountIn) = _sellExactAmount(swapRouter, token0, token1, sellAmount);

        // ensure the received lend token amount is greater than or equal to the lend amount
        require(amountIn >= lendAmount, "finish: Slippage is too high");

        if (amountIn > lendAmount) {
            uint256 feeAmount = amountIn.sub(lendAmount);
            // redeem the fee
            _redeem(feeAddress, pool.lendToken, feeAmount);
            data.finishAmountLend = amountIn.sub(feeAmount);
        } else {
            data.finishAmountLend = amountIn;
        }

        // substrate the redeem borrow fee
        uint256 remainNowAmount = data.settleAmountBorrow.sub(amountSell);
        uint256 remainBorrowAmount = redeemFees(borrowFee, pool.borrowToken, remainNowAmount);
        data.finishAmountBorrow = remainBorrowAmount;

        // update the pool state to finish
        pool.state = PoolState.FINISH;

        // emit the event
        emit StateChange(_pid, uint256(PoolState.EXECUTION), uint256(PoolState.FINISH));
    }

    /**
     * @dev check the liquidate condition, it first gets the basic information and data information of the pool, then calculates the current value of the margin and the liquidation threshold, finally compares these two values, if the current value of the margin is less than the liquidation threshold, then the liquidation condition is met, the function returns true, otherwise returns false.
     * @param _pid is the pool index
     */
    function checkoutLiquidate(uint256 _pid) external view returns (bool) {
        PoolBaseInfo storage pool = poolBaseInfo[_pid];
        PoolDataInfo storage data = poolDataInfo[_pid];
        // get the price
        uint256[2] memory prices = getUnderlyingPriceView(_pid);
        // current value of margin = margin amount * margin price
        uint256 borrowValueNow = data.settleAmountBorrow.mul(prices[1].mul(calDecimal).div(prices[0])).div(calDecimal);
        // liquidation threshold = settleAmountLend*(1+autoLiquidateThreshold)
        uint256 valueThreshold =
            data.settleAmountLend.mul(baseDecimal.add(pool.autoLiquidateThreshold)).div(baseDecimal);
        return borrowValueNow < valueThreshold;
    }

    /**
     * @dev liquidate the pool
     * @param _pid is the pool index
     */
    function liquidate(uint256 _pid) public validCall {
        PoolDataInfo storage data = poolDataInfo[_pid];
        PoolBaseInfo storage pool = poolBaseInfo[_pid];
        require(block.timestamp > pool.settleTime, "liquidate: less than settle time");
        require(pool.state == PoolState.EXECUTION, "liquidate: pool state must be execution");

        // interest = time ratio * interest rate * settle amount lend
        (address token0, address token1) = (pool.borrowToken, pool.lendToken);
        uint256 timeRatio = ((pool.endTime.sub(pool.settleTime)).mul(baseDecimal)).div(baseYear);
        uint256 interest = timeRatio.mul(pool.interestRate.mul(data.settleAmountLend)).div(1e16);
        // lend amount = settle amount lend + interest
        uint256 lendAmount = data.settleAmountLend.add(interest);
        // sell amount = lend amount * (1 + lend fee)
        uint256 sellAmount = lendAmount.mul(lendFee.add(baseDecimal)).div(baseDecimal);
        (uint256 amountSell, uint256 amountIn) = _sellExactAmount(swapRouter, token0, token1, sellAmount);
        // there may be slippage, amountIn - lendAmount < 0;
        if (amountIn > lendAmount) {
            uint256 feeAmount = amountIn.sub(lendAmount);
            // redeem the fee
            _redeem(feeAddress, pool.lendToken, feeAmount);
            data.liquidationAmountLend = amountIn.sub(feeAmount);
        } else {
            data.liquidationAmountLend = amountIn;
        }
        // liquidationAmountBorrow
        uint256 remainNowAmount = data.settleAmountBorrow.sub(amountSell);
        uint256 remainBorrowAmount = redeemFees(borrowFee, pool.borrowToken, remainNowAmount);
        data.liquidationAmountBorrow = remainBorrowAmount;
        // update the pool state
        pool.state = PoolState.LIQUIDATION;
        emit StateChange(_pid, uint256(PoolState.EXECUTION), uint256(PoolState.LIQUIDATION));
    }

    /**
     * @dev calculate the fee and redeem the fee
     */
    function redeemFees(uint256 feeRatio, address token, uint256 amount) internal returns (uint256) {
        // calculate the fee = amount * fee ratio / base decimal
        uint256 fee = amount.mul(feeRatio).div(baseDecimal);
        // if the fee is greater than 0
        if (fee > 0) {
            // redeem the fee
            _redeem(feeAddress, token, fee);
        }
        // return the amount minus the fee
        return amount.sub(fee);
    }

    /**
     * @dev Get the swap path
     */
    function _getSwapPath(address _swapRouter, address token0, address token1)
        internal
        pure
        returns (address[] memory path)
    {
        IUniswapV2Router02 IUniswap = IUniswapV2Router02(_swapRouter);
        path = new address[](2);
        path[0] = token0 == address(0) ? IUniswap.WETH() : token0;
        path[1] = token1 == address(0) ? IUniswap.WETH() : token1;
    }

    /**
     * @dev Get input based on output
     */
    function _getAmountIn(address _swapRouter, address token0, address token1, uint256 amountOut)
        internal
        view
        returns (uint256)
    {
        IUniswapV2Router02 IUniswap = IUniswapV2Router02(_swapRouter);
        address[] memory path = _getSwapPath(swapRouter, token0, token1);
        uint256[] memory amounts = IUniswap.getAmountsIn(amountOut, path);
        return amounts[0];
    }

    /**
     * @param _swapRouter is the swap router address
     * @param token0 is the borrow token address
     * @param token1 is the lend token address
     * @param amountout is the amount of token1 to output
     * 
     * @return (amountSell, amountIn)
     */
    function _sellExactAmount(address _swapRouter, address token0, address token1, uint256 amountout)
        internal
        returns (uint256, uint256)
    {
        uint256 amountSell = amountout > 0 ? _getAmountIn(swapRouter, token0, token1, amountout) : 0;
        return (amountSell, _swap(_swapRouter, token0, token1, amountSell));
    }

    /**
     * @dev Swap
     */
    function _swap(address _swapRouter, address token0, address token1, uint256 amount0) internal returns (uint256) {
        if (token0 != address(0)) {
            _safeApprove(token0, address(_swapRouter), uint256(-1));
        }
        if (token1 != address(0)) {
            _safeApprove(token1, address(_swapRouter), uint256(-1));
        }
        IUniswapV2Router02 IUniswap = IUniswapV2Router02(_swapRouter);
        address[] memory path = _getSwapPath(_swapRouter, token0, token1);
        uint256[] memory amounts;
        if (token0 == address(0)) {
            amounts = IUniswap.swapExactETHForTokens{value: amount0}(0, path, address(this), now + 30);
        } else if (token1 == address(0)) {
            amounts = IUniswap.swapExactTokensForETH(amount0, 0, path, address(this), now + 30);
        } else {
            amounts = IUniswap.swapExactTokensForTokens(amount0, 0, path, address(this), now + 30);
        }
        emit Swap(token0, token1, amounts[0], amounts[amounts.length - 1]);
        return amounts[amounts.length - 1];
    }

    /**
     * @dev Approve
     */
    function _safeApprove(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "!safeApprove");
    }

    /**
     * @dev get the latest price from the oracle
     */
    function getUnderlyingPriceView(uint256 _pid) public view returns (uint256[2] memory) {
        PoolBaseInfo storage pool = poolBaseInfo[_pid];
        uint256[] memory assets = new uint256[](2);
        // add the token to the asset array
        assets[0] = uint256(pool.lendToken);
        assets[1] = uint256(pool.borrowToken);
        // get the price from the oracle
        uint256[] memory prices = oracle.getPrices(assets);
        // return the price array
        return [prices[0], prices[1]];
    }

    /**
     * @dev set Pause
     */
    function setPause() public validCall {
        globalPaused = !globalPaused;
    }

    modifier notPause() {
        require(globalPaused == false, "Stake has been suspended");
        _;
    }

    modifier timeBefore(uint256 _pid) {
        require(block.timestamp < poolBaseInfo[_pid].settleTime, "Less than this time");
        _;
    }

    modifier timeAfter(uint256 _pid) {
        require(block.timestamp > poolBaseInfo[_pid].settleTime, "Greate than this time");
        _;
    }

    modifier stateMatch(uint256 _pid) {
        require(poolBaseInfo[_pid].state == PoolState.MATCH, "state: Pool status is not equal to match");
        _;
    }

    modifier stateNotMatchUndone(uint256 _pid) {
        require(
            poolBaseInfo[_pid].state == PoolState.EXECUTION || poolBaseInfo[_pid].state == PoolState.FINISH
                || poolBaseInfo[_pid].state == PoolState.LIQUIDATION,
            "state: not match and undone"
        );
        _;
    }

    modifier stateFinishLiquidation(uint256 _pid) {
        require(
            poolBaseInfo[_pid].state == PoolState.FINISH || poolBaseInfo[_pid].state == PoolState.LIQUIDATION,
            "state: finish liquidation"
        );
        _;
    }

    modifier stateUndone(uint256 _pid) {
        require(poolBaseInfo[_pid].state == PoolState.UNDONE, "state: state must be undone");
        _;
    }
}
