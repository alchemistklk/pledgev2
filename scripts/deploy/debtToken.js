const {ethers} = require("hardhat");

let tokenName = "spBTC_1";
let tokenSymbol = "spBTC_1";

let multiSignatureAddress = "0x9Ed445329D8465C2C56497102eC80BfDb8952e8B";

async function main() {
  const [deployerMin,,,,deployerMax] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    deployerMin.address
  );

  console.log("Account balance:", (await deployerMin.getBalance()).toString());

  const debtToken = await ethers.getContractFactory("DebtToken");
  const DebtToken = await debtToken.connect(deployerMin).deploy(tokenName,tokenSymbol,multiSignatureAddress);

  console.log("DebtToken address:", DebtToken.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });