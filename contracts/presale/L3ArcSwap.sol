// SPDX-License-Identifier: GPL-3.0

// 0x36e07796a249dEdF8cD486544FA7d8Bd75f5D56A polygon
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Contract that swaps arc token for PreDarkside and PreCZDiamond tokens.
/// @dev This contract should have l3 presale balance to work properly.
/// @dev PreCZDiamond balance should at least be equal [preCZDiamondMaximumAvailable].
/// @dev PreDarkside balance should at least be equal [preDarksideMaximumAvailable].
/// @dev Any remaining presale tokens stay in this contract after pre-sale ends.
/// @custom:note Only ~42.9% of minted L3presale tokens were sent to this contract.
/// The rest is sent to the other swap contract
contract L3ArcSwap is Ownable, ReentrancyGuard {
    address public constant feeAddress =
        0x3a1D1114269d7a786C154FE5278bF5b1e3e20d31;

    address public constant arcadiumAddress =
        0x3F374ed3C8e61A0d250f275609be2219005c021e;
    address public immutable preCZDiamondAddress;
    address public immutable preDarksideAddress;

    uint256 public constant arcSwapPresaleSize = 834686 * (10**18); // XXX amount of ARC expected to be swapped?

    uint256 public preCZDiamondSaleINVPriceE35 = 1543664 * (10**27); // this inventory price (PCZDiamond/ARC) stays fixed during the sale.
    uint256 public preDarksideSaleINVPriceE35 = 12863864 * (10**27); // this inventory price (PDARK/ARC) stays fixed during the sale.

    uint256 public preCZDiamondMaximumAvailable =
        (arcSwapPresaleSize * preCZDiamondSaleINVPriceE35) / 1e35; // max amount of presale CZDiamond tokens available to swap
    uint256 public preDarksideMaximumAvailable =
        (arcSwapPresaleSize * preDarksideSaleINVPriceE35) / 1e35; // max amount of presale Dakside tokens available to swap

    // We use a counter to defend against people sending pre{CZDiamond,Darkside} back
    uint256 public preCZDiamondRemaining = preCZDiamondMaximumAvailable;
    uint256 public preDarksideRemaining = preDarksideMaximumAvailable;

    uint256 public constant oneHourMatic = 1500; // blocks per hour
    uint256 public constant presaleDuration = 71999; // blocks

    uint256 public startBlock;
    uint256 public endBlock = startBlock + presaleDuration;

    event PrePurchased(
        address sender,
        uint256 arcadiumSpent,
        uint256 preCZDiamondReceived,
        uint256 preDarksideReceived
    );
    event RetrieveDepreciatedArcTokens(address feeAddress, uint256 tokenAmount);
    event SaleINVPricesE35Changed(
        uint256 newCZDiamondSaleINVPriceE35,
        uint256 newDarksideSaleINVPriceE35
    );
    event StartBlockChanged(uint256 newStartBlock, uint256 newEndBlock);

    constructor(
        uint256 _startBlock,
        address _preCZDiamondAddress,
        address _preDarksideAddress
    ) {
        require(
            block.number < _startBlock,
            "cannot set start block in the past!"
        );
        require(
            arcadiumAddress != _preCZDiamondAddress,
            "arcadiumAddress cannot be equal to preCZDiamond"
        );
        require(
            _preCZDiamondAddress != _preDarksideAddress,
            "preCZDiamond cannot be equal to preDarkside"
        );
        require(
            _preCZDiamondAddress != address(0),
            "_preCZDiamondAddress cannot be the zero address"
        );
        require(
            _preDarksideAddress != address(0),
            "_preDarksideAddress cannot be the zero address"
        );

        startBlock = _startBlock;
        endBlock = _startBlock + presaleDuration;

        preCZDiamondAddress = _preCZDiamondAddress;
        preDarksideAddress = _preDarksideAddress;
    }

    /// @notice swap l2 token for l3 presale token.
    /// @dev Allows minimum of 1e6 token to be swapped.
    /// Requires l2 token approval.
    function swapArcForPresaleTokensL3(uint256 arcadiumToSwap)
        external
        nonReentrant
    {
        require(
            msg.sender != feeAddress,
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
            preCZDiamondRemaining > 0 && preDarksideRemaining > 0,
            "No more presale tokens remaining! Come back next time!"
        ); // check if any presale tokens remains
        require(
            IERC20(preCZDiamondAddress).balanceOf(address(this)) > 0,
            "No more PreCZDiamond left! Come back next time!"
        ); // check if cotract has presale tokens to give
        require(
            IERC20(preDarksideAddress).balanceOf(address(this)) > 0,
            "No more PreDarkside left! Come back next time!"
        ); // check if cotract has presale tokens to give
        require(arcadiumToSwap > 1e6, "not enough arcadium provided"); // requires a minimum arc token to swap

        uint256 originalPreCZDiamondAmount = (arcadiumToSwap *
            preCZDiamondSaleINVPriceE35) / 1e35;
        uint256 originalPreDarksideAmount = (arcadiumToSwap *
            preDarksideSaleINVPriceE35) / 1e35;

        uint256 preCZDiamondPurchaseAmount = originalPreCZDiamondAmount;
        uint256 preDarksidePurchaseAmount = originalPreDarksideAmount;

        // if we dont have enough left, give them the rest.
        if (preCZDiamondRemaining < preCZDiamondPurchaseAmount)
            preCZDiamondPurchaseAmount = preCZDiamondRemaining;

        if (preDarksideRemaining < preDarksidePurchaseAmount)
            preDarksidePurchaseAmount = preDarksideRemaining;

        require(
            preCZDiamondPurchaseAmount > 0,
            "user cannot purchase 0 preCZDiamond"
        );
        require(
            preDarksidePurchaseAmount > 0,
            "user cannot purchase 0 preDarkside"
        );

        // shouldn't be possible to fail these asserts.
        assert(preCZDiamondPurchaseAmount <= preCZDiamondRemaining);
        assert(
            preCZDiamondPurchaseAmount <=
                IERC20(preCZDiamondAddress).balanceOf(address(this))
        );

        assert(preDarksidePurchaseAmount <= preDarksideRemaining);
        assert(
            preDarksidePurchaseAmount <=
                IERC20(preDarksideAddress).balanceOf(address(this))
        );

        require(
            IERC20(preCZDiamondAddress).transfer(
                msg.sender,
                preCZDiamondPurchaseAmount
            ),
            "failed sending preCZDiamond"
        );
        require(
            IERC20(preDarksideAddress).transfer(
                msg.sender,
                preDarksidePurchaseAmount
            ),
            "failed sending preDarkside"
        );

        preCZDiamondRemaining =
            preCZDiamondRemaining -
            preCZDiamondPurchaseAmount; // set the remainning amount
        preDarksideRemaining = preDarksideRemaining - preDarksidePurchaseAmount;

        require(
            IERC20(arcadiumAddress).transferFrom(
                msg.sender,
                address(this),
                arcadiumToSwap
            ),
            "failed to collect arcadium from user"
        );

        emit PrePurchased(
            msg.sender,
            arcadiumToSwap,
            preCZDiamondPurchaseAmount,
            preDarksidePurchaseAmount
        );
    }

    /// @notice Sends any ARC swapped with this contract back to the fee address.
    /// @dev Can only be used once sale has ended.
    function sendDepreciatedArcToFeeAddress() external onlyOwner {
        require(
            block.number > endBlock,
            "can only retrieve excess tokens after arcadium swap has ended"
        );

        uint256 arcadiumInContract = IERC20(arcadiumAddress).balanceOf(
            address(this)
        );

        if (arcadiumInContract > 0)
            IERC20(arcadiumAddress).transfer(feeAddress, arcadiumInContract);

        emit RetrieveDepreciatedArcTokens(feeAddress, arcadiumInContract);
    }

    /// @notice Sets the sale prices of PreCZDiamond & PreDarkside tokens.
    /// @dev Prices can only be changed up to 4 hrs efore start time.
    /// @param _newPreCZDiamondSaleINVPriceE35 new PreCZDiamond price.
    /// @param _newPreDarksideSaleINVPriceE35 new PreDarkside price.
    function setSaleINVPriceE35(
        uint256 _newPreCZDiamondSaleINVPriceE35,
        uint256 _newPreDarksideSaleINVPriceE35
    ) external onlyOwner {
        require(
            block.number < startBlock - (oneHourMatic * 4),
            "cannot change price 4 hours before start block"
        );
        require(
            _newPreCZDiamondSaleINVPriceE35 >= 1 * (10**32),
            "new CZD price is to high!"
        );
        require(
            _newPreCZDiamondSaleINVPriceE35 <= 1 * (10**34),
            "new CZD price is too low!"
        ); //TODO: create test with price at max. This seems like swapping the total arcadia would require more than the total supply of PCZDiamond.

        require(
            _newPreDarksideSaleINVPriceE35 >= 9 * (10**32),
            "new Darkside price is to high!"
        );
        require(
            _newPreDarksideSaleINVPriceE35 <= 9 * (10**34),
            "new Darkside price is too low!"
        );

        preCZDiamondSaleINVPriceE35 = _newPreCZDiamondSaleINVPriceE35;
        preDarksideSaleINVPriceE35 = _newPreDarksideSaleINVPriceE35;

        preCZDiamondMaximumAvailable =
            (arcSwapPresaleSize * preCZDiamondSaleINVPriceE35) /
            1e35;
        preDarksideMaximumAvailable =
            (arcSwapPresaleSize * preDarksideSaleINVPriceE35) /
            1e35;

        preCZDiamondRemaining = preCZDiamondMaximumAvailable;
        preDarksideRemaining = preDarksideMaximumAvailable;

        emit SaleINVPricesE35Changed(
            preCZDiamondSaleINVPriceE35,
            preDarksideSaleINVPriceE35
        );
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
