// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
pragma solidity ^0.8.0;

contract ERC721Wrapper is ERC721 {
    // FOR TESTING ONLY NOT FOR AUDIT!!!

    constructor(string memory name_, string memory symbol_)
        ERC721(name_, symbol_)
    {}
}
