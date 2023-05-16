// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

interface IFactory {
    function createPair(address tokenA, address tokenB, bool stable) external returns (address pair);
}

interface IPool {
    function mint(address to) external returns (uint liquidity);
    function getAmountOut(uint amountIn, address tokenIn) external view returns (uint);
}

contract CounterTest is Test {
    uint256 MAX_BPS = 10_000;
    uint256 STABLE_FEES = 5;
    uint256 VARIABLE_FEES = 5;

    IFactory factory = IFactory(0x25CbdDb98b35ab1FF77413456B31EC81A6B6B746);

    function setUp() public {
        

        address newPool = factory.createPair(tokenA, tokenB, stable);
    }

    function _deposit(uint256 amountIn, uint256 amountOut) internal {
        // Deposit those on Pair
        // Then call mint
    }
}
