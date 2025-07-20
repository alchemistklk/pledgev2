const { ethers } = require("hardhat");

const wethAddress = "0x338153993F29Be34087CCcF52441f65940F139B8";

async function main() {
  const [deployer, adm] = await ethers.getSigners();
  const weth = await ethers.getContractAt("IWETH", wethAddress);

  const tx = await weth.deposit({value:  ethers.utils.parseEther("0.01")});
//   const tx = await weth.transfer(adm.address, ethers.utils.parseEther("1000"));
  console.log(tx);
}

main();
