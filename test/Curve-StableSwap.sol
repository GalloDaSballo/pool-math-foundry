// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "./tERC20.sol";

// Token A
// Token B
// NOTE: Must be on OP FORK

// FACTORY
// https://optimistic.etherscan.io/address/0x2db0e83599a91b508ac268a6197b8b14f5e72840#code

/**
 * def deploy_plain_pool(
 *     _name: String[32],
 *     _symbol: String[10],
 *     _coins: address[4],
 *     _A: uint256,
 *     _fee: uint256,
 *     _asset_type: uint256 = 0, //     _asset_type Asset type for pool, as an integer  0 = USD, 1 = ETH, 2 = BTC, 3 = Other
 *     _implementation_idx: uint256 = 0,
 */
interface IFactory {
    function deploy_plain_pool(
        string memory name,
        string memory symbol,
        address[4] memory _coins,
        uint256 A,
        uint256 fee,
        uint256 assetType
    ) external returns (address);
}

interface IOracle {
    function latestAnswer() external view returns (uint256);
}

interface IPool {
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external returns (uint256);
    function add_liquidity(uint256[3] memory amounts, uint256 min_mint_amount) external returns (uint256);
    function add_liquidity(uint256[4] memory amounts, uint256 min_mint_amount) external returns (uint256);

    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);
    function get_virtual_price() external view returns (uint256);
}

contract CurveStable is Test {
    uint256 MAX_BPS = 10_000;
    uint256 STABLE_FEES = 4000000;
    uint256 A = 5000;
    uint256 A_FOUR_POOL = 500;

    uint256 USD_TYPE = 0;
    uint256 ETH_TYPE = 1;
    uint256 BTC_TYPE = 2;
    uint256 OTHER_TYPE = 3;

    IFactory factory = IFactory(0x2db0E83599a91b508Ac268a6197b8B14F5e72840);

    address owner = address(123);

    function setUp() public {}

    function test_canDeploy() internal {
        tERC20 tokenA = new tERC20("A", "A", 18);
        tERC20 tokenB = new tERC20("B", "B", 18);

        address[4] memory tokens = [address(tokenA), address(tokenB), address(0), address(0)];

        factory.deploy_plain_pool("w/e", "WE", tokens, A, STABLE_FEES, ETH_TYPE);
    }

    function _setupNewTwoTokenPool(
        uint256 amountA,
        uint8 decimalsA,
        uint256 amountB,
        uint8 decimalsB,
        uint256 aValue,
        uint256 fees,
        uint256 poolType
    ) internal returns (address newPool, address firstToken, address secondToken) {
        // Deploy 2 mock tokens
        vm.startPrank(owner);
        tERC20 tokenA = new tERC20("A", "A", decimalsA);

        tERC20 tokenB = new tERC20("B", "B", decimalsB);

        address[4] memory tokens = [address(tokenA), address(tokenB), address(0), address(0)];

        newPool = factory.deploy_plain_pool("w/e", "WE", tokens, aValue, fees, poolType);

        tokenA.approve(newPool, amountA);
        tokenB.approve(newPool, amountB);

        uint256[2] memory amountsToAdd = [amountA, amountB];
        IPool(newPool).add_liquidity(amountsToAdd, 0);

        return (newPool, address(tokenA), address(tokenB));
    }

    struct ThreeTokens {
        uint256 amountA;
        uint8 decimalsA;
        uint256 amountB;
        uint8 decimalsB;
        uint256 amountC;
        uint8 decimalsC;
    }

    function _setupNewThreeTokenPool(ThreeTokens memory threeTokens, uint256 aValue, uint256 fees, uint256 poolType)
        internal
        returns (address newPool, address firstToken, address secondToken, address thirdToken)
    {
        // Deploy 2 mock tokens
        vm.startPrank(owner);
        tERC20 tokenA = new tERC20("A", "A", threeTokens.decimalsA);
        tERC20 tokenB = new tERC20("B", "B", threeTokens.decimalsB);
        tERC20 tokenC = new tERC20("C", "C", threeTokens.decimalsC);

        address[4] memory tokens = [address(tokenA), address(tokenB), address(tokenC), address(0)];
        newPool = factory.deploy_plain_pool("w/e", "WE", tokens, aValue, fees, poolType);
        {
            tokenA.approve(newPool, threeTokens.amountA);
            tokenB.approve(newPool, threeTokens.amountB);
            tokenC.approve(newPool, threeTokens.amountC);
        }

        uint256[3] memory amountsToAdd = [threeTokens.amountA, threeTokens.amountB, threeTokens.amountC];
        IPool(newPool).add_liquidity(amountsToAdd, 0);

        return (newPool, address(tokenA), address(tokenB), address(tokenC));
    }

    function test_wstETH_ETH() public {
        console2.log("Creating wstETH-ETH Pool");
        // https://optimistic.etherscan.io/address/0xB90B9B1F91a01Ea22A182CD84C1E22222e39B415#readContract
        // Balance 0 is ETH, balance 1 is wstETH
        uint256 WSTETH_IN = 4540302536030246428213;
        uint8 WSTETH_DECIMALS = 18;

        uint256 WETH_IN = 5110270280714989617844;
        uint8 WETH_DECIMALS = 18;

        // This is to adjust price
        // ORACLE for proper math
        // https://optimistic.etherscan.io/address/0xe59eba0d492ca53c6f46015eea00517f2707dc77#readContract
        IOracle oracle = IOracle(0xe59EBa0D492cA53C6f46015EEa00517F2707dc77);

        (address curvePool, address WSTETH, address WETH) =
            _setupNewTwoTokenPool(WSTETH_IN, WSTETH_DECIMALS, WETH_IN, WETH_DECIMALS, A, STABLE_FEES, ETH_TYPE);

        // Let's do amounts and swaps
        uint256[] memory amountsFromWSTETH = new uint256[](5);
        amountsFromWSTETH[0] = _addDecimals(1, WSTETH_DECIMALS);
        amountsFromWSTETH[1] = _addDecimals(10, WSTETH_DECIMALS);
        amountsFromWSTETH[2] = _addDecimals(1000, WSTETH_DECIMALS);
        amountsFromWSTETH[3] = _addDecimals(10_000, WSTETH_DECIMALS);
        amountsFromWSTETH[4] = _addDecimals(100_000, WSTETH_DECIMALS);

        IPool asPool = IPool(curvePool);
        for (uint256 i; i < amountsFromWSTETH.length; i++) {
            uint256 amountIn = amountsFromWSTETH[i];
            console2.log("WSTETH i", i);
            console2.log("WSTETH amountIn", amountIn);
            uint256 dy = asPool.get_dy(0, 1, amountIn);
            console2.log("WSTETH amountOut", dy);
            // NOTE: We adjust the price here, this math is incorrect but by a << 1/10_000 margin of error
            console2.log("WSTETH amountOut adjusted", dy * oracle.latestAnswer() / 1e18);
        }
    }

    // For Four Pool we will use 3 pool and apply the rate as well,
    // As the rate change is basically a virtual_price of difference, meaning that we should be accurate within a reasonable margin of error
    function test_sUSD_3Pool() public {
        console2.log("Creating  sUSD3Pool");
        // https://optimistic.etherscan.io/address/0x061b87122Ed14b9526A813209C8a59a633257bAb
        // 0 sUSD
        // 0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9
        // 1 is 3Pool
        uint256 SUSD_IN = 10499034674015099569330803;
        uint8 SUSD_DECIMALS = 18;

        uint256 THREE_POOL_IN = 8503345729124878946468884;
        uint8 THREE_POOL_DECIMALS = 18;

        (address curvePool, address SUSD, address THREE_POOL) = _setupNewTwoTokenPool(
            SUSD_IN, SUSD_DECIMALS, THREE_POOL_IN, THREE_POOL_DECIMALS, A_FOUR_POOL, STABLE_FEES, USD_TYPE
        );

        // TO ADJUST
        // https://optimistic.etherscan.io/address/0x1337BedC9D22ecbe766dF105c9623922A27963EC
        IPool toAdjust = IPool(0x1337BedC9D22ecbe766dF105c9623922A27963EC);

        // Let's do amounts and swaps
        uint256[] memory amountsFromSUSD = new uint256[](5);
        amountsFromSUSD[0] = _addDecimals(100, SUSD_DECIMALS);
        amountsFromSUSD[1] = _addDecimals(10_000, SUSD_DECIMALS);
        amountsFromSUSD[2] = _addDecimals(150_000, SUSD_DECIMALS);
        amountsFromSUSD[3] = _addDecimals(2_000_000, SUSD_DECIMALS);
        amountsFromSUSD[4] = _addDecimals(15_000_000, SUSD_DECIMALS);

        IPool asPool = IPool(curvePool);
        for (uint256 i; i < amountsFromSUSD.length; i++) {
            uint256 amountIn = amountsFromSUSD[i];
            console2.log("sUSD i", i);
            console2.log("sUSD amountIn", amountIn);
            uint256 dy = asPool.get_dy(0, 1, amountIn);
            console2.log("sUSD amountOut of 3CRV", dy);
            // NOTE: It's a negative adjustment // Also doesn't include the fees from the other pool
            console2.log("sUSD amountOut of 3CRV Adjust by Virtual Price", dy * 1e18 / toAdjust.get_virtual_price());
        }
    }
    // From sUSD to 3 Pool is one thing
    // From 3Pool to 3Pool is this one

    function test_3Pool() public {
        console2.log("Creating 3 Pool");
        // https://optimistic.etherscan.io/address/0x1337BedC9D22ecbe766dF105c9623922A27963EC#readContract
        // Balance 0 is DAI
        // Balance 1 is USDC
        // Balance 2 is USDT

        uint256 DAI_IN = 5105490430369593570566334;
        uint8 DAI_DECIMALS = 18;

        uint256 USDC_IN = 2899439195495;
        uint8 USDC_DECIMALS = 6;

        uint256 USDT_IN = 1759099131964;
        uint8 USDT_DECIMALS = 6;

        // NOTE: We must normalize the weights
        uint256 ADJUSTED_DAI = DAI_IN * 10 ** USDC_DECIMALS / 10 ** DAI_DECIMALS;

        // NOTE: Technically fee is 1 bps but we cannot do it via the factory
        (address curvePool,,,) = _setupNewThreeTokenPool(
            ThreeTokens(ADJUSTED_DAI, USDC_DECIMALS, USDC_IN, USDC_DECIMALS, USDT_IN, USDT_DECIMALS), 2000, STABLE_FEES, USD_TYPE
        );

        // Let's do amounts and swaps
        uint256[] memory amountsFromDAI = new uint256[](5);
        amountsFromDAI[0] = _addDecimals(100, USDC_DECIMALS);
        amountsFromDAI[1] = _addDecimals(10_000, USDC_DECIMALS);
        amountsFromDAI[2] = _addDecimals(150_000, USDC_DECIMALS);
        amountsFromDAI[3] = _addDecimals(2_000_000, USDC_DECIMALS);
        amountsFromDAI[4] = _addDecimals(15_000_000, USDC_DECIMALS);

        IPool asPool = IPool(curvePool);

        for (uint256 i; i < amountsFromDAI.length; i++) {
            uint256 amountIn = amountsFromDAI[i];
            console2.log("DAI i", i);
            console2.log("DAI amountIn (normalized)", amountIn);
            console2.log("DAI amountIn real", amountIn * 10 ** DAI_DECIMALS / 10 ** USDC_DECIMALS);
            uint256 dy = asPool.get_dy(0, 1, amountIn);
            console2.log("dAI amountOut of USDC", dy);
            console2.log("DAI amountOut of USDC adjusted for fees", dy * 10003 / 10000);
        }

        // Let's do amounts and swaps
        uint256[] memory amountsFromUSDC = new uint256[](5);
        amountsFromUSDC[0] = _addDecimals(100, USDC_DECIMALS);
        amountsFromUSDC[1] = _addDecimals(10_000, USDC_DECIMALS);
        amountsFromUSDC[2] = _addDecimals(150_000, USDC_DECIMALS);
        amountsFromUSDC[3] = _addDecimals(2_000_000, USDC_DECIMALS);
        amountsFromUSDC[4] = _addDecimals(15_000_000, USDC_DECIMALS);

        for (uint256 i; i < amountsFromUSDC.length; i++) {
            uint256 amountIn = amountsFromUSDC[i];
            console2.log("USDC i", i);
            console2.log("USDC amountIn", amountIn);
            uint256 dy = asPool.get_dy(1, 2, amountIn);
            console2.log("USDC amountOut of USDT", dy);
            console2.log("USDC amountOut of USDT adjusted for fees", dy * 10003 / 10000);
        }
    }

    function _addDecimals(uint256 value, uint256 decimals) internal pure returns (uint256) {
        return value * 10 ** decimals;
    }
}
