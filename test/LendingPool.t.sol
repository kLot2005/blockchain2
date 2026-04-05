// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/LendingPool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("Test Token", "TST") {
        _mint(msg.sender, 10000e18);
    }
}

contract LendingPoolTest is Test {
    LendingPool public pool;
    TestToken public token;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        token = new TestToken();
        pool = new LendingPool(address(token));
        token.transfer(alice, 1000e18);
        token.transfer(bob, 1000e18);
    }

 
    function test_Deposit() public {
        vm.startPrank(alice);
        token.approve(address(pool), 100e18);
        pool.deposit(100e18);
        vm.stopPrank();
        
        (uint256 deposited,,) = pool.positions(alice);
        assertEq(deposited, 100e18);
    }

   
    function test_BorrowWithinLimit() public {
        vm.startPrank(alice);
        token.approve(address(pool), 100e18);
        pool.deposit(100e18);
        pool.borrow(75e18); 
        vm.stopPrank();

        ( , uint256 borrowed, ) = pool.positions(alice);
        assertEq(borrowed, 75e18);
    }

    
    function test_FailBorrowExceedingLimit() public {
        vm.startPrank(alice);
        token.approve(address(pool), 100e18);
        pool.deposit(100e18);
        vm.expectRevert("Exceeds LTV");
        pool.borrow(76e18); // Пытаемся взять 76%
        vm.stopPrank();
    }

    
    function test_InterestAccrual() public {
        vm.startPrank(alice);
        token.approve(address(pool), 100e18);
        pool.deposit(100e18);
        pool.borrow(50e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 365 days);

        uint256 debt = pool.totalDebt(alice);
        uint256 expectedDebt = 52.5e18; // 50 + 5%


        assertApproxEqAbs(debt, expectedDebt, 1e14);
    }


    function test_Repay() public {
        vm.startPrank(alice);
        token.approve(address(pool), 200e18);
        pool.deposit(100e18);
        pool.borrow(50e18);
        pool.repay(50e18);
        vm.stopPrank();

        ( , uint256 borrowed, ) = pool.positions(alice);
        assertEq(borrowed, 0);
    }


    function test_FailWithdrawWithDebt() public {
        vm.startPrank(alice);
        token.approve(address(pool), 100e18);
        pool.deposit(100e18);
        pool.borrow(70e18); 

    
        vm.expectRevert("Health factor too low");
        pool.withdraw(50e18);
        vm.stopPrank();
}

    
    function test_FailBorrowZeroCollateral() public {
        vm.startPrank(bob);
        vm.expectRevert(); 
        pool.borrow(10e18);
        vm.stopPrank();
    }

    function testFuzz_Deposit(uint256 amount) public {
        amount = bound(amount, 1, 1000e18);
        token.transfer(alice, amount);
        vm.startPrank(alice);
        token.approve(address(pool), amount);
        pool.deposit(amount);
        vm.stopPrank();
        (uint256 deposited,,) = pool.positions(alice);
        assertEq(deposited, amount);
    }

    function test_Invariant_Solvency() public {
        vm.startPrank(alice);
        token.approve(address(pool), 100e18);
        pool.deposit(100e18);
        pool.borrow(50e18);
        vm.stopPrank();

    
        uint256 expectedBalance = 100e18 - 50e18;
        assertEq(token.balanceOf(address(pool)), expectedBalance);
    }

    function test_LiquidationScenario() public {

        vm.startPrank(alice);
        token.approve(address(pool), 100e18);
        pool.deposit(100e18);
        pool.borrow(75e18);
        vm.stopPrank();

  
        vm.warp(block.timestamp + (365 days * 2));
    
   
        assertTrue(pool.getHealthFactor(alice) < 100e18);

    
        token.transfer(bob, 100e18); 
        vm.startPrank(bob);
        token.approve(address(pool), 100e18);
        pool.liquidate(alice);
        vm.stopPrank();

        
        assertGt(token.balanceOf(bob), 100e18); 
        (uint256 dep, uint256 borr, ) = pool.positions(alice);
        assertEq(dep, 0);
        assertEq(borr, 0);
}
}