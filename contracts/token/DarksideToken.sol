// SPDX-License-Identifier: GPL-3.0


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "../library/AddLiquidityHelper.sol";
import "../library/DarksideToolBox.sol";

pragma solidity ^0.8.0;

// DarksideToken.
contract DarksideToken is ERC20("Darkcoin", "DARK") {
    using SafeERC20 for IERC20;

    // Transfer tax rate in basis points. (default 6.66%)
    uint16 public transferTaxRate = 666;
    // Extra transfer tax rate in basis points. (default 10.00%)
    uint16 public extraTransferTaxRate = 1000;
    // Burn rate % of transfer tax. (default 54.95% x 6.66% = 3.660336% of total amount).
    uint32 public constant burnRate = 549549549;
    // Max transfer tax rate: 20.00%.
    uint16 public constant MAXIMUM_TRANSFER_TAX_RATE = 2000;
    // Burn address
    address public constant BURN_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

    address public constant usdcCurrencyAddress =
        0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;

    uint256 public constant usdcSwapThreshold = 20 * (10**6);

    // Min amount to liquify. (default 40 DARKSIDEs)
    uint256 public constant minDarksideAmountToLiquify = 40 * (10**18);
    // Min amount to liquify. (default 100 MATIC)
    uint256 public constant minMaticAmountToLiquify = 100 * (10**18);

    IUniswapV2Router02 public darksideSwapRouter;
    // The trading pair
    address public darksideSwapPair;
    // In swap and liquify
    bool private _inSwapAndLiquify;

    AddLiquidityHelper public immutable addLiquidityHelper;
    DarksideToolBox public immutable darksideToolBox;

    address public immutable CZDiamond;

    bool public ownershipIsTransferred = false;

    mapping(address => bool) public excludeFromMap;
    mapping(address => bool) public excludeToMap;

    mapping(address => bool) public extraFromMap;
    mapping(address => bool) public extraToMap;

    event TransferFeeChanged(uint256 txnFee, uint256 extraTxnFee);
    event UpdateFeeMaps(
        address indexed _contract,
        bool fromExcluded,
        bool toExcluded,
        bool fromHasExtra,
        bool toHasExtra
    );
    event SetDarksideRouter(
        address darksideSwapRouter,
        address darksideSwapPair
    );
    event OperatorTransferred(
        address indexed previousOperator,
        address indexed newOperator
    );

    // The operator can only update the transfer tax rate
    address public operator;

    modifier onlyOperator() {
        require(operator == msg.sender, "!operator");
        _;
    }

    modifier lockTheSwap() {
        _inSwapAndLiquify = true;
        _;
        _inSwapAndLiquify = false;
    }

    modifier transferTaxFree() {
        uint16 _transferTaxRate = transferTaxRate;
        uint16 _extraTransferTaxRate = extraTransferTaxRate;
        transferTaxRate = 0;
        extraTransferTaxRate = 0;
        _;
        transferTaxRate = _transferTaxRate;
        extraTransferTaxRate = _extraTransferTaxRate;
    }

    /**
     * @notice Constructs the DarksideToken contract.
     */
    constructor(
        address _CZDiamond,
        AddLiquidityHelper _addLiquidityHelper,
        DarksideToolBox _darksideToolBox
    ) public {
        addLiquidityHelper = _addLiquidityHelper;
        darksideToolBox = _darksideToolBox;
        CZDiamond = _CZDiamond;
        operator = _msgSender();

        // pre-mint
        _mint(
            address(0x3a1D1114269d7a786C154FE5278bF5b1e3e20d31),
            uint256(325000 * (10**18))
        );
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        require(!ownershipIsTransferred, "!unset");
        super.transferOwnership(newOwner);
        ownershipIsTransferred = true;
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function burn(uint256 _amount) external onlyOwner {
        _burn(msg.sender, _amount);
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function mint(address _to, uint256 _amount) external onlyOwner {
        require(ownershipIsTransferred, "too early!");
        if (_amount > 0) _mint(_to, _amount);
    }

    /// @dev overrides transfer function to meet tokenomics of DARKSIDE
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        bool toFromAddLiquidityHelper = (sender ==
            address(addLiquidityHelper) ||
            recipient == address(addLiquidityHelper));
        // swap and liquify
        if (
            _inSwapAndLiquify == false &&
            address(darksideSwapRouter) != address(0) &&
            !toFromAddLiquidityHelper &&
            sender != darksideSwapPair &&
            sender != owner()
        ) {
            swapAndLiquify();
        }

        if (
            toFromAddLiquidityHelper ||
            recipient == BURN_ADDRESS ||
            (transferTaxRate == 0 && extraTransferTaxRate == 0) ||
            excludeFromMap[sender] ||
            excludeToMap[recipient]
        ) {
            super._transfer(sender, recipient, amount);
        } else {
            // default tax is 6.66% of every transfer, but extra 2% for dumping tax
            uint256 taxAmount = (amount *
                (transferTaxRate +
                    (
                        (extraFromMap[sender] || extraToMap[recipient])
                            ? extraTransferTaxRate
                            : 0
                    ))) / 10000;

            uint256 burnAmount = (taxAmount * burnRate) / 1000000000;
            uint256 liquidityAmount = taxAmount - burnAmount;

            // default 93.34% of transfer sent to recipient
            uint256 sendAmount = amount - taxAmount;

            assert(
                amount == sendAmount + taxAmount &&
                    taxAmount == burnAmount + liquidityAmount
            );

            super._transfer(sender, BURN_ADDRESS, burnAmount);
            super._transfer(sender, address(this), liquidityAmount);
            super._transfer(sender, recipient, sendAmount);
            amount = sendAmount;
        }
    }

    /// @dev Swap and liquify
    function swapAndLiquify() private lockTheSwap transferTaxFree {
        uint256 contractTokenBalance = ERC20(address(this)).balanceOf(
            address(this)
        );

        uint256 WETHbalance = IERC20(darksideSwapRouter.WETH()).balanceOf(
            address(this)
        );

        IWETH(darksideSwapRouter.WETH()).withdraw(WETHbalance);

        if (
            address(this).balance >= minMaticAmountToLiquify ||
            contractTokenBalance >= minDarksideAmountToLiquify
        ) {
            IERC20(address(this)).safeTransfer(
                address(addLiquidityHelper),
                IERC20(address(this)).balanceOf(address(this))
            );
            // send all tokens to add liquidity with, we are refunded any that aren't used.
            addLiquidityHelper.darksideETHLiquidityWithBuyBack{
                value: address(this).balance
            }(BURN_ADDRESS);
        }
    }

    /**
     * @dev unenchant the lp token into its original components.
     * Can only be called by the current operator.
     */
    function swapLpTokensForFee(address token, uint256 amount) internal {
        require(
            IERC20(token).approve(address(darksideSwapRouter), amount),
            "!approved"
        );

        IUniswapV2Pair lpToken = IUniswapV2Pair(token);

        uint256 token0BeforeLiquidation = IERC20(lpToken.token0()).balanceOf(
            address(this)
        );
        uint256 token1BeforeLiquidation = IERC20(lpToken.token1()).balanceOf(
            address(this)
        );

        // make the swap
        darksideSwapRouter.removeLiquidity(
            lpToken.token0(),
            lpToken.token1(),
            amount,
            0,
            0,
            address(this),
            block.timestamp
        );

        uint256 token0FromLiquidation = IERC20(lpToken.token0()).balanceOf(
            address(this)
        ) - token0BeforeLiquidation;
        uint256 token1FromLiquidation = IERC20(lpToken.token1()).balanceOf(
            address(this)
        ) - token1BeforeLiquidation;

        address tokenForCZDiamondUSDCReward = lpToken.token0();
        address tokenForDarksideAMMReward = lpToken.token1();

        // If we already have, usdc, save a swap.
        if (lpToken.token1() == usdcCurrencyAddress) {
            (tokenForDarksideAMMReward, tokenForCZDiamondUSDCReward) = (
                tokenForCZDiamondUSDCReward,
                tokenForDarksideAMMReward
            );
        } else if (lpToken.token0() == darksideSwapRouter.WETH()) {
            // if one is weth already use the other one for czdiamond and
            // the weth for darkside AMM to save a swap.

            (tokenForDarksideAMMReward, tokenForCZDiamondUSDCReward) = (
                tokenForCZDiamondUSDCReward,
                tokenForDarksideAMMReward
            );
        }

        bool czRewardIs0 = tokenForCZDiamondUSDCReward == lpToken.token0();

        // send czdiamond all of 1 half of the LP to be convereted to USDC later.
        IERC20(tokenForCZDiamondUSDCReward).safeTransfer(
            address(CZDiamond),
            czRewardIs0 ? token0FromLiquidation : token1FromLiquidation
        );

        // send czdiamond 50% share of the other 50% to give czdiamond 75% in total.
        IERC20(tokenForDarksideAMMReward).safeTransfer(
            address(CZDiamond),
            (czRewardIs0 ? token1FromLiquidation : token0FromLiquidation) / 2
        );

        swapDepositFeeForWmatic(tokenForDarksideAMMReward, 0);
    }

    /**
     * @dev sell all of a current type of token for weth, to be used in darkside liquidity later.
     * Can only be called by the current operator.
     */
    function swapDepositFeeForETH(address token, uint256 tokenType)
        external
        onlyOwner
    {
        uint256 usdcValue = darksideToolBox.getTokenUSDCValue(
            IERC20(token).balanceOf(address(this)),
            token,
            tokenType,
            false,
            usdcCurrencyAddress
        );

        // If darkside or weth already no need to do anything.
        if (token == address(this) || token == darksideSwapRouter.WETH())
            return;

        // only swap if a certain usdc value
        if (usdcValue < usdcSwapThreshold) return;

        swapDepositFeeForWmatic(token, tokenType);
    }

    function swapDepositFeeForWmatic(address token, uint256 tokenType)
        internal
    {
        address toToken = darksideSwapRouter.WETH();
        uint256 totalTokenBalance = IERC20(token).balanceOf(address(this));

        // can't trade to darkside inside of darkside anyway
        if (
            token == toToken ||
            totalTokenBalance == 0 ||
            toToken == address(this)
        ) return;

        if (tokenType == 1) {
            swapLpTokensForFee(token, totalTokenBalance);
            return;
        }

        require(
            IERC20(token).approve(
                address(darksideSwapRouter),
                totalTokenBalance
            ),
            "!approved"
        );

        // generate the darksideSwap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = toToken;

        try
            // make the swap
            darksideSwapRouter
                .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    totalTokenBalance,
                    0, // accept any amount of tokens
                    path,
                    address(this),
                    block.timestamp
                )
        {
            /* suceeded */
        } catch {
            /* failed, but we avoided reverting */
        }

        // Unfortunately can't swap directly to darkside inside of darkside (Uniswap INVALID_TO Assert, boo).
        // Also dont want to add an extra swap here.
        // Will leave as WETH and make the darkside Txn AMM utilise available WETH first.
    }

    // To receive ETH from darksideSwapRouter when swapping
    receive() external payable {}

    /**
     * @dev Update the transfer tax rate.
     * Can only be called by the current operator.
     */
    function updateTransferTaxRate(
        uint16 _transferTaxRate,
        uint16 _extraTransferTaxRate
    ) external onlyOperator {
        require(
            _transferTaxRate + _extraTransferTaxRate <=
                MAXIMUM_TRANSFER_TAX_RATE,
            "!valid"
        );
        transferTaxRate = _transferTaxRate;
        extraTransferTaxRate = _extraTransferTaxRate;

        emit TransferFeeChanged(transferTaxRate, extraTransferTaxRate);
    }

    /**
     * @dev Update the excludeFromMap
     * Can only be called by the current operator.
     */
    function updateFeeMaps(
        address _contract,
        bool fromExcluded,
        bool toExcluded,
        bool fromHasExtra,
        bool toHasExtra
    ) external onlyOperator {
        excludeFromMap[_contract] = fromExcluded;
        excludeToMap[_contract] = toExcluded;
        extraFromMap[_contract] = fromHasExtra;
        extraToMap[_contract] = toHasExtra;

        emit UpdateFeeMaps(
            _contract,
            fromExcluded,
            toExcluded,
            fromHasExtra,
            toHasExtra
        );
    }

    /**
     * @dev Update the swap router.
     * Can only be called by the current operator.
     */
    function updateDarksideSwapRouter(address _router) external onlyOperator {
        require(_router != address(0), "!!0");
        require(address(darksideSwapRouter) == address(0), "!unset");

        darksideSwapRouter = IUniswapV2Router02(_router);
        darksideSwapPair = IUniswapV2Factory(darksideSwapRouter.factory())
            .getPair(address(this), darksideSwapRouter.WETH());

        require(address(darksideSwapPair) != address(0), "!matic pair");

        emit SetDarksideRouter(address(darksideSwapRouter), darksideSwapPair);
    }

    /**
     * @dev Transfers operator of the contract to a new account (`newOperator`).
     * Can only be called by the current operator.
     */
    function transferOperator(address newOperator) external onlyOperator {
        require(newOperator != address(0), "!!0");

        emit OperatorTransferred(operator, newOperator);

        operator = newOperator;
    }
}
