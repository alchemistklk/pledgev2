# PledgeV2 - Decentralized Lending Platform

## Overview

PledgeV2 is a decentralized lending and borrowing platform that built on Solidity that collateralized lending between users. This platform enables users to lend assets to earn interest and borrow assets by providing collateral with sophisticated risk management and governance mechanisms.

## Architecture Overview

The project is organized into three main architecture components:

1. Multi-Signature Governance - Secure administrative control
2. Pledge Pool System - Core lending/borrowing functionality
3. External Interface Layers - Standardized contract interactions


## 1. Multi-Signature Module

Provides secure administrative control through multi-signature governance, ensuring that critical operations require multiple administrators to approve to prevent single points of failure.

### Components

- `multi-signature.sol` - Core multi-signature contract
  - `mapping(bytes32 => signatureInfo[]) public signatureMap;` - store the (user + address) as key to record the right of accessing
  - `address[] public signatureOwners;` - store the owners of the multi-signature, used to check if the caller is in the ownerList
  - `uint256 public threshold;` - the threshold of the multi-signature

```solidity
function getValidSignature(bytes32 msghash, uint256 lastIndex) external view returns (bool) {
    // get the current signature situation
    signatureInfo[] storage info = signatureMap[msghash];
    // once the signature is enough, return the index + 1
    for (uint256 i = lastIndex; i < info.length; i++) {
        if (info[i].signatures.length >= threshold) {
            return i + 1;
        }
    }
    return 0;
}
```

- `multiSignatureClient.sol` - Parent contract to establish connection between client and multi-signature governance system.

```solidity
constructor(address multiSignature) public {
    require(multiSignature != address(0), "Multi-Signature : Multi-Signature address is zero!");
    // save the multi-signature address to the client contract
    saveValue(multiSignaturePosition, uint256(multiSignature));
}
```

```solidity
// position: use constant string to calculate the position of the value in the contract storage
function saveValue(uint256 position, uint256 value) internal {
    // use inline assembly to provide direct access to contract storage
    assembly {
        sstore(position, value)
    }
}
```

### deploy
address: 0x9Ed445329D8465C2C56497102eC80BfDb8952e8B


## 2. Pledge Pool System

Implements the core lending and borrowing functionality with sophisticated collateral management, automated liquidation, and risk management


### Components

**Pool Management**
- **Pool States**: MATCH → EXECUTION → FINISH → LIQUIDATION → UNDONE
- **Pool Configuration**: Interest rates, collateral ratios, token pairs, settlement times
- **Supply Tracking**: Monitors lend and borrow supply for each pool

```solidity
struct PoolBaseInfo {
    uint256 settleTime;         // Settlement timestamp
    uint256 endTime;            // Pool expiration
    uint256 interestRate;       // interest rate
    uint256 maxSupply;          // Maximum pool capacity
    uint256 mortgageRate;       // Collateral ratio
    address lendToken;          // Asset being lent
    address borrowToken;        // Collateral asset
    PoolState state;            // Current pool state
    IDebtToken spCoin;          // Lender position token
    IDebtToken jpCoin;          // Borrower position token
    uint256 autoLiquidateThreshold; // Liquidation trigger
}
```

**Pool Data**

```solidity
// lend amount and borrow amount of every state
struct PoolDataInfo {
    uint256 settleAmountLend;
    uint256 settleAmountBorrow;
    uint256 finishAmountLend;
    uint256 finishAmountBorrow;
    uint256 liquidationAmountLend;
    uint256 liquidationAmountBorrow;
}
```


**User Operations**:
- **Lend**:
    - `depositLend()`: User deposit lend token to the pool including native token(ETH) and erc20 token. we need to increase user's stake amount and pool's lend supply.
    - `refundLend()`: Refund the excess deposit to lender based on the user's share which is calculated by user's lend stake amount and pool's settle lend amount.
    - `claimLend()`: User claim his all lend stake amount of this pool and use `spCoin` to represent his share of the pool.
    - `withdrawLend()`: User withdraw `_spAmount` of lend token from the pool. If the state is `FINISH`, we need to use `finishAmountLend` to act as total amount, otherwise we use `liquidationAmountLend`
    - `emergencyLendWithdrawal`: User withdraw all stake amount of lend token to his own address.
- **Borrow**:
    - `depositBorrow()`: User borrow borrow token by depositing `_stakeAmount` of his lend token.
    - `refundBorrow()`: Refund the excess deposit to the borrower based on the user's share which is calculated by user's stake amount divide by pool's borrow supply.
    - `claimBorrow()`: User claim the borrow token which amount is calculated by user's stake amount divide by borrow total supply generated share. Mint the `jpToken` a kind of debt token to represent his share of the pool.Then transfer the user `borrowAmount` borrow token.
    - `withdrawBorrow()`: User redeem the borrow token with `_jaAmount` of `jpToken`. When we calculate the amount of borrow token, we need to specify the state of pool, because different state has different borrow amount.
    - `emergencyBorrowWithdrawal()`: User withdraw all stake amount of borrow token to his own address.

**Risk Management**:

- **settle**: We need to switch the state of pool from `MATCH` to `EXECUTION` when the pool is ready to settle. The settle amount of lend token and borrow token need to settled. The `totalValue` of this pool is determined by borrow supply multiply the ration between borrow price and lend price. This result can protect the lender from the risk of the borrow token price drop drastically. We get the `settleAmountLend` and `settleAmountBorrow`

- **finish**: 
  1. When the pool is finished, we need to calculate the interest. 
  2. When we need to calculate the incentive of the pool, we need to change the collateral token to the lend token, how can we swap the tokens, we need to use `uniswap` to swap. 
    2.1 The challenge is determining how many collateral to sell to get the exact amount to repay the lend token and its interest. So under this situation, the token output amount is fixed, we need to calculate the `amountIn` of the collateral token. 
    2.2 There are two amount of token's amount, the first one is `amountSell`, which is the expected amount based on current liquidity ratios, the second one is real output amount, which is reduced by considering the slippage.
  3. We need to ensure we get the enough amount of lend token to repay user's deposit and his own interest, the remaining amount of borrow token we also need to store as `finishAmountBorrow`


- **liquidation**:
  1. liquidation is similar to finish, but we can't make sure the amountIn is enough to repay the  user's deposit and his own interest.









