// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "v3-core/libraries/FullMath.sol";

import "./Common.sol";

contract LpAutomation is AccessControl, Common {

    error SameRange();
    error LiquidityChanged();
    error SwapAmountTooLarge();

    bytes32 public constant OWNER_ROLE = bytes32(uint256(0x00));
    bytes32 public constant OPERATOR_ROLE = bytes32(uint256(0x01));
    bytes32 public constant WITHDRAWER_ROLE = bytes32(uint256(0x02));

    constructor(address _swapRouter) Common(_swapRouter) {
        _grantRole(OWNER_ROLE, tx.origin);
        _grantRole(OPERATOR_ROLE, tx.origin);
        _grantRole(WITHDRAWER_ROLE, tx.origin);
    }

    struct PermitParams {
        address spender;
        uint256 tokenId;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
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

    struct AdjustRangeParams {
        INonfungiblePositionManager nfpm;
        Protocol protocol;
        PermitParams permit;

        address userAddress;
        uint256 tokenId;
        bool swap0To1;
        uint256 amountIn; // if this is set to 0 no swap happens
        uint256 amountOutMin;
        bytes swapData;
        uint128 liquidity; // liquidity the calculations are based on
        uint256 amountRemoveMin0; // min amount to be removed from liquidity
        uint256 amountRemoveMin1; // min amount to be removed from liquidity
        uint256 deadline; // for uniswap operations - operator promises fair value
        uint64 gasFeeX64;  // amount of tokens to be used as gas fee
        uint64 protocolFeeX64;  // amount of tokens to be used as protocol fee

        int24 newTickLower;
        int24 newTickUpper;

        // min amount to be added after swap
        uint256 amountAddMin0;
        uint256 amountAddMin1;
    }

    function adjustRange(AdjustRangeParams calldata params) public payable onlyRole(OPERATOR_ROLE) {
        params.nfpm.permit(params.permit.spender, params.permit.tokenId, params.permit.deadline, params.permit.v, params.permit.r, params.permit.s);
        params.nfpm.transferFrom(params.userAddress, address(this), params.tokenId);

        ExecuteState memory state;
        (state.token0, state.token1, state.liquidity, state.tickLower, state.tickUpper, state.fee) = _getPosition(params.nfpm, params.protocol, params.tokenId);

        if (state.liquidity != params.liquidity) {
            revert LiquidityChanged();
        }

        (state.amount0, state.amount1,,) = _decreaseFullLiquidityAndCollect(params.nfpm, params.tokenId, params.liquidity, params.deadline, params.amountRemoveMin0, params.amountRemoveMin1);
        {
            uint256 fees0 = FullMath.mulDiv(state.amount0, params.gasFeeX64 + params.protocolFeeX64, Q64);
            uint256 fees1 = FullMath.mulDiv(state.amount1, params.gasFeeX64 + params.protocolFeeX64, Q64);
            state.amount0 -= fees0;
            state.amount1 -= fees1;
        }
        if (params.swap0To1 && params.amountIn > state.amount0 || !params.swap0To1 && params.amountIn > state.amount1) {
            revert SwapAmountTooLarge();
        }

        if (state.tickLower == params.newTickLower && state.tickUpper == params.newTickUpper) {
            revert SameRange();
        }

        (uint256 amountInDelta, uint256 amountOutDelta) = _swap(params.swap0To1 ? IERC20(state.token0) : IERC20(state.token1), params.swap0To1 ? IERC20(state.token1) : IERC20(state.token0), params.amountIn, params.amountOutMin, params.swapData);
        
        state.amount0 = params.swap0To1 ? state.amount0 - amountInDelta : state.amount0 + amountOutDelta;
        state.amount1 = params.swap0To1 ? state.amount1 + amountOutDelta : state.amount1 - amountInDelta;

        _swapAndMint(SwapAndMintParams(
            params.protocol, 
            params.nfpm, 
            IERC20(state.token0), IERC20(state.token1), 
            state.fee, 
            state.tickLower, state.tickUpper, 
            state.amount0,
            state.amount1, 
            params.userAddress, 
            params.deadline, 
            params.swap0To1? IERC20(state.token0) : IERC20(state.token1), 
            params.amountIn, params.amountOutMin, params.swapData,
            0, 0, "", params.amountAddMin0, params.amountAddMin1, ""
        ), false);
    }

    /**
     * @notice Withdraws token balance
     * @param tokens Addresses of tokens to withdraw
     * @param to Address to send to
     */
    function withdrawBalances(address[] calldata tokens, address to) onlyRole(WITHDRAWER_ROLE) external {
        uint256 nativeBalance = address(this).balance;
        if (nativeBalance > 0) {
            payable(to).transfer(nativeBalance);
        }
        uint i;
        uint count = tokens.length;
        for(;i < count;++i) {
            uint256 balance = IERC20(tokens[i]).balanceOf(address(this));
            if (balance > 0) {
                _transferToken(IWETH9(address(0)), to, IERC20(tokens[i]), balance, true);
            }
        }
    }

    receive() external payable{}
}
