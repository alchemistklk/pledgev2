# Uniswap Explanation

## Introduction

What the uniswap is and the difference between Uniswap and traditional order book model

Uniswap is a decentralized automated market maker that allows anyone to swap token A for token B. Automated market maker works different from a traditional order book model. The core principle that differentiates an automated market maker(Uniswap) from a traditional order book is that the former runs permissionless code on the blockchain allowing anyone to participate

## System Components

### Overview

What's really happening when we are doing a simple swap?
At a basic level, you're interacting with a smart contract that `holds` reserves of two different tokens. So, if you're buying USDC with WETH, you're increasing the supply of WETH in the pool and reducing the supply of USDC, therefore, increasing the relative price of USDC VS WETH.

In Uniswap V2, every pool has ERC20/ERC20 pair. This approach provides more flexibility to liquidity as they don't need to rely 100% on ETH.

### Protocol Participants

Uniswap works by providing incentives to different participants to work with the system in order for them to profit. The main participants of the system are:

1. Traders: Traders can perform several action in the system

    1. Speculating on the price of an asset
    2. Arbitrage software
    3. Basic swap functionality.

2. Liquidity Providers(LPS): LPs provides the liquidity to the token pools. As reward, they get the transaction fee.
3. Developers

### Fees

Uniswap charges a flat 0.3% fee per trade. We will see how this is calculated in the future sections. The fee goes to the liquidity providers, and this is to reward people for their liquidity. The protocol can also trigger a change that would give 0.5% to the Uniswap team, and the part of fee would be discounted from LPs instead of traders.

### Basic Components

There are three basic components that we need understand in order to have deep knowledge of Uniswap(most of the Defi protocols): They are `constant product formula`, `arbitrage`, and `impermanent loss`.

#### Constant Product Formula

The constant product formula is the automated market algorithm that powers the Uniswap protocol. This formula simply states that the invariant `k` must remain unchanged regarding outflow/inflow of `x` and `y`. In other words, you can change the value of `x` and `y` whatever you want, as long as `k` remains the same. `x` and `y` are the reserves of tokens in the pool.

```solidity
require(
    balance0Adjusted.mul(balance1Adjusted) >= uint256(_reserve0).mul(reserve1).mul(1000**2),
    "UniswapV2: K"
)
```

`balance0Adjusted`: Reserves of `x` after the trader sends TokenX to the pool minus 0.3% of the amount sent.
`balance1Adjusted`: Reserves of `y` after the tokenY is sent to trader from the pool
`_reserve0`: Reserves if token `x` prior to swap
`_reserve1`: Reserves if token `y` prior to swap

#### Arbitrage

Arbitrage is one the most important concepts to understand how uniswap works. Although this concept is not unique to Uniswap, it applies to all of the DeFi projects. In order to understand this concept better, the first thing we need to ask ourselves is how does Uniswap know the the price of given token?

In conclusion, Uniswap does not know about outside world prices. Thanks to the arbitrageurs, the prices are almost identical to the outside world.

#### Impermanent Loss

Impermanent loss for liquidity providers is the change in dollar terms of their total stake in a given pool versus just holding these assets.

### Liquidity/LP Tokens

Big amounts of liquidity are what makes Uniswap an attractive system to use. Without liquidity, the system becomes inefficient, particular for big traders relative to total liquidity of the pool.
Note: For big traders(relative to the pool), it's better to use an aggregator to decrease slippage as much as possible.

When a liquidity provider provides liquidity to a pool, it receives its LP tokens proportionally to its amount of liquidity.

A Uniswap pool is just a smart contract that holds a certain amount of reserves. The liquidity providers provide these reserves. But the pool also has an in-house token called `LP Token`. This token is unique to each pool and main purpose is to track the liquidity each LP has injected. You can think of this token as a certification of your liquidity. The smart contract pool imports `UniswapV2ERC20.sol` which is a basically a contract that has basic ERC20 functionality.


The LP token are `stored` inside of this contract. Every time liquidity providers provides liquidity, some amount of tokens are minted to his address. Inversely, every time the liquidity provider take liquidity out, the LP tokens are burned.
In order to calculate the LP token that a liquidity provider receives, we need to know if there is liquidity or if it is the first time someone is providing liquidity.

As a final note on this topic, if we remember the protocol charges 0.3% trading fee. This fee goes to the liquidity providers, The way the fee is technically accrued is by increasing the reserves of x and y in every trade. This will positively impact the amount of LP tokens each liquidity provider holds.

## System's Core implementation

### Protocol Architecture

Uniswap is a binary smart contract system. It's composed of V2-Core and V2-Periphery.

-   V2-Core is the low level based contracts. These smart contracts are responsible for the system's functionality.
-   V2-Periphery are help contracts that allow frontend application and developers to integrate with the core contracts by applying safety checks and abstracting away certain things.

In simpler terms, V2-Core is the part of protocol that implements the core features(swapping, minting, burning, etc.). In contrast, V2-Periphery is one layer up. It is a set of contracts and libraries that make the integration easier for developers.


### Main Contracts

- `UniswapV2ERC20.sol`: This contract is responsible for the LP token functionality. It is a basic ERC20 contract.
- `UniswapV2Factory.sol`: This is the factory that is responsible for deploying new pools and also to keep track of them.
- `UniswapV2Pair.sol`: This is where the action happens


#### Uniswap V2 Factory 

Again, the factory contract is responsible for creating new contract pairs. In order to concentrate liquidity, there can only be one smart contract per pair. In other words, if there is a WETH/UNI pair contract already, the factory won’t allow you to create the same pair. Of course, you can bypass that (by deploying the pair contract directly), but the core principle here is to concentrate liquidity as much as possible to avoid price slippage and have more liquidity.

#### Uniswap V2 Pair

This contract is responsible for handling unique pool. The basic functionality of this contract is to swap, mint , and burn. We already went into detail as to how these components work, so we will just give them one quick brush.

Swap(): The swap function is the star of Uniswap. Every time you want to trade one token for another, the function gets called. The basic task of this function is to enforce that newK is greater than or equal to k:

Mint(): The mint function is responsible for minting LP tokens every time a liquidity provider provides liquidity.

Burn(): The burn function is responsible for burning LP tokens every time a liquidity provider wants to take his assets out of the pool. 