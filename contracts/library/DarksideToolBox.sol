// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

pragma solidity ^0.8.0;

contract DarksideToolBox {
    IUniswapV2Router02 public immutable darksideSwapRouter;

    uint256 public immutable startBlock;

    /**
     * @notice Constructs the DarksideToken contract.
     */
    constructor(uint256 _startBlock, IUniswapV2Router02 _darksideSwapRouter) {
        startBlock = _startBlock;
        darksideSwapRouter = _darksideSwapRouter;
    }

    function convertToTargetValueFromPair(
        IUniswapV2Pair pair,
        uint256 sourceTokenAmount,
        address targetAddress
    ) public view returns (uint256) {
        require(
            pair.token0() == targetAddress || pair.token1() == targetAddress,
            "one of the pairs must be the targetAddress"
        );
        if (sourceTokenAmount == 0) return 0;

        (uint256 res0, uint256 res1, ) = pair.getReserves();
        if (res0 == 0 || res1 == 0) return 0;

        if (pair.token0() == targetAddress)
            return (res0 * sourceTokenAmount) / res1;
        else return (res1 * sourceTokenAmount) / res0;
    }

    function getTokenUSDCValue(
        uint256 tokenBalance,
        address token,
        uint256 tokenType,
        bool viaMaticUSDC,
        address usdcAddress
    ) external view returns (uint256) {
        require(
            tokenType == 0 || tokenType == 1,
            "invalid token type provided"
        );
        if (token == address(usdcAddress)) return tokenBalance;

        // lp type
        if (tokenType == 1) {
            IUniswapV2Pair lpToken = IUniswapV2Pair(token);
            if (lpToken.totalSupply() == 0) return 0;
            // If lp contains usdc, we can take a short-cut
            if (lpToken.token0() == address(usdcAddress)) {
                return
                    (IERC20(lpToken.token0()).balanceOf(address(lpToken)) *
                        tokenBalance *
                        2) / lpToken.totalSupply();
            } else if (lpToken.token1() == address(usdcAddress)) {
                return
                    (IERC20(lpToken.token1()).balanceOf(address(lpToken)) *
                        tokenBalance *
                        2) / lpToken.totalSupply();
            }
        }

        // Only used for lp type tokens.
        address lpTokenAddress = token;
        // If token0 or token1 is matic, use that, else use token0.
        if (tokenType == 1) {
            token = IUniswapV2Pair(token).token0() == darksideSwapRouter.WETH()
                ? darksideSwapRouter.WETH()
                : (
                    IUniswapV2Pair(token).token1() == darksideSwapRouter.WETH()
                        ? darksideSwapRouter.WETH()
                        : IUniswapV2Pair(token).token0()
                );
        }

        // if it is an LP token we work with all of the reserve in the LP address to scale down later.
        uint256 tokenAmount = (tokenType == 1)
            ? IERC20(token).balanceOf(lpTokenAddress)
            : tokenBalance;

        uint256 usdcEquivalentAmount = 0;

        if (viaMaticUSDC) {
            uint256 maticAmount = 0;

            if (token == darksideSwapRouter.WETH()) {
                maticAmount = tokenAmount;
            } else {
                // As we arent working with usdc at this point (early return), this is okay.
                IUniswapV2Pair maticPair = IUniswapV2Pair(
                    IUniswapV2Factory(darksideSwapRouter.factory()).getPair(
                        darksideSwapRouter.WETH(),
                        token
                    )
                );

                if (address(maticPair) == address(0)) return 0;

                maticAmount = convertToTargetValueFromPair(
                    maticPair,
                    tokenAmount,
                    darksideSwapRouter.WETH()
                );
            }

            // As we arent working with usdc at this point (early return), this is okay.
            IUniswapV2Pair usdcmaticPair = IUniswapV2Pair(
                IUniswapV2Factory(darksideSwapRouter.factory()).getPair(
                    darksideSwapRouter.WETH(),
                    address(usdcAddress)
                )
            );

            if (address(usdcmaticPair) == address(0)) return 0;

            usdcEquivalentAmount = convertToTargetValueFromPair(
                usdcmaticPair,
                maticAmount,
                usdcAddress
            );
        } else {
            // As we arent working with usdc at this point (early return), this is okay.
            IUniswapV2Pair usdcPair = IUniswapV2Pair(
                IUniswapV2Factory(darksideSwapRouter.factory()).getPair(
                    address(usdcAddress),
                    token
                )
            );

            if (address(usdcPair) == address(0)) return 0;

            usdcEquivalentAmount = convertToTargetValueFromPair(
                usdcPair,
                tokenAmount,
                usdcAddress
            );
        }

        // for the tokenType == 1 path usdcEquivalentAmount is the USDC value of all the tokens in the parent LP contract.

        if (tokenType == 1)
            return
                (usdcEquivalentAmount * tokenBalance * 2) /
                IUniswapV2Pair(lpTokenAddress).totalSupply();
        else return usdcEquivalentAmount;
    }

    function getNumberOfHalvingsSinceStart(
        uint256 CZDiamondReleaseHalfLife,
        uint256 _to
    ) public view returns (uint256) {
        if (_to <= startBlock) return 0;

        return (_to - startBlock) / CZDiamondReleaseHalfLife;
    }

    function getPreviousCZDiamondHalvingBlock(
        uint256 CZDiamondReleaseHalfLife,
        uint256 _block
    ) public view returns (uint256) {
        // won't revert from getCZDiamondRelease due to bounds check
        require(
            _block >= startBlock,
            "can't get previous CZDiamond halving before startBlock"
        );

        uint256 numberOfHalvings = getNumberOfHalvingsSinceStart(
            CZDiamondReleaseHalfLife,
            _block
        );
        return numberOfHalvings * CZDiamondReleaseHalfLife + startBlock;
    }

    function getNextCZDiamondHalvingBlock(
        uint256 CZDiamondReleaseHalfLife,
        uint256 _block
    ) public view returns (uint256) {
        // won't revert from getCZDiamondRelease due to bounds check
        require(
            _block >= startBlock,
            "can't get previous CZDiamond halving before startBlock"
        );

        uint256 numberOfHalvings = getNumberOfHalvingsSinceStart(
            CZDiamondReleaseHalfLife,
            _block
        );

        if ((_block - startBlock) % CZDiamondReleaseHalfLife == 0)
            return numberOfHalvings * CZDiamondReleaseHalfLife + startBlock;
        else
            return
                (numberOfHalvings + 1) * CZDiamondReleaseHalfLife + startBlock;
    }

    function getCZDiamondReleaseForBlockE24(
        uint256 initialCZDiamondReleaseRate,
        uint256 CZDiamondReleaseHalfLife,
        uint256 _block
    ) public view returns (uint256) {
        if (_block < startBlock) return 0;

        uint256 numberOfHalvings = getNumberOfHalvingsSinceStart(
            CZDiamondReleaseHalfLife,
            _block
        );
        return (initialCZDiamondReleaseRate * 1e24) / (2**numberOfHalvings);
    }

    // Return CZDIAMOND reward release over the given _from to _to block.
    function getCZDiamondRelease(
        uint256 initialCZDiamondReleaseRate,
        uint256 CZDiamondReleaseHalfLife,
        uint256 _from,
        uint256 _to
    ) external view returns (uint256) {
        if (_from < startBlock || _to <= _from) return 0;

        uint256 releaseDuration = _to - _from;

        uint256 startReleaseE24 = getCZDiamondReleaseForBlockE24(
            initialCZDiamondReleaseRate,
            CZDiamondReleaseHalfLife,
            _from
        );
        uint256 endReleaseE24 = getCZDiamondReleaseForBlockE24(
            initialCZDiamondReleaseRate,
            CZDiamondReleaseHalfLife,
            _to
        );

        // If we are all in the same era its a rectangle problem
        if (startReleaseE24 == endReleaseE24)
            return (endReleaseE24 * releaseDuration) / 1e24;

        // The idea here is that if we span multiple halving eras, we can use triangle geometry to take an average.
        uint256 startSkipBlock = getNextCZDiamondHalvingBlock(
            CZDiamondReleaseHalfLife,
            _from
        );
        uint256 endSkipBlock = getPreviousCZDiamondHalvingBlock(
            CZDiamondReleaseHalfLife,
            _to
        );

        // In this case we do span multiple eras (at least 1 complete half-life era)
        if (startSkipBlock != endSkipBlock) {
            uint256 numberOfCompleteHalfLifes = getNumberOfHalvingsSinceStart(
                CZDiamondReleaseHalfLife,
                endSkipBlock
            ) -
                getNumberOfHalvingsSinceStart(
                    CZDiamondReleaseHalfLife,
                    startSkipBlock
                );
            uint256 partialEndsRelease = startReleaseE24 *
                (startSkipBlock - _from) +
                (endReleaseE24 * (_to - endSkipBlock));
            uint256 wholeMiddleRelease = (endReleaseE24 *
                2 *
                CZDiamondReleaseHalfLife) *
                ((2**numberOfCompleteHalfLifes) - 1);
            return (partialEndsRelease + wholeMiddleRelease) / 1e24;
        }

        // In this case we just span across 2 adjacent eras
        return
            ((endReleaseE24 * releaseDuration) +
                (startReleaseE24 - endReleaseE24) *
                (startSkipBlock - _from)) / 1e24;
    }

    function getDarksideEmissionForBlock(
        uint256 _block,
        bool isIncreasingGradient,
        uint256 releaseGradient,
        uint256 gradientEndBlock,
        uint256 endEmission
    ) public pure returns (uint256) {
        if (_block >= gradientEndBlock) return endEmission;

        if (releaseGradient == 0) return endEmission;
        uint256 currentDarksideEmission = endEmission;
        uint256 deltaHeight = (releaseGradient * (gradientEndBlock - _block)) /
            1e24;

        if (isIncreasingGradient) {
            // if there is a logical error, we return 0
            if (endEmission >= deltaHeight)
                currentDarksideEmission = endEmission - deltaHeight;
            else currentDarksideEmission = 0;
        } else currentDarksideEmission = endEmission + deltaHeight;

        return currentDarksideEmission;
    }

    function calcEmissionGradient(
        uint256 _block,
        uint256 currentEmission,
        uint256 gradientEndBlock,
        uint256 endEmission
    ) external pure returns (uint256) {
        uint256 darksideReleaseGradient;

        // if the gradient is 0 we interpret that as an unchanging 0 gradient.
        if (currentEmission != endEmission && _block < gradientEndBlock) {
            bool isIncreasingGradient = endEmission > currentEmission;
            if (isIncreasingGradient)
                darksideReleaseGradient =
                    ((endEmission - currentEmission) * 1e24) /
                    (gradientEndBlock - _block);
            else
                darksideReleaseGradient =
                    ((currentEmission - endEmission) * 1e24) /
                    (gradientEndBlock - _block);
        } else darksideReleaseGradient = 0;

        return darksideReleaseGradient;
    }

    // Return if we are in the normal operation era, no promo
    function isFlatEmission(uint256 _gradientEndBlock, uint256 _blocknum)
        internal
        pure
        returns (bool)
    {
        return _blocknum >= _gradientEndBlock;
    }

    // Return DARKSIDE reward release over the given _from to _to block.
    function getDarksideRelease(
        bool isIncreasingGradient,
        uint256 releaseGradient,
        uint256 gradientEndBlock,
        uint256 endEmission,
        uint256 _from,
        uint256 _to
    ) external view returns (uint256) {
        if (_to <= _from || _to <= startBlock) return 0;
        uint256 clippedFrom = _from < startBlock ? startBlock : _from;
        uint256 totalWidth = _to - clippedFrom;

        if (
            releaseGradient == 0 ||
            isFlatEmission(gradientEndBlock, clippedFrom)
        ) return totalWidth * endEmission;

        if (!isFlatEmission(gradientEndBlock, _to)) {
            uint256 heightDelta = releaseGradient * totalWidth;

            uint256 baseEmission;
            if (isIncreasingGradient)
                baseEmission = getDarksideEmissionForBlock(
                    clippedFrom,
                    isIncreasingGradient,
                    releaseGradient,
                    gradientEndBlock,
                    endEmission
                );
            else
                baseEmission = getDarksideEmissionForBlock(
                    _to,
                    isIncreasingGradient,
                    releaseGradient,
                    gradientEndBlock,
                    endEmission
                );
            return
                totalWidth *
                baseEmission +
                (((totalWidth * heightDelta) / 2) / 1e24);
        }

        // Special case when we are transitioning between promo and normal era.
        if (
            !isFlatEmission(gradientEndBlock, clippedFrom) &&
            isFlatEmission(gradientEndBlock, _to)
        ) {
            uint256 blocksUntilGradientEnd = gradientEndBlock - clippedFrom;
            uint256 heightDelta = releaseGradient * blocksUntilGradientEnd;

            uint256 baseEmission;
            if (isIncreasingGradient)
                baseEmission = getDarksideEmissionForBlock(
                    _to,
                    isIncreasingGradient,
                    releaseGradient,
                    gradientEndBlock,
                    endEmission
                );
            else
                baseEmission = getDarksideEmissionForBlock(
                    clippedFrom,
                    isIncreasingGradient,
                    releaseGradient,
                    gradientEndBlock,
                    endEmission
                );

            return
                totalWidth *
                baseEmission -
                (((blocksUntilGradientEnd * heightDelta) / 2) / 1e24);
        }

        // huh?
        // shouldnt happen, but also don't want to assert false here either.
        return 0;
    }
}
