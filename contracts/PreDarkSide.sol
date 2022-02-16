// SPDX-License-Identifier: GPL-3.0
// 0x3e67aF60f168B9B2adaDb57164d6726764ffaF0A

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../libs/IERC20.sol";
import "../libs/ERC20.sol";

// PreDarkside
contract PreDarkside is ERC20("PDARKCOIN", "PDARK") {
    constructor() {
        _mint(
            address(0x3a1D1114269d7a786C154FE5278bF5b1e3e20d31),
            uint256(250000 * (10**18))
        );
    }
}
