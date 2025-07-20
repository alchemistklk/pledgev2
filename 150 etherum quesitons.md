Easy

What is the difference between private, internal, public, and external functions?
Approximately, how large can a smart contract be?
What is the difference between create and create2?
What major change with arithmetic happened with Solidity 0.8.0?
What special CALL is required for proxies to work?
How do you calculate the dollar cost of an Ethereum transaction?
What are the challenges of creating a random number on the blockchain?
What is the difference between a Dutch Auction and an English Auction?
What is the difference between transfer and transferFrom in ERC20?
Which is better to use for an address allowlist: a mapping or an array? Why?
Why shouldn’t tx.origin be used for authentication?
What hash function does Ethereum primarily use?
How much is 1 gwei of Ether?
How much is 1 wei of Ether?
What is the difference between assert and require?
What is a flash loan?
What is the check-effects-interaction pattern?
What is the minimum amount of Ether required to run a solo staking node?
What is the difference between fallback and receive?
What is reentrancy?
What prevents infinite loops from running forever?
What is the difference between tx.origin and msg.sender?
How do you send Ether to a contract that does not have payable functions, or a receive or fallback?
What is the difference between view and pure?
What is the difference between transferFrom and safeTransferFrom in ERC721?
How can an ERC1155 token be made into a non-fungible token?
What is access control and why is it important?
What does a modifier do?
What is the largest value a uint256 can store?
What is variable and fixed interest rate?



Medium
What is the difference between transfer and send? Why should they not be used?
What is a storage collision in a proxy contract?
What is the difference between abi.encode and abi.encodePacked?
uint8, uint32, uint64, uint128, uint256 are all valid uint sizes. Are there others? What changed with block.timestamp before and after proof of stake?
What is frontrunning?
What is a commit-reveal scheme and when would you use it?
Under what circumstances could abi.encodePacked create a vulnerability?
How does Ethereum determine the BASEFEE in EIP-1559?
What is the difference between a cold read and a warm read?
How does an AMM price assets?
What is a function selector clash in a proxy and how does it happen?
What is the effect on gas of making a function payable?
What is a signature replay attack?
How would you design a game of rock-paper-scissors in a smart contract such that players cannot cheat?
What is the free memory pointer and where is it stored?
What function modifiers are valid for interfaces? What is the difference between memory and calldata in a function argument?
Describe the three types of storage gas costs for writes.
Why shouldn’t upgradeable contracts use the constructor?
What is the difference between UUPS and the Transparent Upgradeable Proxy pattern?
If a contract delegatecalls an empty address or an implementation that was previously self-destructed, what happens? What if it is a low-level call instead of a delegatecall?
What danger do ERC777 tokens pose?
According to the solidity style guide, how should functions be ordered?
According to the solidity style guide, how should function modifiers be ordered?
What is a bonding curve?
How does _safeMint differ from _mint in the OpenZeppelin ERC721 implementation? What keywords are provided in Solidity to measure time? What is a sandwich attack?
If a delegatecall is made to a function that reverts, what does the delegatecall do?
What is a gas efficient alternative to multiplying and dividing by a power of two?
How large a uint can be packed with an address in one slot?
Which operations give a partial refund of gas? What is ERC165 used for?
If a proxy makes a delegatecall to A, and A does address(this).balance, whose balance is returned, the proxy’s or A?
What is a slippage parameter useful for?
What does ERC721A do to reduce mint costs? What is the tradeoff?
Why doesn’t Solidity support floating point arithmetic?
What is TWAP?
How does Compound Finance calculate utilization?
If a delegatecall is made to a function that reads from an immutable variable, what will the value be?
What is a fee-on-transfer token?
What is a rebasing token?
In what year will a timestamp stored in a uint32 overflow?
What is LTV in the context of DeFi?
What are aTokens and cTokens in the context of Compound Finance and AAVE?
Describe how to use a lending protocol to go leveraged long or leveraged short on an asset.
What is a perpetual protocol?

Hard
How does fixed point arithmetic represent numbers?
What is an ERC20 approval frontrunning attack?
What opcode accomplishes address(this).balance?
How many arguments can a solidity event have?
What is an anonymous Solidity event?
Under what circumstances can a function receive a mapping as an argument?
What is an inflation attack in ERC4626
How many storage slots does this use? uint64[] x = [1,2,3,4,5]? Does it differ from memory?
Prior to the Shanghai upgrade, under what circumstances is returndatasize() more efficient than PUSH 0?
Why does the compiler insert the INVALID op code into Solidity contracts?
What is the difference between how a custom error and a require with error string is encoded at the EVM level? 1hat is the kink parameter in the Compound DeFi formula? 1ow can the name of a function affect its gas cost, if at all?
What is a common vulnerability with ecrecover?
What is the difference between an optimistic rollup and a zk-rollup?
How does EIP1967 pick the storage slots, how many are there, and what do they represent?
How much is one Sazbo of ether?
What can delegatecall be used for besides use in a proxy?
Under what circumstances would a smart contract that works on Etheruem not work on Polygon or Optimism? (Assume no dependencies on external contracts)
How can a smart contract change its bytecode without changing its address?
What is the danger of putting msg.value inside of a loop? escribe the calldata of a function that takes a dynamic length array of uint128 when uint128[1,2,3,4] is passed as an argument
Why is strict inequality comparisons more gas efficient than ≤ or ≥? What extra opcode(s) are added?
If a proxy calls an implementation, and the implementation self-destructs in the function that gets called, what happens?
What is the relationship between variable scope and stack depth?
What is an access list transaction?
How can you halt an execution with the mload opcode?
What is a beacon in the context of proxies?
Why is it necessary to take a snapshot of balances before conducting a governance vote?
How can a transaction be executed without a user paying for gas?
In solidity, without assembly, how do you get the function selector of the calldata?
How is an Ethereum address derived?
What is the metaproxy standard?
If a try catch makes a call to a contract that does not revert, but a revert happens inside the try block, what happens?
If a user calls a proxy makes a delegatecall to A, and A makes a regular call to B, from A’s perspective, who is msg.sender? from B’s perspective, who is msg.sender? From the proxy’s perspective, who is msg.sender?
Under what circumstances do vanity addresses (leading zero addresses) save gas?
Why do a significant number of contract bytecodes begin with 6080604052? What does that bytecode sequence do?
How does Uniswap V3 determine the boundaries of liquidity intervals?
What is the risk-free rate?
When a contract calls another call via call, delegatecall, or staticcall, how is information passed between them?
What is the difference between bytes and bytes1[]?
What is the most amount of leverage that can be achieved in a borrow-swap-supply-collateral loop if the LTV is 75%? What about other LTV limits?
How does Curve StableSwap achieve concentrated liquidity?
What quirks does the Tether stablecoin contract have?
What is the smallest uint that will store 1 million? 1 billion? 1 trillion? 1 quadrillion?
What danger to uninitialized UUPS logic contracts pose?
What is the difference (if any) between what a contract returns if a divide-by-zero happens in Soliidty or if a dividye-by-zero happens in Yul?
Why can’t .push() be used to append to an array in memory?

Advanced
What addresses to the ethereum precompiles live at?
Describe what “liquidity” is in the context of Uniswap V2 and Uniswap V3.
If a delegatecall is made to a contract that makes a delegatecall to another contract, who is msg.sender in the proxy, the first contract, and the second contract?
What is the difference between how a uint64 and uint256 are abi-encoded in calldata?
What is read-only reentrancy?
What are the security considerations of reading a (memory) bytes array from an untrusted smart contract call?
If you deploy an empty Solidity contract, what bytecode will be present on the blockchain, if any?
How does the EVM price memory usage?
What is stored in the metadata section of a smart contract?
What is the uncle-block attack from an MEV perspective?
How do you conduct a signature malleability attack?
Under what circumstances do addresses with leading zeros save gas and why?
What is the difference between payable(msg.sender).call{value: value}("") and msg.sender.call{value: value}("")? 1How many storage slots does a string take up?
How does the --via-ir functionality in the Solidity compiler work?
Are function modifiers called from right to left or left to right, or is it non-deterministic?
If you do a delegatecall to a contract and the opcode CODESIZE executes, which contract size will be returned?
Why is it important to ECDSA sign a hash rather than an arbitrary bytes32?
Describe how symbolic manipulation testing works.
What is the most efficient way to copy regions of memory?
How can you validate on-chain that another smart contract emitted an event, without using an oracle?
When selfdestruct is called, at what point is the Ether transferred? At what point is the smart contract’s bytecode erased?
Under what conditions does the Openzeppelin Proxy.sol overwrite the free memory pointer? Why is it safe to do this?
Why did Solidity deprecate the “years” keyword?
What does the verbatim keyword do, and where can it be used?
How much gas can be forwarded in a call to another smart contract?
What does an int256 variable that stores -1 look like in hex?
What is the use of the signextend opcode?
Why do negative numbers in calldata cost more gas?
What is a zk-friendly hash function and how does it differ from a non-zk-friendly hash function?
What does a metaproxy do?
What is a nullifier in the context of zero knowledge, and what is it used for?
What is SECP256K1?
Why shouldn’t you get price from slot0 in Uniswap V3?
Describe how to compute the 9th root of a number on-chain in Solidity.
What is the danger of using return in assembly out of a Solidity function that has a modifier?
Without using the % operator, how can you determine if a number is even or odd?
What does codesize() return if called within the constructor? What about outside the constructor?
