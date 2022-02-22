// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

contract Hermes is
    Ownable,
    ERC20("Hermes", "HRMS"),
    ERC20Capped(30000000 ether)
{
    function burn(address _account, uint256 amount) public onlyOwner {
        _burn(_account, amount);
    }

    function mint(address _account, uint256 _amount) public onlyOwner {
        _mint(_account, _amount);
    }

    function _mint(address account, uint256 amount)
        internal
        virtual
        override(ERC20, ERC20Capped)
    {
        super._mint(account, amount);
    }
}
