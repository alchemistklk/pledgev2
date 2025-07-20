// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("PledgePoolModule", (m) => {
    const oracleAddress = "0xeF1B8A4326Fa29b31d42517AA70597A71b5Cf8db";
    const swapRouter = "0x5af046Ab3b3AA1fB684DF44807B63b8A7FB52a14";
    const feeAddress = "0xCEd3b838FC041585a62b88B4332CA8e39f040F6E";
    const multiSignatureAddress = "0x9Ed445329D8465C2C56497102eC80BfDb8952e8B";

    const pledgePool = m.contract(
        "PledgePool",
        [oracleAddress, swapRouter, feeAddress, multiSignatureAddress],
        {}
    );
    return { pledgePool };
});
