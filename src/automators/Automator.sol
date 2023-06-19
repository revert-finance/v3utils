// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "v3-core/interfaces/IUniswapV3Factory.sol";
import "v3-core/interfaces/IUniswapV3Pool.sol";
import "v3-core/libraries/TickMath.sol";
import "v3-core/libraries/FullMath.sol";

import "v3-periphery/interfaces/INonfungiblePositionManager.sol";
import "v3-periphery/interfaces/external/IWETH9.sol";

abstract contract Automator is Ownable {

    uint256 internal constant Q64 = 2 ** 64;
    uint256 internal constant Q96 = 2 ** 96;

    error Unauthorized();
    error InvalidConfig();
    error TWAPCheckFailed();
    error EtherSendFailed();
    error NotWETH();
    error SwapFailed();
    error SlippageError();

    INonfungiblePositionManager public immutable nonfungiblePositionManager;
    IUniswapV3Factory public immutable factory;
    IWETH9 immutable public weth;

    uint64 immutable public protocolRewardX64 = uint64(Q64 / 400); // 0.25%

    // admin events
    event OperatorChanged(address newOperator);
    event TWAPConfigChanged(uint32 TWAPSeconds, uint16 maxTWAPTickDifference);
    event SwapRouterChanged(address newSwapRouter);

    // configurable by owner
    address public operator;
    uint32 public TWAPSeconds;
    uint16 public maxTWAPTickDifference;
    address public swapRouter;

    constructor(INonfungiblePositionManager npm, address _swapRouter, address _operator, uint32 _TWAPSeconds, uint16 _maxTWAPTickDifference) {

        nonfungiblePositionManager = npm;
        weth = IWETH9(npm.WETH9());
        factory = IUniswapV3Factory(npm.factory());

        swapRouter = _swapRouter;
        emit SwapRouterChanged(_swapRouter);

        operator = _operator;
        emit OperatorChanged(_operator);

        if (_maxTWAPTickDifference > uint16(type(int16).max) || _TWAPSeconds == 0) {
            revert InvalidConfig();
        }
        TWAPSeconds = _TWAPSeconds;
        maxTWAPTickDifference = _maxTWAPTickDifference;
        emit TWAPConfigChanged(_TWAPSeconds, _maxTWAPTickDifference);
    }

     /**
     * @notice Owner controlled function to change swap router (onlyOwner)
     * @param _swapRouter new swap router
     */
    function setSwapRouter(address _swapRouter) external onlyOwner {

        // don't let this ever be possible - it would enable owner to steal all approved NFTs
        if (swapRouter == address(nonfungiblePositionManager)) {
            revert InvalidConfig();
        }

        emit SwapRouterChanged(_swapRouter);
        swapRouter = _swapRouter;
    }

    /**
     * @notice Owner controlled function to change operator address
     * @param _operator new operator
     */
    function setOperator(address _operator) external onlyOwner {
        emit OperatorChanged(_operator);
        operator = _operator;
    }

    /**
     * @notice Owner controlled function to increase TWAPSeconds / decrease maxTWAPTickDifference
     */
    function setTWAPConfig(uint16 _maxTWAPTickDifference, uint32 _TWAPSeconds) external onlyOwner {
        if (_TWAPSeconds < TWAPSeconds) {
            revert InvalidConfig();
        }
        if (_maxTWAPTickDifference > maxTWAPTickDifference) {
            revert InvalidConfig();
        }
        emit TWAPConfigChanged(_TWAPSeconds, _maxTWAPTickDifference);
        TWAPSeconds = _TWAPSeconds;
        maxTWAPTickDifference = _maxTWAPTickDifference;
    }
    

    /**
     * @notice Withdraws token balance for a address and token
     * @param token Address of token to withdraw
     * @param to Address to send t
     */
    function withdrawBalance(address token, address to) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            _transferToken(to, IERC20(token), balance, true);
        }
    }

    // validate if swap can be done with specified oracle parameters - if not possible reverts
    // if possible returns minAmountOut
    function _validateSwap(bool swap0For1, uint256 amountIn, IUniswapV3Pool pool, uint32 twapPeriod, uint16 maxTickDifference, uint64 maxPriceDifferenceX64) internal view returns (uint256 amountOutMin, int24 currentTick, uint160 sqrtPriceX96, uint256 priceX96) {
        
        // get current price and tick
        (sqrtPriceX96,currentTick,,,,,) = pool.slot0();

        // check if current tick not too far from TWAP
        if (!_hasMaxTWAPTickDifference(pool, twapPeriod, currentTick, maxTickDifference)) {
            revert TWAPCheckFailed();
        }

        // calculate min output price price and percentage
        priceX96 = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, Q96);
        if (swap0For1) {
            amountOutMin = FullMath.mulDiv(amountIn * (Q64 - maxPriceDifferenceX64), priceX96, Q96 * Q64);
        } else {
            amountOutMin = FullMath.mulDiv(amountIn * (Q64 - maxPriceDifferenceX64), Q96, priceX96 * Q64);
        }
    }

    // general swap function which uses external router with off-chain calculated swap instructions
    // does price difference check with amountOutMin param (calculated based on oracle verified price)
    // NOTE: can be only called from (partially) trusted context (nft owner / contract owner / operator) because otherwise swapData can be manipulated to return always amountOutMin
    // returns new token amounts after swap
    function _swap(IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn, uint256 amountOutMin, bytes memory swapData) internal returns (uint256 amountInDelta, uint256 amountOutDelta) {
        if (amountIn > 0 && swapData.length > 0) {
            uint256 balanceInBefore = tokenIn.balanceOf(address(this));
            uint256 balanceOutBefore = tokenOut.balanceOf(address(this));

            // get router specific swap data
            (address allowanceTarget, bytes memory data) = abi.decode(swapData, (address, bytes));

            // approve needed amount
            SafeERC20.safeApprove(tokenIn, allowanceTarget, amountIn);

            // execute swap
            (bool success,) = swapRouter.call(data);
            if (!success) {
                revert SwapFailed();
            }

            // remove any remaining allowance
            SafeERC20.safeApprove(tokenIn, allowanceTarget, 0);

            uint256 balanceInAfter = tokenIn.balanceOf(address(this));
            uint256 balanceOutAfter = tokenOut.balanceOf(address(this));

            amountInDelta = balanceInBefore - balanceInAfter;
            amountOutDelta = balanceOutAfter - balanceOutBefore;

            // amountMin slippage check
            if (amountOutDelta < amountOutMin) {
                revert SlippageError();
            }
        }
    }

    // Checks if there was not more tick difference
    // returns false if not enough data available or tick difference >= maxDifference
    function _hasMaxTWAPTickDifference(IUniswapV3Pool pool, uint32 twapPeriod, int24 currentTick, uint16 maxDifference) internal view returns (bool) {
        (int24 twapTick, bool twapOk) = _getTWAPTick(pool, twapPeriod);
        if (twapOk) {
            return twapTick - currentTick >= -int16(maxDifference) && twapTick - currentTick <= int16(maxDifference);
        } else {
            return false;
        }
    }

    // gets twap tick from pool history if enough history available
    function _getTWAPTick(IUniswapV3Pool pool, uint32 twapPeriod) internal view returns (int24, bool) {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = 0; // from (before)
        secondsAgos[1] = twapPeriod; // from (before)

        // pool observe may fail when there is not enough history available
        try pool.observe(secondsAgos) returns (int56[] memory tickCumulatives, uint160[] memory) {
            return (int24((tickCumulatives[0] - tickCumulatives[1]) / int56(uint56(twapPeriod))), true);
        } catch {
            return (0, false);
        }
    }

    // get pool for token
    function _getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal view returns (IUniswapV3Pool) {
        return
            IUniswapV3Pool(
                PoolAddress.computeAddress(
                    address(factory),
                    PoolAddress.getPoolKey(tokenA, tokenB, fee)
                )
            );
    }

    function _decreaseFullLiquidityAndCollect(uint256 tokenId, uint128 liquidity, uint256 deadline) internal returns (uint256 amount0, uint256 amount1) {
       if (liquidity > 0) {
            (amount0, amount1) = nonfungiblePositionManager.decreaseLiquidity(
                    INonfungiblePositionManager.DecreaseLiquidityParams(
                        tokenId,
                        liquidity,
                        0,
                        0,
                        deadline
                    )
                );
        }
        (amount0, amount1) = nonfungiblePositionManager.collect(
            INonfungiblePositionManager.CollectParams(
                tokenId,
                address(this),
                type(uint128).max,
                type(uint128).max
            )
        );
    }

    // transfers token (or unwraps WETH and sends ETH)
    function _transferToken(address to, IERC20 token, uint256 amount, bool unwrap) internal {
        if (address(weth) == address(token) && unwrap) {
            weth.withdraw(amount);
            (bool sent, ) = to.call{value: amount}("");
            if (!sent) {
                revert EtherSendFailed();
            }
        } else {
            SafeERC20.safeTransfer(token, to, amount);
        }
    }

    // needed for WETH unwrapping
    receive() external payable {
        if (msg.sender != address(weth)) {
            revert NotWETH();
        }
    }
}