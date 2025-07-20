// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

let oracleAddress = "0xeF1B8A4326Fa29b31d42517AA70597A71b5Cf8db";
let swapRouter = "0x5af046Ab3b3AA1fB684DF44807B63b8A7FB52a14";
let feeAddress = "0xCEd3b838FC041585a62b88B4332CA8e39f040F6E";
let multiSignatureAddress = "0x9Ed445329D8465C2C56497102eC80BfDb8952e8B";

const {ethers} = require("hardhat");

async function main() {

  const [deployerMin,,,,deployerMax] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    deployerMin.address
  );

  console.log("Account balance:", (await deployerMin.getBalance()).toString());

  const pledgePoolToken = await ethers.getContractFactory("PledgePool");
  const pledgeAddress = await pledgePoolToken.connect(deployerMin).deploy(oracleAddress,swapRouter,feeAddress, multiSignatureAddress);


  console.log("pledgeAddress address:", pledgeAddress.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });