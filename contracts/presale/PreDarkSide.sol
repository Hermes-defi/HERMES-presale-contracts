// SPDX-License-Identifier: GPL-3.0
// 0x3e67aF60f168B9B2adaDb57164d6726764ffaF0A

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

pragma solidity ^0.8.0;

/// @title the Darkside presale token.
/// @notice this contract is a standard ERC20, and mints all tokens to a specific address.
/// @dev the address minted to is the same as the fee adddress for the L3ArcSwap contract.
contract PreDarkside is ERC20("PDARKCOIN", "PDARK") {
    constructor() {
        _mint(
            address(0x3a1D1114269d7a786C154FE5278bF5b1e3e20d31),
            uint256(250000 * (10**18))
        );
    }
}
