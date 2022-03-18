// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

contract Hermes is
    Ownable,
    ERC20("Hermes", "HRMS"),
    ERC20Capped(30000000 ether),
    AccessControl
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // events are handled by access control
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }

    function burn(address _account, uint256 amount)
        public
        onlyRole(BURNER_ROLE)
    {
        _burn(_account, amount);
    }

    function mint(address _account, uint256 _amount)
        public
        onlyRole(MINTER_ROLE)
    {
        _mint(_account, _amount);
    }

    function grantMinterRole(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _grantRole(MINTER_ROLE, _account);
    }

    function grantBurnerRole(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _grantRole(BURNER_ROLE, _account);
    }

    function revokeMinterRole(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _revokeRole(MINTER_ROLE, _account);
    }

    function revokeBurnerRole(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _revokeRole(BURNER_ROLE, _account);
    }

    function _mint(address account, uint256 amount)
        internal
        virtual
        override(ERC20, ERC20Capped)
    {
        super._mint(account, amount);
    }

    function transferOwnership(address newOwner)
        public
        virtual
        override
        onlyOwner
    {
        require(newOwner != address(0), "Ownable: new owner is zero address");
        _grantRole(DEFAULT_ADMIN_ROLE, newOwner);
        renounceRole(DEFAULT_ADMIN_ROLE, msg.sender);
        renounceRole(MINTER_ROLE, msg.sender);
        renounceRole(BURNER_ROLE, msg.sender);
        _transferOwnership(newOwner);
    }
}
