// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Hermes is ERC20 {
    IERC20 public plutusToken;
    address public constant BURNADDRESS =
        0x000000000000000000000000000000000000dEaD;

    constructor(
        IERC20 _plutusToken,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        plutusToken = _plutusToken;
    }

    function deposit(uint256 amount) public {
        plutusToken.transferFrom(msg.sender, address(this), amount);
        // mint hermes
        _mint(msg.sender, amount);
        // burn plutus.
        plutusToken.transfer(BURNADDRESS, amount);
    }
}
