// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Common.sol";

contract V3Automation is Pausable, Common {

    error SameRange();
    error LiquidityChanged();

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    constructor(address _swapRouter, address admin, address withdrawer) Common(_swapRouter, admin, withdrawer) {
        _grantRole(OPERATOR_ROLE, admin);
    }

    enum Action {
        AUTO_ADJUST,
        AUTO_EXIT,
        AUTO_COMPOUND
    }

    struct ExecuteState {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;

        uint256 amount0;
        uint256 amount1;

        uint128 liquidity;
    }

    struct ExecuteParams {
        Action action;
        Protocol protocol;
        INonfungiblePositionManager nfpm;

        address userAddress;
        uint256 tokenId;
        uint128 liquidity; // liquidity the calculations are based on

        // target token for swaps (if this is address(0) no swaps are executed)
        address targetToken;
    
        uint256 amountIn0;
        // if token0 needs to be swapped to targetToken - set values
        uint256 amountOut0Min;
        bytes swapData0; // encoded data from 0x api call (address,bytes) - allowanceTarget,data

        // amountIn1 is used for swap and also as minAmount1 for decreased liquidity + collected fees
        uint256 amountIn1;
        // if token1 needs to be swapped to targetToken - set values
        uint256 amountOut1Min;
        bytes swapData1; // encoded data from 0x api call (address,bytes) - allowanceTarget,data

        uint256 amountRemoveMin0; // min amount to be removed from liquidity
        uint256 amountRemoveMin1; // min amount to be removed from liquidity
        uint256 deadline; // for uniswap operations - operator promises fair value
        uint64 gasFeeX64;  // amount of tokens to be used as gas fee
        uint64 protocolFeeX64;  // amount of tokens to be used as protocol fee

        // for mint new range
        int24 newTickLower;
        int24 newTickUpper;

        // compound fee to new position or not
        bool compoundFees;

        // min amount to be added after swap
        uint256 amountAddMin0;
        uint256 amountAddMin1;
    }

    function execute(ExecuteParams calldata params) public payable onlyRole(OPERATOR_ROLE) whenNotPaused() {
        _execute(params);
    }

    function executeWithPermit(ExecuteParams calldata params, uint8 v, bytes32 r, bytes32 s) public payable onlyRole(OPERATOR_ROLE) whenNotPaused() {
        params.nfpm.permit(address(this), params.tokenId, params.deadline, v, r, s);
        _execute(params);
    }

    function _execute(ExecuteParams calldata params) internal {
        params.nfpm.transferFrom(params.userAddress, address(this), params.tokenId);

        ExecuteState memory state;
        (state.token0, state.token1, state.liquidity, state.tickLower, state.tickUpper, state.fee) = _getPosition(params.nfpm, params.protocol, params.tokenId);

        if (state.liquidity != params.liquidity && params.liquidity != 0) {
            revert LiquidityChanged();
        }

        (state.amount0, state.amount1) = _decreaseLiquidityAndCollectFees(DecreaseAndCollectFeesParams(params.nfpm, IERC20(state.token0), IERC20(state.token1), params.tokenId, params.liquidity, params.deadline, params.amountRemoveMin0, params.amountRemoveMin1, params.compoundFees));

        // take fees
        {
            // take gas fees
            if (params.gasFeeX64 > 0) {
                if (params.gasFeeX64 > _maxFeeX64[FeeType.GAS_FEE]) {
                    revert TooMuchFee();
                }
                uint256 feeAmount0 = FullMath.mulDiv(state.amount0, params.gasFeeX64, Q64);
                uint256 feeAmount1 = FullMath.mulDiv(state.amount1, params.gasFeeX64, Q64);
                emit TakeFees(address(params.nfpm) ,params.tokenId, params.userAddress, state.token0, state.token1, state.amount0, state.amount1, feeAmount0, feeAmount1, params.gasFeeX64, FeeType.GAS_FEE);

                state.amount0 -= feeAmount0;
                state.amount1 -= feeAmount1;
            }

            // take protocol fees
            if (params.protocolFeeX64 > 0) {
                if (params.protocolFeeX64 > _maxFeeX64[FeeType.PROTOCOL_FEE]) {
                    revert TooMuchFee();
                }
                uint256 feeAmount0 = FullMath.mulDiv(state.amount0, params.protocolFeeX64, Q64);
                uint256 feeAmount1 = FullMath.mulDiv(state.amount1, params.protocolFeeX64, Q64);
                emit TakeFees(address(params.nfpm), params.tokenId, params.userAddress, state.token0, state.token1, state.amount0, state.amount1, feeAmount0, feeAmount1, params.protocolFeeX64, FeeType.PROTOCOL_FEE);

                state.amount0 -= feeAmount0;
                state.amount1 -= feeAmount1;
            }
        }

        if (params.action == Action.AUTO_ADJUST) {
            if (state.tickLower == params.newTickLower && state.tickUpper == params.newTickUpper) {
                revert SameRange();
            }
            uint256 newTokenId;
            uint256 newLiquidity;
            uint256 token0Added;
            uint256 token1Added;
            if (params.targetToken == state.token0) {
                (newTokenId, newLiquidity, token0Added, token1Added) = _swapAndMint(SwapAndMintParams(params.protocol, params.nfpm, IERC20(state.token0), IERC20(state.token1), state.fee, params.newTickLower, params.newTickUpper, state.amount0, state.amount1, params.userAddress, params.deadline, IERC20(state.token1), params.amountIn1, params.amountOut1Min, params.swapData1, 0, 0, bytes(""), params.amountAddMin0, params.amountAddMin1, ""), false);
            } else if (params.targetToken == state.token1) {
                (newTokenId, newLiquidity, token0Added, token1Added) = _swapAndMint(SwapAndMintParams(params.protocol, params.nfpm, IERC20(state.token0), IERC20(state.token1), state.fee, params.newTickLower, params.newTickUpper, state.amount0, state.amount1, params.userAddress, params.deadline, IERC20(state.token0), 0, 0, bytes(""), params.amountIn0, params.amountOut0Min, params.swapData0, params.amountAddMin0, params.amountAddMin1, ""), false);
            } else {
                (newTokenId, newLiquidity, token0Added, token1Added) = _swapAndMint(SwapAndMintParams(params.protocol, params.nfpm, IERC20(state.token0), IERC20(state.token1), state.fee, params.newTickLower, params.newTickUpper, state.amount0, state.amount1, params.userAddress, params.deadline, IERC20(address(0)), 0, 0, bytes(""), 0, 0, bytes(""), params.amountAddMin0, params.amountAddMin1, ""), false);
            }
            emit ChangeRange(address(params.nfpm), params.tokenId, newTokenId, newLiquidity, token0Added, token1Added);
        } else if (params.action == Action.AUTO_EXIT) {
            IWETH9 weth = _getWeth9(params.nfpm, params.protocol);
            uint256 targetAmount;
            if (state.token0 != params.targetToken) {
                (uint256 amountInDelta, uint256 amountOutDelta) = _swap(IERC20(state.token0), IERC20(params.targetToken), state.amount0, params.amountOut0Min, params.swapData0);
                if (amountInDelta < state.amount0) {
                    _transferToken(weth, params.userAddress, IERC20(state.token0), state.amount0 - amountInDelta, false);
                }
                targetAmount += amountOutDelta;
            } else {
                targetAmount += state.amount0; 
            }
            if (state.token1 != params.targetToken) {
                (uint256 amountInDelta, uint256 amountOutDelta) = _swap(IERC20(state.token1), IERC20(params.targetToken), state.amount1, params.amountOut1Min, params.swapData1);
                if (amountInDelta < state.amount1) {
                    _transferToken(weth, params.userAddress, IERC20(state.token1), state.amount1 - amountInDelta, false);
                }
                targetAmount += amountOutDelta;
            } else {
                targetAmount += state.amount1; 
            }

            // send complete target amount
            if (targetAmount != 0 && params.targetToken != address(0)) {
                _transferToken(weth, params.userAddress, IERC20(params.targetToken), targetAmount, false);
            }
        } else if (params.action == Action.AUTO_COMPOUND) {
            if (params.targetToken == state.token0) {
                _swapAndIncrease(SwapAndIncreaseLiquidityParams(params.protocol, params.nfpm, params.tokenId, state.amount0, state.amount1, params.userAddress, params.deadline, IERC20(state.token1), params.amountIn1, params.amountOut1Min, params.swapData1, 0, 0, bytes(""), params.amountAddMin0, params.amountAddMin1), IERC20(state.token0), IERC20(state.token1), false);
            } else if (state.token0 == state.token1) {
                _swapAndIncrease(SwapAndIncreaseLiquidityParams(params.protocol, params.nfpm, params.tokenId, state.amount0, state.amount1, params.userAddress, params.deadline, IERC20(state.token0), 0, 0, bytes(""), params.amountIn0, params.amountOut0Min, params.swapData0, params.amountAddMin0, params.amountAddMin1), IERC20(state.token0), IERC20(state.token1), false);
            } else {
                _swapAndIncrease(SwapAndIncreaseLiquidityParams(params.protocol, params.nfpm, params.tokenId, state.amount0, state.amount1, params.userAddress, params.deadline, IERC20(address(0)), 0, 0, bytes(""), 0, 0, bytes(""), params.amountAddMin0, params.amountAddMin1), IERC20(state.token0), IERC20(state.token1), false);
            }
        } else {
            revert NotSupportedAction();
        }
        params.nfpm.transferFrom(address(this), params.userAddress, params.tokenId);
    }

    receive() external payable{}
}
