# Pledge V2 Contract

## 1. Deploy multiSignature on Sepolia -> MultiSignature Address:0x9Ed445329D8465C2C56497102eC80BfDb8952e8B

rewrite your own address to the signature address

let multiSignatureAddress = [
    "0xCEd3b838FC041585a62b88B4332CA8e39f040F6E",
    "0xABc8462699d9d8e4EfF9636e14ae9b234c90A4c4",
    "0x448129a5f09cAd03f23f80e930cd4805ac4bA2f8",
];
let threshold = 2;


```shell
npx hardhat run scripts/deploy/multiSignature.js --network sepolia
```

## 2. Deploy debtToken on Sepolia -> DebtToken Address: 0x3d2be5E676cDF1e72bD2598ba7aC3Ea9E50AbC02

```shell
npx hardhat run scripts/deploy/debtToken.js --network sepolia
```

## 3. Deploy oracle on Sepolia -> Oracle Address: 0xeF1B8A4326Fa29b31d42517AA70597A71b5Cf8db

```shell
npx hardhat run scripts/deploy/oracle.js --network sepolia
```

## 4. Deploy swapRouter on Sepolia -> SwapRouter: 0x5af046Ab3b3AA1fB684DF44807B63b8A7FB52a14

```shell
npx hardhat run scripts/deploy/swapRouter.js --network sepolia
```

## 5. Deploy pledgePool on Sepolia -> PledgePool: 0x4F21E451E5960A4C72b6a931E5914072cA08B650

```shell
npx hardhat run scripts/deploy/pledgePool.js --network sepolia
```