// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import "hardhat/console.sol";

/// @title Contract that swaps plutus token for PreHermes tokens.
/// @dev This contract should have l3 presale balance to work properly.
/// @dev PreHermes balance should at least be equal [preHermesMaximumAvailable].
/// @dev Any remaining presale tokens stay in this contract after pre-sale ends.
/// @custom:note Only ~42.9% of minted L3presale tokens were sent to this contract.
/// The rest is sent to the other swap contract
contract L3PltsSwap is Ownable, ReentrancyGuard {
    address public constant FEE_ADDRESS =
        0x1109c5BB8Abb99Ca3BBeff6E60F5d3794f4e0473;

    address public plutusAddress = 0xd32858211fcefd0be0dd3fd6d069c3e821e0aef3;

    address public immutable preHermesAddress;

    uint256 public constant pltsSwapPresaleSize = 834686 * (10**18); // XXX amount of PLTS expected to be swapped?

    uint256 public preHermesSaleINVPriceE35 = 12863864 * (10**27); // this inventory price (PHRMS/PLTS) stays fixed during the sale.

    uint256 public preHermesMaximumAvailable =
        (pltsSwapPresaleSize * preHermesSaleINVPriceE35) / 1e35; // max amount of presale Dakside tokens available to swap

    // We use a counter to defend against people sending pre{Hermes} back

    uint256 public preHermesRemaining = preHermesMaximumAvailable;

    uint256 public constant oneHourMatic = 1500; // blocks per hour
    uint256 public constant presaleDuration = 71999; // blocks

    uint256 public startBlock;
    uint256 public endBlock = startBlock + presaleDuration;

    event PrePurchased(
        address sender,
        uint256 plutusSpent,
        uint256 preHermesReceived
    );
    event RetrieveDepreciatedPltsTokens(
        address feeAddress,
        uint256 tokenAmount
    );
    event SaleINVPricesE35Changed(uint256 newHermesSaleINVPriceE35);
    event StartBlockChanged(uint256 newStartBlock, uint256 newEndBlock);

    constructor(
        uint256 _startBlock,
        address _plutusAddress, //TODO: remove from constructor and make constant
        address _preHermesAddress
    ) {
        require(
            block.number < _startBlock,
            "cannot set start block in the past!"
        );
        require(
            plutusAddress != _preHermesAddress,
            "plutusAddress cannot be equal to preHermes"
        );

        require(
            _preHermesAddress != address(0),
            "_preHermesAddress cannot be the zero address"
        );

        startBlock = _startBlock;
        endBlock = _startBlock + presaleDuration;

        preHermesAddress = _preHermesAddress;
        plutusAddress = _plutusAddress;
    }

    /// @notice swap l2 token for l3 presale token.
    /// @dev Allows minimum of 1e6 token to be swapped.
    /// Requires l2 token approval.
    /// @param plutusToSwap Amount of PLTS token to swap.
    function swapPltsForPresaleTokensL3(uint256 plutusToSwap)
        external
        nonReentrant
    {
        require(
            msg.sender != FEE_ADDRESS,
            "fee address cannot partake in presale"
        );
        require(
            block.number >= startBlock,
            "presale hasn't started yet, good things come to those that wait"
        );
        require(
            block.number < endBlock,
            "presale has ended, come back next time!"
        );
        require(
            preHermesRemaining > 0,
            "No more presale tokens remaining! Come back next time!"
        ); // check if any presale tokens remains

        require(
            IERC20(preHermesAddress).balanceOf(address(this)) > 0,
            "No more PreHermes left! Come back next time!"
        ); // check if cotract has presale tokens to give
        require(plutusToSwap > 1e6, "not enough plutus provided"); // requires a minimum plts token to swap

        uint256 originalPreHermesAmount = (plutusToSwap *
            preHermesSaleINVPriceE35) / 1e35;

        uint256 preHermesPurchaseAmount = originalPreHermesAmount;

        // if we dont have enough left, give them the rest.

        if (preHermesRemaining < preHermesPurchaseAmount)
            preHermesPurchaseAmount = preHermesRemaining;

        require(
            preHermesPurchaseAmount > 0,
            "user cannot purchase 0 preHermes"
        );

        // shouldn't be possible to fail these asserts.
        assert(preHermesPurchaseAmount <= preHermesRemaining);
        assert(
            preHermesPurchaseAmount <=
                IERC20(preHermesAddress).balanceOf(address(this))
        );

        require(
            IERC20(preHermesAddress).transfer(
                msg.sender,
                preHermesPurchaseAmount
            ),
            "failed sending preHermes"
        );

        preHermesRemaining = preHermesRemaining - preHermesPurchaseAmount;

        require(
            IERC20(plutusAddress).transferFrom(
                msg.sender,
                address(this),
                plutusToSwap
            ),
            "failed to collect plutus from user"
        );

        emit PrePurchased(msg.sender, plutusToSwap, preHermesPurchaseAmount);
    }

    /// @notice Sends any PLTS swapped with this contract back to the fee address.
    /// @dev Can only be used once sale has ended.
    function sendDepreciatedPltsToFeeAddress() external onlyOwner {
        require(
            block.number > endBlock,
            "can only retrieve excess tokens after plutus swap has ended"
        );

        uint256 plutusInContract = IERC20(plutusAddress).balanceOf(
            address(this)
        );

        if (plutusInContract > 0)
            IERC20(plutusAddress).transfer(FEE_ADDRESS, plutusInContract);

        emit RetrieveDepreciatedPltsTokens(FEE_ADDRESS, plutusInContract);
    }

    /// @notice Sets the sale prices of PreHermes tokens.
    /// @dev Prices can only be changed up to 4 hrs efore start time.
    /// @param _newPreHermesSaleINVPriceE35 new PreHermes price.
    function setSaleINVPriceE35(uint256 _newPreHermesSaleINVPriceE35)
        external
        onlyOwner
    {
        require(
            block.number < startBlock - (oneHourMatic * 4),
            "cannot change price 4 hours before start block"
        );

        require(
            _newPreHermesSaleINVPriceE35 >= 9 * (10**32),
            "new Hermes price is to high!"
        );
        require(
            _newPreHermesSaleINVPriceE35 <= 9 * (10**34),
            "new Hermes price is too low!"
        );

        preHermesSaleINVPriceE35 = _newPreHermesSaleINVPriceE35;

        preHermesMaximumAvailable =
            (pltsSwapPresaleSize * preHermesSaleINVPriceE35) /
            1e35;

        preHermesRemaining = preHermesMaximumAvailable;

        emit SaleINVPricesE35Changed(preHermesSaleINVPriceE35);
    }

    /// @notice Set the start block to begin trading.
    /// @dev Can only change start block if sale has not yet started.
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
        endBlock = _newStartBlock + presaleDuration;

        emit StartBlockChanged(_newStartBlock, endBlock);
    }
}
