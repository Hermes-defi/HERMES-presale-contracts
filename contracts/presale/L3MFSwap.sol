// SPDX-License-Identifier: GPL-3.0

// 0x71D6E3803E0C4C538620570D974bDB119e542B97
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract L3MFSwap is Ownable, ReentrancyGuard {
    address public constant feeAddress =
        0x3a1D1114269d7a786C154FE5278bF5b1e3e20d31;

    address public constant myFriendsAddress =
        0xa509Da749745Ac07E9Ae47E7a092eAd2648B47f2;
    address public immutable preCZDiamondAddress;
    address public immutable preDarksideAddress;

    uint256 public constant mfSwapPresaleSize = 66800 * (10**18);

    uint256 public preCZDiamondSaleINVPriceE35 = 25621640 * (10**27);
    uint256 public preDarksideSaleINVPriceE35 = 213513666 * (10**27);

    uint256 public preCZDiamondMaximumAvailable =
        (mfSwapPresaleSize * preCZDiamondSaleINVPriceE35) / 1e35;
    uint256 public preDarksideMaximumAvailable =
        (mfSwapPresaleSize * preDarksideSaleINVPriceE35) / 1e35;

    // We use a counter to defend against people sending pre{CZDiamond,Darkside} back
    uint256 public preCZDiamondRemaining = preCZDiamondMaximumAvailable;
    uint256 public preDarksideRemaining = preDarksideMaximumAvailable;

    uint256 public constant oneHourMatic = 1500;
    uint256 public constant presaleDuration = 71999;

    uint256 public startBlock;
    uint256 public endBlock = startBlock + presaleDuration;

    event PrePurchased(
        address sender,
        uint256 myFriendsSpent,
        uint256 preCZDiamondReceived,
        uint256 preDarksideReceived
    );
    event RetrieveDepreciatedMFTokens(address feeAddress, uint256 tokenAmount);
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
            myFriendsAddress != _preCZDiamondAddress,
            "myFriendsAddress cannot be equal to preCZDiamond"
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

    function swapMFForPresaleTokensL3(uint256 myFriendsToSwap)
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
        );
        require(
            IERC20(preCZDiamondAddress).balanceOf(address(this)) > 0,
            "No more PreCZDiamond left! Come back next time!"
        );
        require(
            IERC20(preDarksideAddress).balanceOf(address(this)) > 0,
            "No more PreDarkside left! Come back next time!"
        );
        require(myFriendsToSwap > 1e6, "not enough MyFriends provided");

        uint256 originalPreCZDiamondAmount = (myFriendsToSwap *
            preCZDiamondSaleINVPriceE35) / 1e35;
        uint256 originalPreDarksideAmount = (myFriendsToSwap *
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
            preCZDiamondPurchaseAmount;
        preDarksideRemaining = preDarksideRemaining - preDarksidePurchaseAmount;

        require(
            IERC20(myFriendsAddress).transferFrom(
                msg.sender,
                address(this),
                myFriendsToSwap
            ),
            "failed to collect myFriends from user"
        );

        emit PrePurchased(
            msg.sender,
            myFriendsToSwap,
            preCZDiamondPurchaseAmount,
            preDarksidePurchaseAmount
        );
    }

    function sendDepreciatedMFToFeeAddress() external onlyOwner {
        require(
            block.number > endBlock,
            "can only retrieve excess tokens after myfriends swap has ended"
        );

        uint256 myFriendsInContract = IERC20(myFriendsAddress).balanceOf(
            address(this)
        );

        if (myFriendsInContract > 0)
            IERC20(myFriendsAddress).transfer(feeAddress, myFriendsInContract);

        emit RetrieveDepreciatedMFTokens(feeAddress, myFriendsInContract);
    }

    function setSaleINVPriceE35(
        uint256 _newPreCZDiamondSaleINVPriceE35,
        uint256 _newPreDarksideSaleINVPriceE35
    ) external onlyOwner {
        require(
            block.number < startBlock - (oneHourMatic * 4),
            "cannot change price 4 hours before start block"
        );
        require(
            _newPreCZDiamondSaleINVPriceE35 >= 2 * (10**33),
            "new myfriends price is to high!"
        );
        require(
            _newPreCZDiamondSaleINVPriceE35 <= 28 * (10**34),
            "new myfriends price is too low!"
        );

        require(
            _newPreDarksideSaleINVPriceE35 >= 2 * (10**34),
            "new darkside price is to high!"
        );
        require(
            _newPreDarksideSaleINVPriceE35 <= 23 * (10**35),
            "new darkside price is too low!"
        );

        preCZDiamondSaleINVPriceE35 = _newPreCZDiamondSaleINVPriceE35;
        preDarksideSaleINVPriceE35 = _newPreDarksideSaleINVPriceE35;

        preCZDiamondMaximumAvailable =
            (mfSwapPresaleSize * preCZDiamondSaleINVPriceE35) /
            1e35;
        preDarksideMaximumAvailable =
            (mfSwapPresaleSize * preDarksideSaleINVPriceE35) /
            1e35;

        preCZDiamondRemaining = preCZDiamondMaximumAvailable;
        preDarksideRemaining = preDarksideMaximumAvailable;

        emit SaleINVPricesE35Changed(
            preCZDiamondSaleINVPriceE35,
            preDarksideSaleINVPriceE35
        );
    }

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
