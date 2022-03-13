// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Contract that swaps plutus token for PreHermes tokens.
/// @dev This contract should have l3 presale balance to work properly.
/// PreHermes balance should at least be equal [preHermesMaximumAvailable].
/// Any remaining presale tokens stays in this contract after pre-sale ends.
contract L3PltsSwapBank is Ownable, ReentrancyGuard {
    address public constant FEE_ADDRESS =
        0x7cef2432A2690168Fb8eb7118A74d5f8EfF9Ef55;

    address public immutable plutusAddress;

    address public immutable preHermesAddress;

    uint256 public constant PLTS_SWAP_PRESALE_SIZE =
        14627908917828694 * (10**8); // 1,462,790.8917828694 amount of PLTS expected to be swapped?

    uint256 public preHermesSaleINVPriceE35 = 6610169492 * (10**25); // this price (pHRMS/PLTS) stays fixed during the sale.
    uint256 public preHermesMaximumAvailable =
        (PLTS_SWAP_PRESALE_SIZE * preHermesSaleINVPriceE35) / 1e35; // max amount of presale hermes tokens available to swap

    // We use a counter to defend against people sending pre{Hermes} back
    uint256 public preHermesRemaining = preHermesMaximumAvailable;

    uint256 public constant ONE_HOUR_HARMONY = 1630; // blocks per hour
    uint256 public constant PRESALE_DURATION = 117360; // blocks

    uint256 public startBlock;
    uint256 public endBlock = startBlock + PRESALE_DURATION;

    struct WhitelistedUserInfo {
        bool whiteListed;
        uint256 allowance;
    }

    mapping(address => WhitelistedUserInfo) public whitelisted;

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
        address _plutusAddress,
        address _preHermesAddress,
        address[] memory _accounts,
        uint256[] memory _amounts
    ) {
        require(
            block.number < _startBlock,
            "cannot set start block in the past!"
        );
        require(
            _plutusAddress != _preHermesAddress,
            "plutusAddress cannot be equal to preHermes"
        );

        require(
            _preHermesAddress != address(0),
            "_preHermesAddress cannot be the zero address"
        );
        require(
            _plutusAddress != address(0),
            "_plutusAddress cannot be the zero address"
        );

        startBlock = _startBlock;
        endBlock = _startBlock + PRESALE_DURATION;

        preHermesAddress = _preHermesAddress;
        plutusAddress = _plutusAddress;

        _whiteListAccounts(_accounts, _amounts);
    }

    /// @dev requires that users be whiteListed to execute functions
    modifier isWhitelisted(address _account) {
        require(whitelisted[_account].whiteListed, "User is not Allowed.");
        _;
    }

    /// @notice swap l2 token for l3 presale token.
    /// @dev Allows minimum of 1e6 token to be swapped.
    /// Requires l2 token approval.
    /// @param plutusToSwap Amount of PLTS token to swap.
    function swapPltsForPresaleTokensL3(uint256 plutusToSwap)
        external
        nonReentrant
        isWhitelisted(msg.sender)
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
        ); // checks if contract has presale tokens to give
        require(plutusToSwap > 1e6, "not enough plutus provided"); // requires a minimum plts token to swap

        require(
            whitelisted[msg.sender].allowance >= plutusToSwap,
            "Not allowed to swap this much PLTS"
        );

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

        preHermesRemaining = preHermesRemaining - preHermesPurchaseAmount;

        // update whitelisted user info.
        whitelisted[msg.sender].allowance -= plutusToSwap;

        require(
            IERC20(preHermesAddress).transfer(
                msg.sender,
                preHermesPurchaseAmount
            ),
            "failed sending preHermes"
        );

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
            block.number < startBlock - (ONE_HOUR_HARMONY * 4),
            "cannot change price 4 hours before start block"
        );

        require(
            _newPreHermesSaleINVPriceE35 >= 66 * (10**33),
            "new Hermes price is to high!"
        );
        require(
            _newPreHermesSaleINVPriceE35 <= 80 * (10**33),
            "new Hermes price is too low!"
        );

        preHermesSaleINVPriceE35 = _newPreHermesSaleINVPriceE35;

        preHermesMaximumAvailable =
            (PLTS_SWAP_PRESALE_SIZE * preHermesSaleINVPriceE35) /
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
        endBlock = _newStartBlock + PRESALE_DURATION;

        emit StartBlockChanged(_newStartBlock, endBlock);
    }

    /// @dev whitelist users that are allowed to swap using this contract.
    function whitelistUser(address _account, uint256 _allowance)
        public
        onlyOwner
    {
        require(_account != address(0), "Invalid address.");
        require(_allowance > 0, "Insufficient PLTS balance in Bank.");
        whitelisted[_account].whiteListed = true;
        whitelisted[_account].allowance += _allowance;
    }

    /// @notice check the max plts allowed to swap.
    function swapAllowance(address _account) public view returns (uint256) {
        return whitelisted[_account].allowance;
    }

    /// @dev whitelist users on contract creation
    /// @param _accounts list of user accounts
    /// @param _amounts list of user amounts
    function _whiteListAccounts(
        address[] memory _accounts,
        uint256[] memory _amounts
    ) private {
        require(_accounts.length == _amounts.length, "length mismatch");
        for (uint256 i = 0; i < _accounts.length; i++) {
            whitelistUser(_accounts[i], _amounts[i]);
        }
    }
}
