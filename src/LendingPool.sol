// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LendingPool {
    IERC20 public token;
    struct UserPosition {
        uint256 deposited;
        uint256 borrowed;
        uint256 lastUpdateTimestamp;
    }

    mapping(address => UserPosition) public positions;
    uint256 public constant LTV = 75; // 75%
    uint256 public constant LIQUIDATION_THRESHOLD = 80; 
    uint256 public constant INTEREST_RATE = 5;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function deposit(uint256 amount) external {
        token.transferFrom(msg.sender, address(this), amount);
        positions[msg.sender].deposited += amount;
    }

    function borrow(uint256 amount) external {
        uint256 maxBorrow = (positions[msg.sender].deposited * LTV) / 100;
        require(positions[msg.sender].borrowed + amount <= maxBorrow, "Exceeds LTV");
        positions[msg.sender].borrowed += amount;
        token.transfer(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        token.transferFrom(msg.sender, address(this), amount);
        positions[msg.sender].borrowed -= amount;
    }

    function getHealthFactor(address user) public view returns (uint256) {
        if (positions[user].borrowed == 0) return 100e18; 
        uint256 collateralValue = positions[user].deposited;
        return (collateralValue * LTV) / positions[user].borrowed;
    }

    function getAccruedDebt(address user) public view returns (uint256) {
        UserPosition storage pos = positions[user];
        if (pos.borrowed == 0) return 0;
        uint256 timeElapsed = block.timestamp - pos.lastUpdateTimestamp;

        return (pos.borrowed * INTEREST_RATE * timeElapsed) / (365 days * 100);
    }

    function totalDebt(address user) public view returns (uint256) {
        return positions[user].borrowed + getAccruedDebt(user);
    }

    function withdraw(uint256 amount) external {
        require(positions[msg.sender].deposited >= amount, "Insufficient balance");
        positions[msg.sender].deposited -= amount;
        if (positions[msg.sender].borrowed > 0) {
            require(getHealthFactor(msg.sender) >= 100e18, "Health factor too low");
        }
        token.transfer(msg.sender, amount);
        positions[msg.sender].lastUpdateTimestamp = block.timestamp;
    }

    function liquidate(address user) external {
        require(getHealthFactor(user) < 100e18, "Health factor is fine");
        uint256 userDebt = totalDebt(user);
        uint256 userCollateral = positions[user].deposited;
        token.transferFrom(msg.sender, address(this), userDebt);
        positions[user].deposited = 0;
        positions[user].borrowed = 0;
        token.transfer(msg.sender, userCollateral);
    }
}