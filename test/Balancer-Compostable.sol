// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "./tERC20.sol";

/**
 * Note on Balancer work
 *     Due to extra complexity, we fork directly and perform the swaps
 *     This means we are just getting the spot liquidity values
 *     Tests will be less thorough, but they will demonstrate that we can match real values
 */

interface IFactory {
    function create(
        string memory name,
        string memory symbol,
        address[] memory tokens, // TokenA and B
        uint256 amplificationParameter, // 570
        address[] memory rateProviders, // Fake rate providers
        uint256[] memory tokenRateCacheDurations, // 1800
        bool[] memory exemptFromYieldProtocolFeeFlags, // false false
        uint256 swapFeePercentage, // 100000000000000
        address owner // address(0)
    ) external returns (address);
}
// Token A
// Token B
// Decimal A
// Decimal B
// Amount A
// AmountB
// RateA
// Rate B

// Rate provider for compostable
contract FakeRateProvider {
    uint256 public getRate = 1e18;

    constructor(uint256 newRate) {
        getRate = newRate;
    }
}

interface IPool {
    function getPoolId() external view returns (bytes32);
    function mint(address to) external returns (uint256 liquidity);
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);

    enum SwapKind {
        GIVEN_IN,
        GIVEN_OUT
    }

    struct BatchSwapStep {
        bytes32 poolId;
        uint256 assetInIndex;
        uint256 assetOutIndex;
        uint256 amount;
        bytes userData;
    }

    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address payable recipient;
        bool toInternalBalance;
    }

    function queryBatchSwap(
        SwapKind kind,
        BatchSwapStep[] memory swaps,
        address[] memory assets, // Note: same encoding
        FundManagement memory funds
    ) external returns (int256[] memory);

    function joinPool(bytes32 poolId, address sender, address recipient, JoinPoolRequest memory request)
        external
        payable;

    struct JoinPoolRequest {
        address[] assets;
        uint256[] maxAmountsIn;
        bytes userData;
        bool fromInternalBalance;
    }

    function getPoolTokens(bytes32 poolId)
        external
        view
        returns (address[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock);
}

contract BalancerStable is Test {
    uint256 MAX_BPS = 10_000;

    IFactory factory = IFactory(0xe2E901AB09f37884BA31622dF3Ca7FC19AA443Be);
    IPool vault = IPool(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    bytes32 SPECIALIZATION_MASK = 0x000000000000000000000000000000000000000000020000000000000000008b;

    // TODO: IGNORE
    function fromAddressToPoolId(address pool) public returns (bytes32) {
        bytes32 addyToBytes = bytes32(uint256(uint160(pool)) << 96);
        // Or the result since we know that all values in the last 12 bytes for X are 0
        // So we can append without masking since we know those are all 0s
        return addyToBytes | SPECIALIZATION_MASK;
    }

    address owner = address(123);

    function setUp() public {}

    struct TokensAndRates {
        uint256 amountA;
        uint8 decimalsA;
        uint256 amountB;
        uint8 decimalsB;
        uint256 rateA;
        uint256 rateB;
    }

    function _setupNewTwoTokenPool(TokensAndRates memory settings)
        internal
        returns (bytes32 poolId, address firstToken, address secondToken)
    {
        // Deploy 2 mock tokens
        vm.startPrank(owner);
        tERC20 tokenA = new tERC20("A", "A", settings.decimalsA);

        tERC20 tokenB = new tERC20("B", "B", settings.decimalsB);

        address newPool;
        {
            address[] memory tokens = new address[](2);
            tokens[0] = address(tokenA) > address(tokenB) ? address(tokenB) : address(tokenA);
            tokens[1] = address(tokenA) > address(tokenB) ? address(tokenA) : address(tokenB);

            address[] memory rates = new address[](2);
            rates[0] = address(new FakeRateProvider(settings.rateA));
            rates[1] = address(new FakeRateProvider(settings.rateB));

            uint256[] memory durations = new uint256[](2);
            durations[0] = 1800;
            durations[1] = 1800;

            bool[] memory set = new bool[](2);
            set[0] = false;
            set[1] = false;

            // Deploy new pool
            newPool = factory.create("Pool", "POOL", tokens, 570, rates, durations, set, 100000000000000, address(0));
        }

        poolId = IPool(newPool).getPoolId();

        (address[] memory setupPoolTokens,,) = vault.getPoolTokens(poolId);

        console2.log("setupPoolTokens", setupPoolTokens.length);
        console2.log("setupPoolTokens", setupPoolTokens[0]);
        console2.log("setupPoolTokens", setupPoolTokens[1]);
        console2.log("setupPoolTokens", setupPoolTokens[2]);
        {
            tokenA.approve(address(vault), settings.amountA);
            tokenB.approve(address(vault), settings.amountB);

            address[] memory assets = new address[](3);
            assets[0] = setupPoolTokens[0];
            assets[1] = setupPoolTokens[1];
            assets[2] = setupPoolTokens[2];

            uint256[] memory amountsToAdd = new uint256[](3);
            amountsToAdd[0] = setupPoolTokens[0] == address(tokenA)
                ? settings.amountA
                : setupPoolTokens[0] == address(tokenB) ? settings.amountB : 1e18;
            console2.log("amountsToAdd[0]", amountsToAdd[0]);

            amountsToAdd[1] = setupPoolTokens[1] == address(tokenA)
                ? settings.amountA
                : setupPoolTokens[1] == address(tokenB) ? settings.amountB : 1e18;
            console2.log("amountsToAdd[1]", amountsToAdd[1]);

            amountsToAdd[2] = setupPoolTokens[2] == address(tokenA)
                ? settings.amountA
                : setupPoolTokens[2] == address(tokenB) ? settings.amountB : 1e18;
            console2.log("amountsToAdd[2]", amountsToAdd[2]);

            vault.joinPool(poolId, owner, owner, IPool.JoinPoolRequest(assets, amountsToAdd, abi.encode(""), false));
        }

        return (poolId, address(tokenA), address(tokenB));
    }

    /**
     * https://optimistic.etherscan.io/address/0xba12222222228d8ba445958a75a0704d566bf2c8#readContract
     *     getPoolTokens
     *     0x7b50775383d3d6f0215a8f290f2c9e2eebbeceb200020000000000000000008b
     *
     *     1063322810377902132666,1394603632644752706329
     *
     *     getRateProviders
     *     CL
     *     -> getRATE
     *     1124504367992424664
     */

    function test_wstETH_WETH() public {
        // Assumption is we always swap
        console2.log("Creating wstETH WETH Pool");

        uint8 DECIMALS = 18;

        // Get whale
        // Have whale donate tokens
        address WSTETH = 0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb;
        address WETH = 0x4200000000000000000000000000000000000006;

        address WHALE = 0xc45A479877e1e9Dfe9FcD4056c699575a1045dAA;
        vm.startPrank(WHALE);
        tERC20(WSTETH).transfer(owner, _addDecimals(150, DECIMALS));
        vm.stopPrank();

        // Let's do amounts and swaps
        // Liquidity for this pair is up to 150 WSTETH
        uint256[] memory amountsFromWstETH = new uint256[](5);
        amountsFromWstETH[0] = _addDecimals(1, DECIMALS);
        amountsFromWstETH[1] = _addDecimals(10, DECIMALS);
        amountsFromWstETH[2] = _addDecimals(50, DECIMALS);
        amountsFromWstETH[3] = _addDecimals(100, DECIMALS);
        amountsFromWstETH[4] = _addDecimals(150, DECIMALS);

        bytes32 POOL_ID = bytes32(0x7b50775383d3d6f0215a8f290f2c9e2eebbeceb200020000000000000000008b);

        for (uint256 i; i < amountsFromWstETH.length; i++) {
            uint256 amountIn = amountsFromWstETH[i];
            console2.log("wstETH i", i);
            console2.log("wstETH amountIn (raw)", amountIn);
            uint256 res = _balSwap(POOL_ID, owner, amountIn, WSTETH, WETH);
            console2.log("WETH amountOut (raw)", res);
        }
    }

    // TODO: Need to figure out initialization of pool
    // function test_wstETH_WETHInternal() public {
    //     // Assumption is we always swap
    //     console2.log("Creating wstETH WETH Pool");

    //     uint256 WST_ETH_BAL = 1063322810377902132666;
    //     uint256 WST_ETH_RATE = 1124504367992424664;

    //     uint256 WETH_BAL = 1063322810377902132666;
    //     uint8 DECIMALS = 18;

    //     (bytes32 poolId, address WSTETH, address WETH) = _setupNewTwoTokenPool(
    //         TokensAndRates(
    //             WST_ETH_BAL,
    //             DECIMALS,
    //             WETH_BAL,
    //             DECIMALS,
    //             WST_ETH_RATE,
    //             DECIMALS // same as rate
    //         )
    //     );

    //     // Let's do amounts and swaps
    //     // Liquidity for this pair is up to 150 WSTETH
    //     uint256[] memory amountsFromWstETH = new uint256[](5);
    //     amountsFromWstETH[0] = _addDecimals(1, DECIMALS);
    //     amountsFromWstETH[1] = _addDecimals(10, DECIMALS);
    //     amountsFromWstETH[2] = _addDecimals(50, DECIMALS);
    //     amountsFromWstETH[3] = _addDecimals(100, DECIMALS);
    //     amountsFromWstETH[4] = _addDecimals(150, DECIMALS);

    //     bytes32 POOL_ID = poolId;

    //     for (uint256 i; i < amountsFromWstETH.length; i++) {
    //         uint256 amountIn = amountsFromWstETH[i];
    //         console2.log("wstETH i", i);
    //         console2.log("wstETH amountIn (raw)", amountIn);
    //         uint256 res = _balSwap(POOL_ID, owner, amountIn, WSTETH, WETH);
    //         console2.log("WETH amountOut (raw)", res);
    //     }
    // }

    function _balSwap(bytes32 poolId, address user, uint256 amountIn, address tokenIn, address tokenOut)
        internal
        returns (uint256)
    {
        vm.startPrank(user);

        tERC20(tokenIn).approve(address(vault), amountIn);

        IPool.BatchSwapStep[] memory steps = new IPool.BatchSwapStep[](1);
        steps[0] = IPool.BatchSwapStep(
            poolId,
            0,
            1,
            amountIn,
            abi.encode("") // Empty user data
        );

        address[] memory tokens = new address[](2);
        tokens[0] = tokenIn;
        tokens[1] = tokenOut;

        int256[] memory res = vault.queryBatchSwap(
            IPool.SwapKind.GIVEN_IN, steps, tokens, IPool.FundManagement(user, false, payable(user), false)
        );

        vm.stopPrank();

        // Negative means we receive those tokens
        if (res[1] > 0) {
            revert("invalid result");
        }

        return uint256(-res[1]);
    }

    function _addDecimals(uint256 value, uint256 decimals) internal pure returns (uint256) {
        return value * 10 ** decimals;
    }
}
