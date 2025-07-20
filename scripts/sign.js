const { ethers } = require("hardhat");

const multiSignatureAddress = "0xa75d4642CeE17d908B79528B5f0Cb8f5647870D2";

async function main() {
    const [deployer, adm] = await ethers.getSigners();

      const multiSignature = await ethers.getContractAt("multiSignature", multiSignatureAddress);
  
    const pledgePoolAddress = "0xabEBB00fB590e9Ad376304ADB1E32eC6066E6f76";
  
    //   const tx = await multiSignature.connect(deployer).createApplication(pledgePoolAddress)
  
    //   console.log(tx);
  
      const pledgePoolMsgHash = '0xdb90e67feee25404c526caa5fb04799b965003907540d9d58bf0ef72603d43bf'
      const tx2 = await multiSignature.connect(deployer).signApplication(pledgePoolMsgHash)
      const tx3 = await multiSignature.connect(adm).signApplication(pledgePoolMsgHash)
}

main()