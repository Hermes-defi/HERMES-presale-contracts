
// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// File: @openzeppelin/contracts/security/ReentrancyGuard.sol


// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: contracts/PreHermes.sol



pragma solidity ^0.8.0;




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
    event WhitelistAccount(address account, uint256 amount);

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
        if (_accounts.length > 0) {
            _whiteListAccounts(_accounts, _amounts);
        }
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
        emit WhitelistAccount(_account, _allowance);
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
