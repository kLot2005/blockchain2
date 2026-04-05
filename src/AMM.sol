// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./LPToken.sol";

contract AMM {
    IERC20 public tokenA;
    IERC20 public tokenB;
    LPToken public lpToken;
    uint256 public reserveA;
    uint256 public reserveB;
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpAmount);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpAmount);
    event Swap(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        lpToken = new LPToken();
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external returns (uint256 liquidity) {
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        uint256 _totalSupply = lpToken.totalSupply();
        if (_totalSupply == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            liquidity = min((amountA * _totalSupply) / reserveA, (amountB * _totalSupply) / reserveB);
        }

        require(liquidity > 0, "Insufficient liquidity minted");
        reserveA += amountA;
        reserveB += amountB;

        lpToken.mint(msg.sender, liquidity);
        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut) {
        require(tokenIn == address(tokenA) || tokenIn == address(tokenB), "Invalid token");

        bool isTokenA = tokenIn == address(tokenA);
        (IERC20 tIn, IERC20 tOut, uint256 resIn, uint256 resOut) = isTokenA 
            ? (tokenA, tokenB, reserveA, reserveB) 
            : (tokenB, tokenA, reserveB, reserveA);

        tIn.transferFrom(msg.sender, address(this), amountIn);
        amountOut = getAmountOut(amountIn, resIn, resOut);
        require(amountOut >= minAmountOut, "High slippage");

        if (isTokenA) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        tOut.transfer(msg.sender, amountOut);
        emit Swap(msg.sender, tokenIn, amountIn, amountOut); 
    }

    function removeLiquidity(uint256 lpAmount) external returns (uint256 amountA, uint256 amountB) {
        uint256 _totalSupply = lpToken.totalSupply();
        amountA = (lpAmount * reserveA) / _totalSupply;
        amountB = (lpAmount * reserveB) / _totalSupply;

        lpToken.burn(msg.sender, lpAmount);
    
        reserveA -= amountA;
        reserveB -= amountB;

        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, lpAmount);
    }

    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function min(uint x, uint y) internal pure returns (uint) {
        return x <= y ? x : y;
    }
}