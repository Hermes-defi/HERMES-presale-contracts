// SPDX-License-Identifier: GPL-3.0
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./library/interfaces/IWETH.sol";

pragma solidity ^0.8.0;

// NFTChef is the keeper of Masterchefs NFTs.
//
//
// Have fun reading it. Hopefully it's bug-free. .
contract NFTChef is IERC721Receiver, Ownable {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // max NFTs a single user can stake in a pool. This is to ensure finite gas usage on emergencyWithdraw.
    uint256 public constant MAX_NFT_COUNT = 32;
    uint256 public constant MAX_MATIC_STAKING_FEE = 1e3 * (1e18);

    // Mapping of NFT contract address to which NFTs a user has staked.
    mapping(address => mapping(address => mapping(uint256 => bool)))
        public userStakedMap;
    // Mapping of NFT contract address to array of NFT IDs a user has staked.
    mapping(address => mapping(address => EnumerableSet.UintSet))
        private userNftIdsMapArray;
    // mapping of NFT contract address to maticFeeAmount
    mapping(address => uint256) public userNftMaticFeeMap;

    // MATIC Polygon (MATIC) address
    address public constant maticCurrencyAddress =
        0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address public immutable CZDiamondAddress;
    address public immutable darksideAddress;

    event AddSetPoolNFT(address indexed nftContractAddress, uint256 maticFee);
    event DepositNFT(
        address indexed user,
        address indexed nftContractAddress,
        uint256 nftId
    );
    event WithdrawNFT(
        address indexed user,
        address indexed nftContractAddress,
        uint256 nftId
    );
    event EmergencyWithdrawNFT(
        address indexed user,
        address indexed nftContractAddress,
        uint256 nftId
    );
    event EmergencyNFTWithdrawCompleted(
        address indexed user,
        address indexed nftContractAddress,
        uint256 amountOfNfts
    );

    constructor(address _CZDiamondAddress, address _darksideAddress) public {
        CZDiamondAddress = _CZDiamondAddress;
        darksideAddress = _darksideAddress;
    }

    // set NFTs matic deposit Fees.
    function setPoolMaticFee(address nftContractAddress, uint256 maticFee)
        external
        onlyOwner
    {
        IERC721(nftContractAddress).balanceOf(address(this));
        require(
            maticFee <= MAX_MATIC_STAKING_FEE,
            "maximum matic fee for nft staking is 1000 matic!"
        );
        userNftMaticFeeMap[nftContractAddress] = maticFee;

        emit AddSetPoolNFT(nftContractAddress, maticFee);
    }

    // Deposit NFTs to NFTChef for DARKSIDE allocation.
    function deposit(
        address nftContractAddress,
        address userAddress,
        uint256 nftId
    ) external payable onlyOwner {
        require(
            msg.value >= userNftMaticFeeMap[nftContractAddress],
            "not enough unwrapped matic provided!"
        );
        require(
            userNftIdsMapArray[nftContractAddress][userAddress].length() <
                MAX_NFT_COUNT,
            "you have aleady reached the maximum amount of NFTs you can stake in this pool"
        );
        IERC721(nftContractAddress).transferFrom(
            userAddress,
            address(this),
            nftId
        );

        userStakedMap[nftContractAddress][userAddress][nftId] = true;

        userNftIdsMapArray[nftContractAddress][userAddress].add(nftId);

        uint256 maticBalance = address(this).balance;
        // Wrapping native matic for wmatic.
        if (maticBalance > 0)
            IWETH(maticCurrencyAddress).deposit{value: maticBalance}();

        uint256 wmaticBalance = IERC20(maticCurrencyAddress).balanceOf(
            address(this)
        );
        uint256 darkSideFee = wmaticBalance / 4;

        if (darkSideFee > 0)
            IERC20(maticCurrencyAddress).safeTransferFrom(
                address(this),
                darksideAddress,
                darkSideFee
            );
        if (wmaticBalance - darkSideFee > 0)
            IERC20(maticCurrencyAddress).safeTransferFrom(
                address(this),
                CZDiamondAddress,
                wmaticBalance - darkSideFee
            );

        emit DepositNFT(userAddress, nftContractAddress, nftId);
    }

    // Withdraw NFTs from NFTChef.
    function withdraw(
        address nftContractAddress,
        address userAddress,
        uint256 nftId
    ) external onlyOwner {
        require(
            userStakedMap[nftContractAddress][userAddress][nftId],
            "nft not staked"
        );

        IERC721(nftContractAddress).transferFrom(
            address(this),
            userAddress,
            nftId
        );

        userStakedMap[nftContractAddress][userAddress][nftId] = false;

        userNftIdsMapArray[nftContractAddress][userAddress].remove(nftId);

        emit WithdrawNFT(userAddress, nftContractAddress, nftId);
    }

    // Withdraw all NFTs without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(address nftContractAddress, address userAddress)
        external
        onlyOwner
    {
        EnumerableSet.UintSet storage nftStakedCollection = userNftIdsMapArray[
            nftContractAddress
        ][userAddress];

        for (uint256 i = 0; i < nftStakedCollection.length(); i++) {
            uint256 nftId = nftStakedCollection.at(i);

            IERC721(nftContractAddress).transferFrom(
                address(this),
                userAddress,
                nftId
            );

            userStakedMap[nftContractAddress][userAddress][nftId] = false;

            emit EmergencyWithdrawNFT(userAddress, nftContractAddress, nftId);
        }

        emit EmergencyNFTWithdrawCompleted(
            userAddress,
            nftContractAddress,
            nftStakedCollection.length()
        );

        // empty user nft Ids array
        delete userNftIdsMapArray[nftContractAddress][userAddress];
    }

    function viewStakerUserNFTs(address nftContractAddress, address userAddress)
        public
        view
        returns (uint256[] memory)
    {
        EnumerableSet.UintSet storage nftStakedCollection = userNftIdsMapArray[
            nftContractAddress
        ][userAddress];

        uint256[] memory nftStakedArray = new uint256[](
            nftStakedCollection.length()
        );

        for (uint256 i = 0; i < nftStakedCollection.length(); i++)
            nftStakedArray[i] = nftStakedCollection.at(i);

        return nftStakedArray;
    }

    // To receive MATIC from depositers when depositing NFTs
    receive() external payable {}
}
