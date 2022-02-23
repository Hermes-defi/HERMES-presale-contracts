// SPDX-License-Identifier: GPL-3.0

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

pragma solidity ^0.8.0;

/// @title the Hermes presale token.
/// @notice this contract is a standard ERC20, and mints all tokens to a specific address.
/// @dev the address minted to is the same as the fee adddress for the L3PltsSwap contract.
contract PreHermes is ERC20("pHermes", "PHRMS") {
    constructor() {
        _mint(
            address(0x1109c5BB8Abb99Ca3BBeff6E60F5d3794f4e0473),
            uint256(1811855 * (10**18))
        );
    }
}
