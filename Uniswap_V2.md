# UNISWAP V2

This document was to record my personal summaries during the learning process of Uniswap, it's not just a copy, it also is about extending the knowledge point of Uniswap V2, especially focus on the engineering implementation of contract codes.

UniswapV2 is a decentralized exchange protocol that allows users to swap ERC20 tokens without intermediaries. It is built on the Ethereum blockchain and uses an automated market maker (AMM) model to determine the price of tokens.

## Uniswap V2 Upgrade

### Introduction

UniswapV2 is a new version based on the formula, containing many anticipated features.
One of the most important is to support the any ERC20 pairs.
Moreover the ERC20 offers prices oracle functionality, accumulating the relative price of two token at the beginning of each block.This will allow other ETH contract to obtain the time-weighted average price(TWAP) of any two token over any period.
V2 also introduces "flash swaps", allowing users to borrow and use tokens freely on chain requiring only that these token be returned at the end of the transaction, along with a fee.

### New Features

#### ERC20 Pair

Comparing to Uniswap V1 used ETH as a token bridge, UniswapV2 allows liquidity provides to create contracts for any ERC20 pair.
Although v1 simplifies the router process, it imposes a significant costs of liquidity providers. All liquidity providers were exposed ETH price volatility, incurring impermanent loss when the relative prices of their tokens shift against ETH.
Using ETH as a mandatory trading token also increases transaction costs.

#### Price Oracle

The marginal prices(including fee) provided by Uniswap at time t determined by dividing the quantities of token A and token B. When the Uniswap's price is incorrect, the arbitrageurs can profit, meaning Uniswap's token prices follow the market prices.

Uniswap v2 improves the oracle function by recording prices at the first transaction of each block, making price manipulation harder. If the attacker manipulates the price at the end of the block, other arbitrageurs could correct it within the same block unless the attacker fill the block with transactions, mines two consecutive blocks.

#### Flash Swap

Uniswap V2 introduce a feature allowing users to receive and use tokens before paying for them, as long as they complete payment within the same transaction.

The swap method calls an optional user-specified callback contract between transferring tokens and checking out the k value. Once the callback is completed, the contract check the current balance and confirm it satisfies k condition(after deducting fess). If the contract lacks sufficient balance, the transaction is rolled back.

User can return the original tokens without performing a swap. This feature allows anyone to borrow any amount of tokens from pool.

#### Transaction Fee

Uniswap includes a 0.05% protocol fee toggle. If activated, the fee is sent to contract's `feeTo` address.

#### Meta Transactions for Pool Share

Uniswap pool shares natively support meta transactions. This means users can authorize a third parties to transfer their liquidity token without initiating on-chain transactions themselves. Anyone can submit user's signature via permit method, paying gas fee and perform other actions in the same transaction.

## Uniswap Smart Contracts

### Contract Architecture

Uniswap V2 contracts are primarily divided into two categories: core and periphery contract. The core contract contains only most basic trading functionality, with code about 200 lines, ensuring minimization to avoid introducing bugs as user's fund are stored in these contracts. The periphery contract provides various of encapsulated methods tailored to user scenarios, such as supporting ETH, multi-path swap

### Uniswap-V2-Core

**UniswapV2Factory**

A contract is created using `assembly + create2` to manipulate EVM in solidity. As discussed in whitepaper book, the `create2` is mainly used to create the deterministic pair contract addresses, meaning the contract address can be computed directly from two tokens' addresses without on-chain contract queries.

```solidity
// assembly + create2 to store
bytes memory bytecode = type(UniswapV2Pair).creationCode;
bytes32 salt = kecca256(abi.encodePacked(token0, token1))
assembly {
    pair := create2(0, add(bytecode, 32). mload(bytecode), salt)
}

```

**UniswapV2ERC20**

The `permit` method implements `Meta transactions for pool shares` features introduced in the whitepaper. EIP-712 defines the standard for offline signatures, the format of `digest` that a user signs. The signature's content is a authorization by the owner(approve) to allow the contract(spender) to spend certain amount(value) of tokens before the deadline. Application can use original information and generated v, r, s signatures to call pair contract `permit` method to obtain authorization. If the verification passes, the approval is granted.

```solidity
function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
    require(deadline >= block.timestamp, 'UniswapV2: EXPIRED');
    bytes32 digest = keccak256(
        abi.encodePacked(
            '\x19\x01',
            DOMAIN_SEPARATOR,
            keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
        )
    );
    address recoveredAddress = ecrecover(digest, v, r, s);
    require(recoveredAddress != address(0) && recoveredAddress == owner, 'UniswapV2: INVALID_SIGNATURE');
    _approve(owner, spender, value);
}
```

**Uniswap Pair**

The pair contract primarily implements three methods: `mint`, `burn` and `swap`

-   mint(add liquidity)

The `mint` method determines if it is the first time providing liquidity for trading pair, liquidity token is generated based on square root of xy and `MINIMUM_LIQUIDITY` is burned; otherwise the liquidity are minted based on the ratio of transferred token value to current liquidity value.

```solidity
function mint(address to) external lock returns(uint liquidity) {
    // get increase amount of two tokens
    (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // use cache amount to avoid manipulating prices
    uint balance0 = IERC20(token0).balanceOf(address(this));
    uint balance1 = IERC20(token1).balanceOf(address(this));
    uint amount0 = balance0.sub(_reserve0);
    uint amount1 = balance1.sub(_reserve1);
    // check if it's the first time to calculate the liquidity
    uint _totalSupply = totalSupply;
    if (_totalSupply == 0) {
        liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
        _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
    } else {
        liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
    }
    require(liquidity > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED');

    // mint to user
    _mint(to, liquidity);

    // update reserve
    _update(balance0, balance1, _reserve0, _reserve1);
}

```

-   burn(remove liquidity)

```solidity
function burn(address to) external lock returns (uint amount0, uint amount1) {
    (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
    address _token0 = token0;                                // gas savings
    address _token1 = token1;                                // gas savings
    uint balance0 = IERC20(_token0).balanceOf(address(this));
    uint balance1 = IERC20(_token1).balanceOf(address(this));
    // the liquidity is sent from user, because user firstly transfer their lp token
    uint liquidity = balanceOf[address(this)];

    bool feeOn = _mintFee(_reserve0, _reserve1);
    uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
    amount0 = liquidity.mul(balance0) / _totalSupply; // using balances ensures pro-rata distribution
    amount1 = liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution
    require(amount0 > 0 && amount1 > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED');
    _burn(address(this), liquidity);
    _safeTransfer(_token0, to, amount0);
    _safeTransfer(_token1, to, amount1);
    balance0 = IERC20(_token0).balanceOf(address(this));
    balance1 = IERC20(_token1).balanceOf(address(this));

    _update(balance0, balance1, _reserve0, _reserve1);
    if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
    emit Burn(msg.sender, amount0, amount1, to);
}

```

-   swap(exchange)

Since the `swap` method will check the balance to comply with the constant product formula constrain, the contract can first transfer token the user wish to receive, if the user did not transfer tokens to the contract, it is equivalent to borrowing tokens. If using a flash loan, it is necessary to return the borrow token via custom `UniswapV2Call`.

```solidity
function swap(uint amount0out, uint amount1Out, address to, bytes calldata data) external lock {
    // check reasonable amounts, at least one amount is greater than zero and both of them are less than reserves
    require(amount0Out > 0 || amount1Out > 0, 'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT');
    (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
    require(amount0Out < _reserve0 && amount1Out < _reserve1, 'UniswapV2: INSUFFICIENT_LIQUIDITY');

    // assign token address and check address
    uint balance0;
    uint balance1;
    { // scope for _token{0,1}, avoids stack too deep errors
        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, 'UniswapV2: INVALID_TO');
          // transfer user certain amount of token
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
        // if the current call is flash loan, execute the calldata method
        if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
    }

    // calculate the input amount of another token
    uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
    uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;

    // calculate the adjust amount (deduct the fee)
    require(amount0In > 0 || amount1In > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT');
    { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
        uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
        uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
        // make sure the k value satisfies the formula
        require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000**2), 'UniswapV2: K');
    }

    // update reserves and timestamp
    _update(balance0, balance1, _reserve0, _reserve1);
    emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
}
```

-   update(reserves and timestamp)

Update the cumulative price required by price oracle using the cached balance and finally update cached balance to current balance

```solidity
// update reserves and, on the first call per block, price accumulators
function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
    require(balance0 <= uint112(-1) && balance1 <= uint112(-1), 'UniswapV2: OVERFLOW');
    uint32 blockTimestamp = uint32(block.timestamp % 2**32);
    uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
    if (timeElapsed > 0 and _reserve0 != 0 and _reserve1 != 0) {
        // * never overflows, and + overflow is desired
        price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
        price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
    }
    reserve0 = uint112(balance0);
    reserve1 = uint112(balance1);
    blockTimestampLast = blockTimestamp;
    emit Sync(reserve0, reserve1);
}

```

### UniswapV2Router02

#### Library

-   pairFor

Calculate the address of trading pair

```solidity
function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
    (address token0, address token1) = sortTokens(tokenA, tokenB);
    pair = address(uint(keccak256(abi.encodePacked(
            hex'ff',
            factory,
            keccak256(abi.encodePacked(token0, token1)),
            hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
        ))));
}
```

-   getAmountOut

This method calculate how much of token B can be obtained for a given amount of token A

```solidity
function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
    require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
    require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
    uint amountInWithFee = amountIn.mul(997);
    uint numerator = amountInWithFee.mul(reserveOut);
    uint denominator = reserveIn.mul(1000).add(amountInWithFee);
    amountOut = numerator / denominator;
}
```

-   getAmountIn

This method calculate how much of token A is required to obtain a specified amount of token B

```solidity
function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
    require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
    require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
    uint numerator = reserveIn.mul(amountOut).mul(1000);
    uint denominator = reserveOut.sub(amountOut).mul(997);
    amountIn = (numerator / denominator).add(1);
}
```

-   getAmountsOut

This method calculates, for a given amount of first token, how much of last token in a sequence can be obtaining using multiple trading pairs. The first element in `amounts` array represents `amountIn`, and the last element represent the target token.

```solidity
function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
    require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
    amounts = new uint[](path.length);
    amounts[0] = amountIn;
    for (uint i; i < path.length - 1; i++) {
        (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
        amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
    }
}
```

-   getAmountsIn

As opposed to `getAmountsOut`, `getAmountIn` calculate the amount of intermediary token required when a specific amount of target token is desired. It iteratively call `getAmountIn` method

```solidity
function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
    require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
    amounts = new uint[](path.length);
    amounts[amounts.length - 1] = amountOut;
    for (uint i = path.length - 1; i > 0; i--) {
        (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
        amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
    }
}
```

#### ERC20-ERC20

**addLiquidity**

Transactions submitted by users can be packed by miners at an uncertain time, hence the token price at the time of submission differ from the price at the time of transaction packing. `amountMin` parameter controls price fluctuation range to prevent being exploited by miners or bots; similarly, the `deadline` parameter ensures transaction expires after a specific time.

If the token price providing by users add liquidity differs from the actual price, they will only receive LP tokens at a lower exchange rate, with a surplus token contributing to entire pool. `_addLiquidity` helps calculate the optimal exchange rate. If it's the first time adding liquidity, a trading pair will be created first; otherwise the amount of token to inject are calculated by the current pool balance.

**removeLiquidity**

Firstly, liquidity tokens are sent to pair contract. Based on the proportion of received liquidity tokens to total tokens, the corresponding amounts of two tokens represented by liquidity are calculated. After destroying corresponding liquidity tokens, the user receives the corresponding proportion of tokens. If it's lower than user's set minimum expectations, the transaction reverts

**removeLiquidityWithPermit**

Normally, to remove liquidity, user need to perform two operations

-   `approve`: Authorizing router contract to spend their liquidity token
-   `removeLiquidity`: Calling router contract to remove liquidity

Unless maximum token amount was authorized during the first authorization, each liquidity remove would require two interactions, user need to pay gas fees twice. By using `removeLiquidityWithPermit` method, user can authorize Router contract to spend their token through a signature without separately calling `approve`, only need to call remove method once to complete the operation, saving the gas costs. Additionally, since offline signature doesn't incur gas fee, each signature can authorize only a specific amount of tokens, enhancing security.

**swapExactTokenForTokens**

There are two common scenarios for trading:

1. Using a specific amount of token A to exchange maximum amount of token B
2. Receiving a specific amount to token B using the minimum amount of token A
