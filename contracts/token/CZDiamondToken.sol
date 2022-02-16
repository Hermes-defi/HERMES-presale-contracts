// SPDX-Licence-Identifier: MIT


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../library/DarksideToolBox.sol";


pragma solidity ^0.8.0;

// CZDiamondToken
contract CZDiamondToken is ERC20("CZDiamond", "CZDIAMOND") {
    // Burn address
    address public constant BURN_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

    uint256 public constant usdcSwapThreshold = 20 * (10**6);

    uint256 public pendingUSDC = 0;

    IERC20 public immutable usdcRewardCurrency;

    DarksideToolBox public immutable darksideToolBox;

    IUniswapV2Router02 public darksideSwapRouter;

    uint256 public lastUSDCDistroBlock = type(uint256).max;

    // default to two weeks @ 1600 blocks per hour
    uint256 public distributionTimeFrameBlocks = 1600 * 24 * 14;

    bool public ownershipIsTransferred = false;

    // Events
    event DistributeCZDiamond(address recipient, uint256 CZDiamondAmount);
    event DepositFeeConvertedToUSDC(
        address indexed inputToken,
        uint256 inputAmount,
        uint256 usdcOutput
    );
    event USDCTransferredToUser(address recipient, uint256 usdcAmount);
    event OperatorTransferred(
        address indexed previousOperator,
        address indexed newOperator
    );
    event DarksideSwapRouterUpdated(
        address indexed operator,
        address indexed router
    );
    event SetUSDCDistributionTimeFrame(uint256 distributionTimeFrameBlocks);

    // The operator can only update the transfer tax rate
    address public operator;

    modifier onlyOperator() {
        require(operator == msg.sender, "operator: caller is not the operator");
        _;
    }

    /**
     * @notice Constructs the DarksideToken contract.
     */
    constructor(address _usdcCurrency, DarksideToolBox _darksideToolBox) {
        operator = _msgSender();
        emit OperatorTransferred(address(0), operator);

        darksideToolBox = _darksideToolBox;
        usdcRewardCurrency = IERC20(_usdcCurrency);

        lastUSDCDistroBlock = _darksideToolBox.startBlock();

        // Divvy up CZDiamond supply.
        _mint(
            0x3a1D1114269d7a786C154FE5278bF5b1e3e20d31,
            60 * (10**3) * (10**18)
        );
        _mint(address(this), 40 * (10**3) * (10**18));
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        require(!ownershipIsTransferred, "!unset");
        super.transferOwnership(newOwner);
        ownershipIsTransferred = true;
    }

    /// @notice Sends `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function distribute(address _to, uint256 _amount)
        external
        onlyOwner
        returns (uint256)
    {
        require(ownershipIsTransferred, "too early!");
        uint256 sendAmount = _amount;
        if (balanceOf(address(this)) < _amount)
            sendAmount = balanceOf(address(this));

        if (sendAmount > 0) {
            IERC20(address(this)).transfer(_to, sendAmount);
            emit DistributeCZDiamond(_to, sendAmount);
        }

        return sendAmount;
    }

    // To receive MATIC from darksideSwapRouter when swapping
    receive() external payable {}

    /**
     * @dev sell all of a current type of token for usdc. and distribute on a drip.
     * Can only be called by the current owner.
     */
    function getUSDCDripRate() external view returns (uint256) {
        return
            usdcRewardCurrency.balanceOf(address(this)) /
            distributionTimeFrameBlocks;
    }

    /**
     * @dev sell all of a current type of token for usdc. and distribute on a drip.
     * Can only be called by the current owner.
     */
    function getUSDCDrip() external onlyOwner returns (uint256) {
        uint256 usdcBalance = usdcRewardCurrency.balanceOf(address(this));
        if (pendingUSDC > usdcBalance) return 0;

        uint256 usdcAvailable = usdcBalance - pendingUSDC;

        // only provide a drip if there has been some blocks passed since the last drip
        uint256 blockSinceLastDistro = block.number > lastUSDCDistroBlock
            ? block.number - lastUSDCDistroBlock
            : 0;

        // We distribute the usdc assuming the old usdc balance wanted to be distributed over distributionTimeFrameBlocks blocks.
        uint256 usdcRelease = (blockSinceLastDistro * usdcAvailable) /
            distributionTimeFrameBlocks;

        usdcRelease = usdcRelease > usdcAvailable ? usdcAvailable : usdcRelease;

        lastUSDCDistroBlock = block.number;
        pendingUSDC += usdcRelease;

        return usdcRelease;
    }

    /**
     * @dev sell all of a current type of token for usdc.
     */
    function convertDepositFeesToUSDC(address token, uint256 tokenType)
        public
        onlyOwner
    {
        // shouldn't be trying to sell CZDiamond
        if (token == address(this) || token == address(usdcRewardCurrency))
            return;

        // LP tokens aren't destroyed in CZDiamond, but this is so CZDiamond can process
        // already destroyed LP fees sent to it by the DarksideToken contract.
        if (tokenType == 1) {
            convertDepositFeesToUSDC(IUniswapV2Pair(token).token0(), 0);
            convertDepositFeesToUSDC(IUniswapV2Pair(token).token1(), 0);
            return;
        }

        uint256 totalTokenBalance = IERC20(token).balanceOf(address(this));

        uint256 usdcValue = darksideToolBox.getTokenUSDCValue(
            totalTokenBalance,
            token,
            tokenType,
            false,
            address(usdcRewardCurrency)
        );

        if (totalTokenBalance == 0) return;
        if (usdcValue < usdcSwapThreshold) return;

        // generate the darksideSwap pair path of token -> usdc.
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = address(usdcRewardCurrency);

        uint256 usdcPriorBalance = usdcRewardCurrency.balanceOf(address(this));

        require(
            IERC20(token).approve(
                address(darksideSwapRouter),
                totalTokenBalance
            ),
            "approval failed"
        );

        try
            // make the swap
            darksideSwapRouter
                .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    totalTokenBalance,
                    0, // accept any amount of USDC
                    path,
                    address(this),
                    block.timestamp
                )
        {
            /* suceeded */
        } catch {
            /* failed, but we avoided reverting */
        }

        uint256 usdcProfit = usdcRewardCurrency.balanceOf(address(this)) -
            usdcPriorBalance;

        emit DepositFeeConvertedToUSDC(token, totalTokenBalance, usdcProfit);
    }

    /**
     * @dev send usdc to a user
     * Can only be called by the current operator.
     */
    function transferUSDCToUser(address recipient, uint256 amount)
        external
        onlyOwner
    {
        uint256 usdcBalance = usdcRewardCurrency.balanceOf(address(this));
        if (usdcBalance < amount) amount = usdcBalance;

        require(
            usdcRewardCurrency.transfer(recipient, amount),
            "transfer failed!"
        );

        pendingUSDC -= amount;

        emit USDCTransferredToUser(recipient, amount);
    }

    /**
     * @dev set the number of blocks we should use to calculate the USDC drip rate.
     * Can only be called by the current operator.
     */
    function setUSDCDistributionTimeFrame(uint256 _usdcDistributionTimeFrame)
        external
        onlyOperator
    {
        require(
            _usdcDistributionTimeFrame > 1600 &&
                _usdcDistributionTimeFrame < 70080000, /* 5 years */
            "_usdcDistributionTimeFrame out of range!"
        );

        distributionTimeFrameBlocks = _usdcDistributionTimeFrame;

        emit SetUSDCDistributionTimeFrame(distributionTimeFrameBlocks);
    }

    /**
     * @dev Update the swap router.
     * Can only be called by the current operator.
     */
    function updateDarksideSwapRouter(address _router) external onlyOperator {
        require(
            _router != address(0),
            "updateDarksideSwapRouter: new _router is the zero address"
        );
        require(
            address(darksideSwapRouter) == address(0),
            "router already set!"
        );

        darksideSwapRouter = IUniswapV2Router02(_router);
        emit DarksideSwapRouterUpdated(msg.sender, address(darksideSwapRouter));
    }

    /**
     * @dev Transfers operator of the contract to a new account (`newOperator`).
     * Can only be called by the current operator.
     */
    function transferOperator(address newOperator) external onlyOperator {
        require(
            newOperator != address(0),
            "transferOperator: new operator is the zero address"
        );

        emit OperatorTransferred(operator, newOperator);

        operator = newOperator;
    }
}
