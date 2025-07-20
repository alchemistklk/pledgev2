const { ethers } = require("hardhat");
let multiSignatureAddress = [
    "0xCEd3b838FC041585a62b88B4332CA8e39f040F6E",
    "0xABc8462699d9d8e4EfF9636e14ae9b234c90A4c4",
    "0x448129a5f09cAd03f23f80e930cd4805ac4bA2f8",
];
let threshold = 2;

async function main() {
    const [deployerMax, , , , deployerMin] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployerMax.address);

    console.log(
        "Account balance:",
        (await deployerMax.getBalance()).toString()
    );

    const multiSignatureToken = await ethers.getContractFactory(
        "multiSignature"
    );
    const multiSignature = await multiSignatureToken
        .connect(deployerMax)
        .deploy(multiSignatureAddress, threshold);

    console.log("multiSignature address:", multiSignature.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
