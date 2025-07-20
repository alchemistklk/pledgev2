require("@nomicfoundation/hardhat-ignition");
require("@nomiclabs/hardhat-ethers");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  networks: {
    sepolia: {
      url: "hideden",
      accounts: [process.env.PRIVATE_KEY],
    },
  },
  solidity: {
    optimizer: {
      enabled: false,
      runs: 50,
    },
    compilers: [
      {
        version: "0.4.18",
        settings: {
          evmVersion: "berlin"
        }
      },
      {
        version: "0.5.16",
        settings: {
          evmVersion: "berlin"
        }
      },
      {
        version: "0.6.6",
        settings: {
          evmVersion: "berlin",
          optimizer: {
            enabled: true,
            runs: 1
          },
        }
      },
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1
          },
          // evmVersion: "shanghai"
        }
      },
    ],
  },
};
