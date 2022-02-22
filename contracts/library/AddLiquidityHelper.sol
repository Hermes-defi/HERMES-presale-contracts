// SPDX-License-Identifier: GPL-3.0
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

pragma solidity ^0.8.0;

// AddLiquidityHelper, allows anyone to add or remove Darkside liquidity tax free
// Also allows the Darkside Token to do buy backs tax free via an external contract.
contract AddLiquidityHelper is ReentrancyGuard, Ownable {
    using SafeERC20 for ERC20;

    address public darksideAddress;

    IUniswapV2Router02 public immutable darksideSwapRouter;
    // The trading pair
    address public darksideSwapPair;

    // To receive ETH when swapping
    receive() external payable {}

    event SetDarksideAddresses(
        address darksideAddress,
        address darksideSwapPair
    );

    /**
     * @notice Constructs the AddLiquidityHelper contract.
     */
    constructor(address _router) public {
        require(_router != address(0), "_router is the zero address");
        darksideSwapRouter = IUniswapV2Router02(_router);
    }

    function darksideETHLiquidityWithBuyBack(address lpHolder)
        external
        payable
        nonReentrant
    {
        require(
            msg.sender == darksideAddress,
            "can only be used by the darkside token!"
        );

        (uint256 res0, uint256 res1, ) = IUniswapV2Pair(darksideSwapPair)
            .getReserves();

        if (res0 != 0 && res1 != 0) {
            // making weth res0
            if (IUniswapV2Pair(darksideSwapPair).token0() == darksideAddress)
                (res1, res0) = (res0, res1);

            uint256 contractTokenBalance = ERC20(darksideAddress).balanceOf(
                address(this)
            );

            // calculate how much eth is needed to use all of contractTokenBalance
            // also boost precision a tad.
            uint256 totalETHNeeded = (res0 * contractTokenBalance) / res1;

            uint256 existingETH = address(this).balance;

            uint256 unmatchedDarkside = 0;

            if (existingETH < totalETHNeeded) {
                // calculate how much darkside will match up with our existing eth.
                uint256 matchedDarkside = (res1 * existingETH) / res0;
                if (contractTokenBalance >= matchedDarkside)
                    unmatchedDarkside = contractTokenBalance - matchedDarkside;
            } else if (existingETH > totalETHNeeded) {
                // use excess eth for darkside buy back
                uint256 excessETH = existingETH - totalETHNeeded;

                if (excessETH / 2 > 0) {
                    // swap half of the excess eth for lp to be balanced
                    swapETHForTokens(excessETH / 2, darksideAddress);
                }
            }

            uint256 unmatchedDarksideToSwap = unmatchedDarkside / 2;

            // swap tokens for ETH
            if (unmatchedDarksideToSwap > 0)
                swapTokensForEth(darksideAddress, unmatchedDarksideToSwap);

            uint256 darksideBalance = ERC20(darksideAddress).balanceOf(
                address(this)
            );

            // approve token transfer to cover all possible scenarios
            ERC20(darksideAddress).approve(
                address(darksideSwapRouter),
                darksideBalance
            );

            // add the liquidity
            darksideSwapRouter.addLiquidityETH{value: address(this).balance}(
                darksideAddress,
                darksideBalance,
                0, // slippage is unavoidable
                0, // slippage is unavoidable
                lpHolder,
                block.timestamp
            );
        }

        if (address(this).balance > 0) {
            // not going to require/check return value of this transfer as reverting behaviour is undesirable.
            payable(address(msg.sender)).call{value: address(this).balance}("");
        }

        if (ERC20(darksideAddress).balanceOf(address(this)) > 0)
            ERC20(darksideAddress).transfer(
                msg.sender,
                ERC20(darksideAddress).balanceOf(address(this))
            );
    }

    function addDarksideETHLiquidity(uint256 nativeAmount)
        external
        payable
        nonReentrant
    {
        require(msg.value > 0, "!sufficient funds");

        ERC20(darksideAddress).safeTransferFrom(
            msg.sender,
            address(this),
            nativeAmount
        );

        // approve token transfer to cover all possible scenarios
        ERC20(darksideAddress).approve(
            address(darksideSwapRouter),
            nativeAmount
        );

        // add the liquidity
        darksideSwapRouter.addLiquidityETH{value: msg.value}(
            darksideAddress,
            nativeAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            msg.sender,
            block.timestamp
        );

        if (address(this).balance > 0) {
            // not going to require/check return value of this transfer as reverting behaviour is undesirable.
            payable(address(msg.sender)).call{value: address(this).balance}("");
        }

        uint256 darksideBalance = ERC20(darksideAddress).balanceOf(
            address(this)
        );

        if (darksideBalance > 0)
            ERC20(darksideAddress).transfer(msg.sender, darksideBalance);
    }

    function addDarksideLiquidity(
        address baseTokenAddress,
        uint256 baseAmount,
        uint256 nativeAmount
    ) external nonReentrant {
        ERC20(baseTokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            baseAmount
        );
        ERC20(darksideAddress).safeTransferFrom(
            msg.sender,
            address(this),
            nativeAmount
        );

        // approve token transfer to cover all possible scenarios
        ERC20(baseTokenAddress).approve(
            address(darksideSwapRouter),
            baseAmount
        );
        ERC20(darksideAddress).approve(
            address(darksideSwapRouter),
            nativeAmount
        );

        // add the liquidity
        darksideSwapRouter.addLiquidity(
            baseTokenAddress,
            darksideAddress,
            baseAmount,
            nativeAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            msg.sender,
            block.timestamp
        );

        if (ERC20(baseTokenAddress).balanceOf(address(this)) > 0)
            ERC20(baseTokenAddress).safeTransfer(
                msg.sender,
                ERC20(baseTokenAddress).balanceOf(address(this))
            );

        if (ERC20(darksideAddress).balanceOf(address(this)) > 0)
            ERC20(darksideAddress).transfer(
                msg.sender,
                ERC20(darksideAddress).balanceOf(address(this))
            );
    }

    function removeDarksideLiquidity(
        address baseTokenAddress,
        uint256 liquidity
    ) external nonReentrant {
        address lpTokenAddress = IUniswapV2Factory(darksideSwapRouter.factory())
            .getPair(baseTokenAddress, darksideAddress);
        require(
            lpTokenAddress != address(0),
            "pair hasn't been created yet, so can't remove liquidity!"
        );

        ERC20(lpTokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            liquidity
        );
        // approve token transfer to cover all possible scenarios
        ERC20(lpTokenAddress).approve(address(darksideSwapRouter), liquidity);

        // add the liquidity
        darksideSwapRouter.removeLiquidity(
            baseTokenAddress,
            darksideAddress,
            liquidity,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            msg.sender,
            block.timestamp
        );
    }

    /// @dev Swap tokens for eth
    function swapTokensForEth(address saleTokenAddress, uint256 tokenAmount)
        internal
    {
        // generate the darksideSwap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = saleTokenAddress;
        path[1] = darksideSwapRouter.WETH();

        ERC20(saleTokenAddress).approve(
            address(darksideSwapRouter),
            tokenAmount
        );

        // make the swap
        darksideSwapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function swapETHForTokens(uint256 ethAmount, address wantedTokenAddress)
        internal
    {
        require(
            address(this).balance >= ethAmount,
            "insufficient matic provided!"
        );
        require(
            wantedTokenAddress != address(0),
            "wanted token address can't be the zero address!"
        );

        // generate the darksideSwap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = darksideSwapRouter.WETH();
        path[1] = wantedTokenAddress;

        // make the swap
        darksideSwapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: ethAmount
        }(
            0,
            path,
            // cannot send tokens to the token contract of the same type as the output token
            address(this),
            block.timestamp
        );
    }

    /**
     * @dev set the darkside address.
     * Can only be called by the current owner.
     */
    function setDarksideAddress(address _darksideAddress) external onlyOwner {
        require(
            _darksideAddress != address(0),
            "_darksideAddress is the zero address"
        );
        require(darksideAddress == address(0), "darksideAddress already set!");

        darksideAddress = _darksideAddress;

        darksideSwapPair = IUniswapV2Factory(darksideSwapRouter.factory())
            .getPair(darksideAddress, darksideSwapRouter.WETH());

        require(address(darksideSwapPair) != address(0), "matic pair !exist");

        emit SetDarksideAddresses(darksideAddress, darksideSwapPair);
    }
}
