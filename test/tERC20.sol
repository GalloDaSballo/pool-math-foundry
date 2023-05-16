// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

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