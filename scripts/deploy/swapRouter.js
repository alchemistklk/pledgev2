const { ethers } = require("hardhat");

async function mockUniswap(minter, weth) {
    const UniswapV2Factory = await ethers.getContractFactory(
        "UniswapV2Factory"
    );
    let uniswapFactory = await UniswapV2Factory.deploy(minter.address);

    const UniswapV2Router02 = await ethers.getContractFactory(
        "UniswapV2Router02"
    );
    let uniswapRouter = await UniswapV2Router02.deploy(
        uniswapFactory.address,
        weth.address
    );
    return [uniswapRouter, uniswapFactory];
}
// targetToken: {address: string, price: int}
async function mockAddLiquidity(
    router,
    token0,
    token1,
    minter,
    deadline,
    amount0,
    amount1
) {
    // approve
    await token0.connect(minter).approve(router.address, BigInt(amount0));
    await token1.connect(minter).approve(router.address, BigInt(amount1));
    // add
    await router
        .connect(minter)
        .addLiquidity(
            token0.address,
            token1.address,
            BigInt(amount0),
            BigInt(amount1),
            BigInt(0),
            BigInt(0),
            minter.address,
            deadline
        );
}

async function mockSwap(
    router,
    token0,
    swapAmount,
    minAmount,
    path,
    minter,
    deadline
) {
    // approve
    await token0.connect(minter).approve(router.address, BigInt(swapAmount));
    // swap
    await router
        .connect(minter)
        .swapExactTokensForTokens(
            BigInt(swapAmount),
            BigInt(minAmount),
            path,
            minter.address,
            deadline
        );
}

async function main() {
    const [deployerMin, , , , deployerMax] = await ethers.getSigners();
    const WETH9 = await ethers.getContractFactory("WETH9");
    const weth = await WETH9.deploy();
    console.log("weth", weth.address);
    const [router, factory] = await mockUniswap(deployerMin, weth);
    console.log("router", router.address);
    console.log("factory", factory.address);
}

main();
