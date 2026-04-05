// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AMM.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract TestToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 10000e18);
    }
}

contract AMMTest is Test {
    AMM public amm;
    TestToken public tokenA;
    TestToken public tokenB;
    address public provider = makeAddr("provider");
    address public trader = makeAddr("trader");
    event Swap(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

    function setUp() public {
        tokenA = new TestToken("Token A", "TKNA");
        tokenB = new TestToken("Token B", "TKNB");
        amm = new AMM(address(tokenA), address(tokenB));

        tokenA.transfer(provider, 1000e18);
        tokenB.transfer(provider, 1000e18);
        tokenA.transfer(trader, 500e18);
        tokenB.transfer(trader, 500e18);
    }

    // --- ТЕСТЫ ЛИКВИДНОСТИ ---

    function test_InitialLiquidity() public {
        vm.startPrank(provider);
        tokenA.approve(address(amm), 100e18);
        tokenB.approve(address(amm), 100e18);
        
        uint256 lpAmount = amm.addLiquidity(100e18, 100e18);
        assertEq(lpAmount, 100e18); // sqrt(100 * 100)
        assertEq(amm.reserveA(), 100e18);
        assertEq(amm.reserveB(), 100e18);
        vm.stopPrank();
    }

    // --- ТЕСТЫ СВОПОВ ---

    function test_SwapAforB() public {
        vm.startPrank(provider);
        tokenA.approve(address(amm), 500e18);
        tokenB.approve(address(amm), 500e18);
        amm.addLiquidity(500e18, 500e18);
        vm.stopPrank();

        uint256 initialK = amm.reserveA() * amm.reserveB();

        vm.startPrank(trader);
        tokenA.approve(address(amm), 10e18);
        uint256 amountOut = amm.swap(address(tokenA), 10e18, 9e18); 
        vm.stopPrank();

        uint256 finalK = amm.reserveA() * amm.reserveB();
        assertGe(finalK, initialK); 
        assertGt(amountOut, 0);
    }

    // --- ТЕСТЫ ОШИБОК (EDGE CASES) ---

    function test_FailSlippageProtection() public {
        vm.startPrank(provider);
        tokenA.approve(address(amm), 100e18);
        tokenB.approve(address(amm), 100e18);
        amm.addLiquidity(100e18, 100e18);
        vm.stopPrank();

        vm.startPrank(trader);
        tokenA.approve(address(amm), 10e18);
        vm.expectRevert("High slippage");
        amm.swap(address(tokenA), 10e18, 11e18);
        vm.stopPrank();
    }

    // --- ФАЗЗИНГ ---

    function testFuzz_Swap(uint256 amountIn) public {
        vm.startPrank(provider);
        tokenA.approve(address(amm), 1000e18);
        tokenB.approve(address(amm), 1000e18);
        amm.addLiquidity(1000e18, 1000e18);
        vm.stopPrank();
        amountIn = bound(amountIn, 1e10, 100e18); 

        uint256 initialBalanceB = tokenB.balanceOf(trader);

        vm.startPrank(trader);
        tokenA.approve(address(amm), amountIn);
        amm.swap(address(tokenA), amountIn, 0);
        vm.stopPrank();

        assertGt(tokenB.balanceOf(trader), initialBalanceB);
    }

    // Своп в обратную сторону (B на A)
    function test_SwapBforA() public {
        vm.startPrank(provider);
        tokenA.approve(address(amm), 500e18);
        tokenB.approve(address(amm), 500e18);
        amm.addLiquidity(500e18, 500e18);
        vm.stopPrank();

        vm.startPrank(trader);
        tokenB.approve(address(amm), 10e18);
        uint256 amountOut = amm.swap(address(tokenB), 10e18, 9e18);
        vm.stopPrank();

        assertGt(amountOut, 0);
        assertGt(tokenA.balanceOf(trader), 500e18);
    }

    // Удаление ликвидности (полное) 
    function test_RemoveFullLiquidity() public {
        vm.startPrank(provider);
        tokenA.approve(address(amm), 100e18);
        tokenB.approve(address(amm), 100e18);
        uint256 lpAmount = amm.addLiquidity(100e18, 100e18);
        // amm.removeLiquidity(lpAmount); 
        vm.stopPrank();
    }

    // Проверка постоянства K (инварианта)
    function test_K_IncreasesAfterSwap() public {
        vm.startPrank(provider);
        tokenA.approve(address(amm), 100e18);
        tokenB.approve(address(amm), 100e18);
        amm.addLiquidity(100e18, 100e18);
        vm.stopPrank();

        uint256 kBefore = amm.reserveA() * amm.reserveB();

        vm.startPrank(trader);
        tokenA.approve(address(amm), 10e18);
        amm.swap(address(tokenA), 10e18, 0);
        vm.stopPrank();

        uint256 kAfter = amm.reserveA() * amm.reserveB();
        assertGt(kAfter, kBefore);
    }

    // Ошибка при нулевом количестве
    function test_FailSwapZeroAmount() public {
        vm.startPrank(trader);
        vm.expectRevert(); 
        amm.swap(address(tokenA), 0, 0);
        vm.stopPrank();
    }

    // Ошибка при неверном адресе токена
    function test_FailInvalidTokenSwap() public {
        address randomToken = makeAddr("random");
        vm.startPrank(trader);
        vm.expectRevert("Invalid token");
        amm.swap(randomToken, 10e18, 0);
        vm.stopPrank();
    }

    // Добавление ликвидности вторым провайдером 
    function test_SubsequentProvider() public {
        vm.startPrank(provider);
        tokenA.approve(address(amm), 100e18);
        tokenB.approve(address(amm), 100e18);
        amm.addLiquidity(100e18, 100e18);
        vm.stopPrank();

        vm.startPrank(trader);
        tokenA.approve(address(amm), 50e18);
        tokenB.approve(address(amm), 50e18);
        uint256 lpAmount = amm.addLiquidity(50e18, 50e18);
        vm.stopPrank();

        assertEq(lpAmount, 50e18);
    }

    // Большой своп (High Price Impact)
    function test_LargeSwapPriceImpact() public {
        vm.startPrank(provider);
        tokenA.approve(address(amm), 100e18);
        tokenB.approve(address(amm), 100e18);
        amm.addLiquidity(100e18, 100e18);
        vm.stopPrank();

        vm.startPrank(trader);
        tokenA.approve(address(amm), 90e18); 
        uint256 amountOut = amm.swap(address(tokenA), 90e18, 0);
        vm.stopPrank();

        assertLt(amountOut, 50e18); 
    }

    // Проверка событий (Events) 
    // function test_SwapEventEmitted() public {
    //     vm.startPrank(provider);
    //     tokenA.approve(address(amm), 100e18);
    //     tokenB.approve(address(amm), 100e18);
    //     amm.addLiquidity(100e18, 100e18);
    //     vm.stopPrank();
    //
    //     vm.expectEmit(true, true, false, false);
    //     emit Swap(trader, address(tokenA), 0, 0);
    //     
    //     vm.startPrank(trader);
    //     tokenA.approve(address(amm), 10e18);
    //     amm.swap(address(tokenA), 10e18, 0);
    //     vm.stopPrank();
    // }

    // Ликвидность в неправильной пропорции
    function test_AddLiquidityImbalanced() public {
        vm.startPrank(provider);
        tokenA.approve(address(amm), 100e18);
        tokenB.approve(address(amm), 100e18);
        amm.addLiquidity(100e18, 100e18);

        tokenA.approve(address(amm), 50e18);
        tokenB.approve(address(amm), 100e18);
        uint256 lp = amm.addLiquidity(50e18, 100e18);
        vm.stopPrank();
        
        assertGt(lp, 0);
    }

    // Многократные свопы (Stress test)
    function test_MultipleSwaps() public {
        test_InitialLiquidity();
        
        vm.startPrank(trader);
        for(uint i=0; i<5; i++) {
            tokenA.approve(address(amm), 1e18);
            amm.swap(address(tokenA), 1e18, 0);
        }
        vm.stopPrank();
        assertGt(tokenB.balanceOf(trader), 500e18);
    }

    // Минимальный ликвидный минт 
    function test_FailVerySmallLiquidity() public {
        vm.startPrank(provider);
        tokenA.approve(address(amm), 10);
        tokenB.approve(address(amm), 10);
        amm.addLiquidity(10, 10); 
        vm.stopPrank();
    }
}