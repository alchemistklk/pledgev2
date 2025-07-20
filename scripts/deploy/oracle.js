const {ethers} = require("hardhat");
let multiSignatureAddress = "0x9Ed445329D8465C2C56497102eC80BfDb8952e8B";

async function main() {
  const [deployerMin,,,,deployerMax] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    deployerMin.address
  );

  console.log("Account balance:", (await deployerMin.getBalance()).toString());

  const oracleToken = await ethers.getContractFactory("BscPledgeOracle");
  const oracle = await oracleToken.connect(deployerMin).deploy(multiSignatureAddress);

  console.log("Oracle address:", oracle.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });