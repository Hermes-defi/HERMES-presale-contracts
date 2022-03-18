// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "../presale_hermes/L3PltsSwapBank.sol";
import "../presale_hermes/L3PltsSwapGen.sol";

/// @title Contract that swaps { PreHermes} for { Hermes}.
/// @dev This contract should have { Hermes} balance to work properly
/// @custom:note Total pre-minted L3 tokens are sent to this contract before start.
contract L3HermesTokenRedeem is Ownable, ReentrancyGuard {
    address public constant BURN_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

    address public constant FEE_ADDRESS =
        0x7cef2432A2690168Fb8eb7118A74d5f8EfF9Ef55;

    address public immutable preHermesAddress;

    address public immutable hermesAddress;

    L3PltsSwapBank public immutable l3PltsSwapBank;
    L3PltsSwapGen public immutable l3PltsSwapGen;

    uint256 public startBlock;

    bool public hasRetrievedUnsoldPresale = false;

    event HermesSwap(address sender, uint256 amount);
    event RetrieveUnclaimedTokens(uint256 hermesAmount);
    event StartBlockChanged(uint256 newStartBlock);

    constructor(
        uint256 _startBlock,
        L3PltsSwapBank _l3PltsSwapBank,
        L3PltsSwapGen _l3PltsSwapGen,
        address _preHermesAddress,
        address _hermesAddress
    ) {
        require(
            block.number < _startBlock,
            "cannot set start block in the past!"
        );
        require(
            _preHermesAddress != _hermesAddress,
            "preHermes cannot be equal to Hermes."
        );
        require(
            _preHermesAddress != address(0),
            "_preHermesAddress cannot be the zero address."
        );
        require(
            _hermesAddress != address(0),
            "_HermesAddress cannot be the zero address."
        );
        require(
            address(_l3PltsSwapBank) != address(_l3PltsSwapGen),
            "Incorrect presale contract address."
        );

        startBlock = _startBlock;

        l3PltsSwapBank = _l3PltsSwapBank;
        l3PltsSwapGen = _l3PltsSwapGen;

        preHermesAddress = _preHermesAddress;

        hermesAddress = _hermesAddress;
    }

    /// @notice swaps PreHermes token for Hermes token at 1:1 ratio.
    /// @param hermesSwapAmount amount of pre-sale tokens to swap for L3 token.
    /// @dev the pre-sale token is sent to dead address.
    function swapPreHermesForHermes(uint256 hermesSwapAmount)
        external
        nonReentrant
    {
        require(
            block.number >= startBlock,
            "token redemption hasn't started yet, good things come to those that wait"
        );
        require(
            IERC20(hermesAddress).balanceOf(address(this)) >= hermesSwapAmount,
            "Not Enough tokens in contract for swap"
        );

        IERC20(preHermesAddress).transferFrom(
            msg.sender,
            BURN_ADDRESS,
            hermesSwapAmount
        );
        IERC20(hermesAddress).transfer(msg.sender, hermesSwapAmount);

        emit HermesSwap(msg.sender, hermesSwapAmount);
    }

    /// @notice Sends any unclaimed L3 tokens to the fee address.
    /// @dev This can only be called once, after L3 token presale has ended.
    function sendUnclaimedsToFeeAddress() external onlyOwner {
        require(
            block.number > l3PltsSwapBank.endBlock(),
            "can only retrieve excess tokens after presale has ended."
        );

        require(
            block.number > l3PltsSwapGen.endBlock(),
            "can only retrieve excess tokens after presale has ended."
        );

        require(
            !hasRetrievedUnsoldPresale,
            "can only burn unsold presale once!"
        );

        uint256 wastedPreHermesTokens = l3PltsSwapBank.preHermesRemaining() +
            l3PltsSwapGen.preHermesRemaining();

        require(
            wastedPreHermesTokens <=
                IERC20(hermesAddress).balanceOf(address(this)),
            "retreiving too much preHermes, has this been setup properly?"
        );

        if (wastedPreHermesTokens > 0)
            IERC20(hermesAddress).transfer(FEE_ADDRESS, wastedPreHermesTokens);

        hasRetrievedUnsoldPresale = true;

        emit RetrieveUnclaimedTokens(wastedPreHermesTokens);
    }

    /// @notice set the start block to begin trading.
    /// @dev can only change start block if sale has not yet started.
    /// @param _newStartBlock new block number when sale should begin.
    function setStartBlock(uint256 _newStartBlock) external onlyOwner {
        require(
            block.number < startBlock,
            "cannot change start block if sale has already commenced"
        );
        require(
            block.number < _newStartBlock,
            "cannot set start block in the past"
        );
        startBlock = _newStartBlock;

        emit StartBlockChanged(_newStartBlock);
    }
}
