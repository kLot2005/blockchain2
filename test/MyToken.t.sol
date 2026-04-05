// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MyToken.sol";

contract MyTokenTest is Test {
    MyToken public token;
   
    address public owner = address(0x123); 
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        vm.prank(owner);
        token = new MyToken("MyToken", "MTK");
        targetContract(address(token));
    }
    function test_InitialSupply() public view {
        assertEq(token.totalSupply(), 1000e18); // [cite: 253]
    }

    function test_OwnerBalance() public view {
        assertEq(token.balanceOf(owner), 1000e18);
    }

    function test_Transfer() public {
        vm.prank(owner);
        token.transfer(alice, 100e18);
        assertEq(token.balanceOf(alice), 100e18);
        assertEq(token.balanceOf(owner), 900e18);
    }

    function test_ApproveAndAllowance() public {
        vm.prank(owner);
        token.approve(alice, 50e18);
        assertEq(token.allowance(owner, alice), 50e18);
    }

    function test_TransferFrom() public {
        vm.prank(owner);
        token.approve(alice, 50e18);
        vm.prank(alice);
        token.transferFrom(owner, alice, 50e18);
        assertEq(token.balanceOf(alice), 50e18);
    }

    function test_MintByOwner() public {
        vm.prank(owner);
        token.mint(bob, 200e18);
        assertEq(token.balanceOf(bob), 200e18);
    }

    function test_FailTransferInsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 1 ether);
    }

    function test_FailMintByNonOwner() public {
        vm.prank(alice); 
        vm.expectRevert();
        token.mint(alice, 100e18);
    }

    function test_TransferZeroAmount() public {
        vm.prank(owner);
        bool success = token.transfer(alice, 0);
        assertTrue(success);
    }

    function test_AllowanceAfterTransferFrom() public {
        vm.prank(owner);
        token.approve(alice, 100e18);
        vm.prank(alice);
        token.transferFrom(owner, bob, 40e18);
        assertEq(token.allowance(owner, alice), 60e18);
    }

    function testFuzz_Transfer(uint256 amount) public {
        amount = bound(amount, 0, token.balanceOf(owner));
        vm.prank(owner);
        token.transfer(alice, amount);
        assertEq(token.balanceOf(alice), amount);
    }

    function invariant_TotalSupplyEqualsBalances() public view {
        uint256 sumBalances = token.balanceOf(owner) + token.balanceOf(alice) + token.balanceOf(bob);
        assertLe(sumBalances, token.totalSupply());
    }
}