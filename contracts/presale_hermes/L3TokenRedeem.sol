// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "../presale_hermes/L3PltsSwap.sol";

/// @title Contract that swaps { PreHermes} for { Hermes}.
/// @dev This contract should have { Hermes} balance to work properly
/// @custom:note Total pre-minted L3 tokens are sent to this contract before start.
contract L3HermesTokenRedeem is Ownable, ReentrancyGuard {
    address public constant BURN_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

    address public constant FEE_ADDRESS =
        0x1109c5BB8Abb99Ca3BBeff6E60F5d3794f4e0473;

    address public immutable preHermesAddress;

    address public immutable hermesAddress;

    L3PltsSwap public immutable l3PltsSwap;

    uint256 public startBlock;

    bool public hasRetrievedUnsoldPresale = false;

    event HermesSwap(address sender, uint256 amount);
    event RetrieveUnclaimedTokens(uint256 hermesAmount);
    event StartBlockChanged(uint256 newStartBlock);

    constructor(
        uint256 _startBlock,
        L3PltsSwap _l3PltsSwap,
        address _preHermesAddress,
        address _hermesAddress
    ) {
        require(
            block.number < _startBlock,
            "cannot set start block in the past!"
        );
        require(
            _preHermesAddress != _hermesAddress,
            "preHermes cannot be equal to Hermes"
        );
        require(
            _preHermesAddress != address(0),
            "_preHermesAddress cannot be the zero address"
        );
        require(
            _hermesAddress != address(0),
            "_HermesAddress cannot be the zero address"
        );

        startBlock = _startBlock;

        l3PltsSwap = _l3PltsSwap;

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

    /// @notice Sends any remaining L3 tokens to the fee address.
    /// @dev This can only be called once L3 token presale has ended
    /// @dev This can only be called once.
    function sendUnclaimedsToFeeAddress() external onlyOwner {
        require(
            block.number > l3PltsSwap.endBlock(),
            "can only retrieve excess tokens after plts swap has ended"
        );

        require(
            !hasRetrievedUnsoldPresale,
            "can only burn unsold presale once!"
        );

        uint256 wastedPreHermesTokens = l3PltsSwap.preHermesRemaining();

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
