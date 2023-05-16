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
    def deploy_plain_pool(
    _name: String[32],
    _symbol: String[10],
    _coins: address[4],
    _A: uint256,
    _fee: uint256,
    _asset_type: uint256 = 0, //     _asset_type Asset type for pool, as an integer  0 = USD, 1 = ETH, 2 = BTC, 3 = Other
    _implementation_idx: uint256 = 0,
 */
interface IFactory {
    function deploy_plain_pool(string memory name, string memory symbol, address[4] memory _coins, uint256 A, uint256 fee, uint256 assetType) external returns (address);
}

interface IPool {
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external returns (uint256);
    function add_liquidity(uint256[3] memory amounts, uint256 min_mint_amount) external returns (uint256);
    function add_liquidity(uint256[4] memory amounts, uint256 min_mint_amount) external returns (uint256);

    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);
}

contract CurveStable is Test {
    uint256 MAX_BPS = 10_000;
    uint256 STABLE_FEES = 4000000;
    uint256 A = 5000;

    uint256 USD_TYPE = 0;
    uint256 ETH_TYPE = 1;
    uint256 BTC_TYPE = 2;
    uint256 OTHER_TYPE = 3;

    IFactory factory = IFactory(0x2db0E83599a91b508Ac268a6197b8B14F5e72840);

    address owner = address(123);

    function setUp() public {}

    function test_canDeploy() public {
        tERC20 tokenA = new tERC20("A", "A", 18);
        tERC20 tokenB = new tERC20("B", "B", 18);
        
        address[4] memory tokens = [address(tokenA), address(tokenB), address(0), address(0)];

        factory.deploy_plain_pool("w/e", "WE", tokens, A, STABLE_FEES, USD_TYPE);
    }

    function _addDecimals(uint256 value, uint256 decimals) internal pure returns (uint256) {
        return value * 10 ** decimals;
    }
}

// ETH wstETH
// https://optimistic.etherscan.io/address/0xB90B9B1F91a01Ea22A182CD84C1E22222e39B415
/**
 */