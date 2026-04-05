// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniswapV2Router {
    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract ForkTest is Test {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    function setUp() public {
       
        vm.createSelectFork("mainnet", 19_000_000);
    }

    function test_ReadUSDCTotalSupply() public view {
        uint256 supply = IERC20(USDC).totalSupply();
        console.log("Real USDC Total Supply:", supply);
    
        assertGt(supply, 20_000_000_000e6);
    }

    
    function test_SimulateUniswapSwap() public {
        address whale = 0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503;
        uint256 amountIn = 1000e6; // 1000 USDC
        vm.deal(whale, 1 ether);

        vm.startPrank(whale);
        IERC20(USDC).approve(UNISWAP_ROUTER, amountIn);

        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = WETH;

        IUniswapV2Router(UNISWAP_ROUTER).swapExactTokensForETH(
            amountIn,
            0,
            path,
            whale,
            block.timestamp
        );
        vm.stopPrank();
        assertGt(whale.balance, 1 ether);
        console.log("Whale ETH balance after swap:", whale.balance);
    }
}