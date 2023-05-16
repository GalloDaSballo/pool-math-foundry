// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// Token A
// Token B
// NOTE: Must be on OP Fork
// NOTE: We use Compostable since it's same math but without rate provider
// When comparing pools with rates, you can adjust the values before

// Vault: 0xba12222222228d8ba445958a75a0704d566bf2c8
// https://optimistic.etherscan.io/address/0xba12222222228d8ba445958a75a0704d566bf2c8

// Factory: 0xe2e901ab09f37884ba31622df3ca7fc19aa443be
// https://optimistic.etherscan.io/address/0xe2e901ab09f37884ba31622df3ca7fc19aa443be

// Settings for Pool scraped from
// https://optimistic.etherscan.io/tx/0x6409b38ffe5a647a44cabe322380ca81f37ffa4bead674bdb49bff96814a58bc
// Go and grab them from there



contract tERC20 is ERC20 {
    uint8 public immutable _decimals;
    constructor(string memory name, string memory symbol, uint8 __decimals) ERC20(name, symbol) {
        _decimals = __decimals;

        _mint(msg.sender, 1e36);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}


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
    function mint(address to) external returns (uint256 liquidity);
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
}

contract BalancerStable is Test {
    uint256 MAX_BPS = 10_000;

    IFactory factory = IFactory(0xe2E901AB09f37884BA31622dF3Ca7FC19AA443Be);

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

    function _setupNewPool(TokensAndRates memory settings )
        internal
        returns (address newPool, address firstToken, address secondToken)
    {
        // Deploy 2 mock tokens
        vm.startPrank(owner);
        tERC20 tokenA = new tERC20("A", "A", settings.decimalsA);
        tERC20 tokenB = new tERC20("B", "B", settings.decimalsB);

        // Deploy the pool
        // Scope due to SO
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
            factory.create("Pool", "POOL", tokens, 570, rates, durations, set, 100000000000000, address(0));
        }

        

        return (newPool, address(tokenA), address(tokenB));
    }

    // VELO VARIABLE
    function test_USDC_WETH() public {
        // Assumption is we always swap
        console2.log("Creating TODO Pool");
        _setupNewPool(
            TokensAndRates(
                10, // amtA
                18, // decimalsA
                10,
                18,
                1e18, // RateA
                1e18 // RateB
            )
        );
    }
    function _addDecimals(uint256 value, uint256 decimals) internal pure returns (uint256) {
        return value * 10 ** decimals;
    }
}
