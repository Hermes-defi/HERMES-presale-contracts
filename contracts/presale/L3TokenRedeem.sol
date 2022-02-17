// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;
// 0x7ffA1Ccdc9fE9C0Ebcb8E4CE1c8ccc5D6f15418A

import "../presale/L3ArcSwap.sol";
import "../presale/L3MFSwap.sol";

/// @title Contract that swaps {PreCZDiamond; PreDarkside} for {CZDiamond; Darkside}.
/// @dev This contract should have {CZDiamond; Darkside} balance to work properly
/// @custom:note Total pre-minted L3 tokens are sent to this contract before start.
contract L3TokenRedeem is Ownable, ReentrancyGuard {
    address public constant BURN_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

    address public constant feeAddress =
        0x3a1D1114269d7a786C154FE5278bF5b1e3e20d31;

    address public immutable preCZDiamond;
    address public immutable preDarksideAddress;

    address public immutable CZDiamondAddress;
    address public immutable darksideAddress;

    L3ArcSwap public immutable l3ArcSwap;
    L3MFSwap public immutable l3MFSwap;

    uint256 public startBlock;

    bool public hasRetrievedUnsoldPresale = false;

    event CZDiamondSwap(address sender, uint256 amount);
    event DarksideSwap(address sender, uint256 amount);
    event RetrieveUnclaimedTokens(
        uint256 CZDiamondAmount,
        uint256 Darksidemount
    );
    event StartBlockChanged(uint256 newStartBlock);

    constructor(
        uint256 _startBlock,
        L3ArcSwap _l3ArcSwap,
        L3MFSwap _l3MFSwap,
        address _preCZDiamondAddress,
        address _preDarksideAddress,
        address _CZDiamondAddress,
        address _darksideAddress
    ) {
        require(
            block.number < _startBlock,
            "cannot set start block in the past!"
        );
        require(
            _preCZDiamondAddress != _preDarksideAddress,
            "preCZDiamond cannot be equal to preDarkside"
        );
        require(
            _CZDiamondAddress != _darksideAddress,
            "preCZDiamond cannot be equal to preDarkside"
        );
        require(
            _preCZDiamondAddress != address(0),
            "_preCZDiamondAddress cannot be the zero address"
        );
        require(
            _CZDiamondAddress != address(0),
            "_CZDiamondAddress cannot be the zero address"
        );

        startBlock = _startBlock;

        l3ArcSwap = _l3ArcSwap;
        l3MFSwap = _l3MFSwap;

        preCZDiamond = _preCZDiamondAddress;
        preDarksideAddress = _preDarksideAddress;
        CZDiamondAddress = _CZDiamondAddress;
        darksideAddress = _darksideAddress;
    }

    /// @notice swaps PreCZDiamond token for CZDiamond token at 1:1 ratio.
    /// @param CZDiamondSwapAmount amount of pre-sale tokens to swap for L3 token.
    /// @dev the pre-sale token is sent to dead address.
    function swapPreCZDiamondForCZDiamond(uint256 CZDiamondSwapAmount)
        external
        nonReentrant
    {
        require(
            block.number >= startBlock,
            "token redemption hasn't started yet, good things come to those that wait"
        );
        require(
            IERC20(CZDiamondAddress).balanceOf(address(this)) >=
                CZDiamondSwapAmount,
            "Not Enough tokens in contract for swap"
        );

        IERC20(preCZDiamond).transferFrom(
            msg.sender,
            BURN_ADDRESS,
            CZDiamondSwapAmount
        );
        IERC20(CZDiamondAddress).transfer(msg.sender, CZDiamondSwapAmount);

        emit CZDiamondSwap(msg.sender, CZDiamondSwapAmount);
    }

    /// @notice swaps PreDarkside token for Darkside token at 1:1 ratio.
    /// @param darksideSwapAmount amount of pre-sale tokens to swap for L3 token.
    /// @dev the pre-sale token is sent to dead address.
    function swapPreDarksideForDarkside(uint256 darksideSwapAmount)
        external
        nonReentrant
    {
        require(
            block.number >= startBlock,
            "token redemption hasn't started yet, good things come to those that wait"
        );
        require(
            IERC20(darksideAddress).balanceOf(address(this)) >=
                darksideSwapAmount,
            "Not Enough tokens in contract for swap"
        );

        IERC20(preDarksideAddress).transferFrom(
            msg.sender,
            BURN_ADDRESS,
            darksideSwapAmount
        );
        IERC20(darksideAddress).transfer(msg.sender, darksideSwapAmount);

        emit DarksideSwap(msg.sender, darksideSwapAmount);
    }

    /// @notice Sends any remaining L3 tokens to the fee address.
    /// @dev This can only be called once L3 token presale has ended
    /// @dev This can only be called once.
    function sendUnclaimedsToFeeAddress() external onlyOwner {
        require(
            block.number > l3ArcSwap.endBlock(),
            "can only retrieve excess tokens after arc swap has ended"
        );
        require(
            block.number > l3MFSwap.endBlock(),
            "can only retrieve excess tokens after myfriends swap has ended"
        );
        require(
            !hasRetrievedUnsoldPresale,
            "can only burn unsold presale once!"
        );

        uint256 wastedPreCZDiamondTokend = l3ArcSwap.preCZDiamondRemaining() +
            l3MFSwap.preCZDiamondRemaining();
        uint256 wastedPreDarksideTokens = l3ArcSwap.preDarksideRemaining() +
            l3MFSwap.preDarksideRemaining();

        require(
            wastedPreCZDiamondTokend <=
                IERC20(CZDiamondAddress).balanceOf(address(this)),
            "retreiving too much preCZDiamond, has this been setup properly?"
        );

        require(
            wastedPreDarksideTokens <=
                IERC20(darksideAddress).balanceOf(address(this)),
            "retreiving too much preDarkside, has this been setup properly?"
        );

        if (wastedPreCZDiamondTokend > 0)
            IERC20(CZDiamondAddress).transfer(
                feeAddress,
                wastedPreCZDiamondTokend
            );

        if (wastedPreDarksideTokens > 0)
            IERC20(darksideAddress).transfer(
                feeAddress,
                wastedPreDarksideTokens
            );

        hasRetrievedUnsoldPresale = true;

        emit RetrieveUnclaimedTokens(
            wastedPreCZDiamondTokend,
            wastedPreDarksideTokens
        );
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
