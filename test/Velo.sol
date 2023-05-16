// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "./tERC20.sol";

// Token A
// Token B
// NOTE: Must be on OP FORK

interface IFactory {
    function createPair(address tokenA, address tokenB, bool stable) external returns (address pair);
}

interface IPool {
    function mint(address to) external returns (uint256 liquidity);
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
}

contract VeloStable is Test {
    uint256 MAX_BPS = 10_000;
    uint256 STABLE_FEES = 5;
    uint256 VARIABLE_FEES = 5;

    IFactory factory = IFactory(0x25CbdDb98b35ab1FF77413456B31EC81A6B6B746);

    address owner = address(123);

    function setUp() public {}

    function _setupNewPool(bool stable, uint256 amountA, uint8 decimalsA, uint256 amountB, uint8 decimalsB)
        internal
        returns (address newPool, address firstToken, address secondToken)
    {
        // Deploy 2 mock tokens
        vm.startPrank(owner);
        tERC20 tokenA = new tERC20("A", "A", decimalsA);

        tERC20 tokenB = new tERC20("B", "B", decimalsB);

        // Stable is false
        newPool = factory.createPair(address(tokenA), address(tokenB), stable);

        tokenA.transfer(newPool, amountA);
        tokenB.transfer(newPool, amountB);

        IPool(newPool).mint(owner);

        return (newPool, address(tokenA), address(tokenB));
    }

    // VELO VARIABLE
    function test_USDC_WETH() public {
        console2.log("Creating USDC-ETH Pool");
        uint256 USDC_IN = 3296185590291;
        uint8 USDC_DECIMALS = 6;

        uint256 WETH_IN = 1817723253459044368326;
        uint8 WETH_DECIMALS = 18;
        // Not stable
        (address poolUSDCETH, address USDC, address WETH) =
            _setupNewPool(false, USDC_IN, USDC_DECIMALS, WETH_IN, WETH_DECIMALS);

        // Let's do amounts and swaps
        uint256[] memory amountsFromUSDC = new uint256[](5);
        amountsFromUSDC[0] = _addDecimals(100, USDC_DECIMALS);
        amountsFromUSDC[1] = _addDecimals(10000, USDC_DECIMALS);
        amountsFromUSDC[2] = _addDecimals(1_000_000, USDC_DECIMALS);
        amountsFromUSDC[3] = _addDecimals(5_000_000, USDC_DECIMALS);
        amountsFromUSDC[4] = _addDecimals(25_000_000, USDC_DECIMALS);

        IPool asPool = IPool(poolUSDCETH);
        for (uint256 i; i < amountsFromUSDC.length; i++) {
            uint256 amountIn = amountsFromUSDC[i];
            console2.log("USDC i", i);
            console2.log("USDC amountIn", amountIn);
            console2.log("WETH amountOut", asPool.getAmountOut(amountIn, USDC));
        }
    }

    function test_USDC_WBTC() public {
        console2.log("Creating USDC-test_USDC_WBTC Pool");
        uint256 USDC_IN = 2530086913;
        uint8 USDC_DECIMALS = 6;

        uint256 WBTC_IN = 9243860;
        uint8 WBTC_DECIMALS = 18;

        // Not stable
        (address poolUSDCETH, address USDC, address WBTC) =
            _setupNewPool(false, USDC_IN, USDC_DECIMALS, WBTC_IN, WBTC_DECIMALS);

        // Let's do amounts and swaps
        uint256[] memory amountsFromUSDC = new uint256[](7);
        amountsFromUSDC[0] = _addDecimals(100, USDC_DECIMALS);
        amountsFromUSDC[1] = _addDecimals(2500, USDC_DECIMALS);
        amountsFromUSDC[2] = _addDecimals(5000, USDC_DECIMALS);
        amountsFromUSDC[3] = _addDecimals(75000, USDC_DECIMALS);
        amountsFromUSDC[4] = _addDecimals(10000, USDC_DECIMALS);
        amountsFromUSDC[5] = _addDecimals(1_000_000, USDC_DECIMALS);
        amountsFromUSDC[6] = _addDecimals(5_000_000, USDC_DECIMALS);

        IPool asPool = IPool(poolUSDCETH);
        for (uint256 i; i < amountsFromUSDC.length; i++) {
            uint256 amountIn = amountsFromUSDC[i];
            console2.log("USDC i", i);
            console2.log("USDC amountIn", amountIn);
            console2.log("WBTC amountOut", asPool.getAmountOut(amountIn, USDC));
        }
    }

    // VELO STABLE
    function test_USDC_USDT() public {
        // Assumption is we always swap
        console2.log("Creating USDC-USDT Pool");
        uint256 USDC_IN = 1378798585397;
        uint8 USDC_DECIMALS = 6;
        uint256 USDT_IN = 1204218837708;
        (address poolUSDCUSDT, address USDC, address USDT) =
            _setupNewPool(true, USDC_IN, USDC_DECIMALS, USDT_IN, USDC_DECIMALS);

        // Let's do amounts and swaps
        uint256[] memory amountsFromUSDC = new uint256[](5);
        amountsFromUSDC[0] = _addDecimals(100, USDC_DECIMALS);
        amountsFromUSDC[1] = _addDecimals(10000, USDC_DECIMALS);
        amountsFromUSDC[2] = _addDecimals(1_000_000, USDC_DECIMALS);
        amountsFromUSDC[3] = _addDecimals(5_000_000, USDC_DECIMALS);
        amountsFromUSDC[4] = _addDecimals(25_000_000, USDC_DECIMALS);

        IPool asPool = IPool(poolUSDCUSDT);
        for (uint256 i; i < amountsFromUSDC.length; i++) {
            uint256 amountIn = amountsFromUSDC[i];
            console2.log("USDC i", i);
            console2.log("USDC amountIn", amountIn);
            console2.log("USDT amountOut", asPool.getAmountOut(amountIn, USDC));
        }
    }

    function _addDecimals(uint256 value, uint256 decimals) internal pure returns (uint256) {
        return value * 10 ** decimals;
    }
}
