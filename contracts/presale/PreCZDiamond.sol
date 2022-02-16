// SPDX-License-Identifier: GPL-3.0

// 0xde4c826179aeA9DE46a7ed0E103848FA7373ca45

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

pragma solidity ^0.8.0;

// PreCZDiamond
contract PreCZDiamond is ERC20("PCZDIAMOND", "PCZDIAMOND") {
    constructor() {
        _mint(
            address(0x3a1D1114269d7a786C154FE5278bF5b1e3e20d31),
            uint256(30000 * (10**18))
        );
    }
}
