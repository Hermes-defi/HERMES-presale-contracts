
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

// File: PreHermes_flat_flat.sol






pragma solidity ^0.8.0;

interface IL3PltsSwapBank{
    function endBlock() external returns(uint);
    function preHermesRemaining() external returns(uint);
}

interface IL3PltsSwapGen{
    function endBlock() external returns(uint);
    function preHermesRemaining() external returns(uint);
}

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

    IL3PltsSwapBank public immutable l3PltsSwapBank;
    IL3PltsSwapGen public immutable l3PltsSwapGen;

    uint256 public startBlock;

    bool public hasRetrievedUnsoldPresale = false;

    event HermesSwap(address sender, uint256 amount);
    event RetrieveUnclaimedTokens(uint256 hermesAmount);
    event StartBlockChanged(uint256 newStartBlock);

    constructor(
        uint256 _startBlock,
        IL3PltsSwapBank _l3PltsSwapBank,
        IL3PltsSwapGen _l3PltsSwapGen,
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
