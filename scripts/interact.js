const { ethers } = require("hardhat");

async function main() {
  const [deployer, adm] = await ethers.getSigners();

  const pledgePoolAddress = "0xabEBB00fB590e9Ad376304ADB1E32eC6066E6f76";

  const PledgePool = await ethers.getContractAt(
    "PledgePool",
    pledgePoolAddress
  );
  console.log("start---");

  //   uint256 _settleTime,  uint256 _endTime, uint64 _interestRate,
  // uint256 _maxSupply, uint256 _martgageRate, address _lendToken, address _borrowToken,
  // address _spToken, address _jpToken, uint256 _autoLiquidateThreshold
  // const txc = await PledgePool.createPoolInfo(
  //   Math.ceil(Date.now()/1000) + 1000000,
  //   Math.ceil(Date.now()/1000) + 2000000,
  //   2000,
  //   ethers.utils.parseEther("1000"),
  //   10000,
  //   ethers.constants.AddressZero,
  //   "0x338153993F29Be34087CCcF52441f65940F139B8",
  //   "0xc3C6Ef79897Df94ddd86189A86BD9c5c7bB93Cf6",
  //   "0xc3C6Ef79897Df94ddd86189A86BD9c5c7bB93Cf6",
  //   100000000000000
  // )
  //   const pool = await PledgePool.poolBaseInfo(0);
  //   console.log(pool);

  //   const tx = await PledgePool.connect(adm).depositLend(0, ethers.utils.parseEther("0.01"), {
  //     value: ethers.utils.parseEther("0.01"),
  //   });

  const wethAddress = "0x338153993F29Be34087CCcF52441f65940F139B8";

  const weth = await ethers.getContractAt("WETH9", wethAddress);

  const tx = await weth.connect(adm).approve(
    pledgePoolAddress,
    ethers.utils.parseEther("0.01")
  );

  console.log(tx);
  

  const db = await PledgePool.connect(adm).depositBorrow(
    0,
    // ethers.utils.parseEther("0.01")
    // 10000000000000000
    ethers.utils.parseEther("0.01")
  );


  console.log(db);
  
  //   const receipt = await tx.wait()
  //   console.log(tx);
  //   console.log("Deploying contracts with the account:", deployer.address);
  //   console.log("Account balance:", (await deployer.getBalance()).toString());
}

main();
