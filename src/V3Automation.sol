// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Common.sol";

contract V3Automation is AccessControl, Common {

    error SameRange();
    error LiquidityChanged();
    error SwapAmountTooLarge();

    bytes32 public constant OWNER_ROLE = bytes32(uint256(0x00));
    bytes32 public constant OPERATOR_ROLE = bytes32(uint256(0x01));
    bytes32 public constant WITHDRAWER_ROLE = bytes32(uint256(0x02));

    constructor(address _swapRouter, address firstOwner) Common(_swapRouter) {
        _grantRole(OWNER_ROLE, firstOwner);
        _grantRole(OPERATOR_ROLE, firstOwner);
        _grantRole(WITHDRAWER_ROLE, firstOwner);
    }

    enum Action {
        AUTO_ADJUST,
        AUTO_EXIT
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

        // min amount to be added after swap
        uint256 amountAddMin0;
        uint256 amountAddMin1;

        // signature fo permit for tokenId, and deadline
        // these params use for auto exit.
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function execute(ExecuteParams calldata params) public payable onlyRole(OPERATOR_ROLE) {
        if (params.action == Action.AUTO_EXIT &&
            !params.nfpm.isApprovedForAll(params.userAddress, address(this))
            && params.nfpm.getApproved(params.tokenId) != address(this)
        ) {
            params.nfpm.permit(address(this), params.tokenId, params.deadline, params.v, params.r, params.s);
        }
        params.nfpm.transferFrom(params.userAddress, address(this), params.tokenId);

        ExecuteState memory state;
        (state.token0, state.token1, state.liquidity, state.tickLower, state.tickUpper, state.fee) = _getPosition(params.nfpm, params.protocol, params.tokenId);

        if (state.liquidity != params.liquidity) {
            revert LiquidityChanged();
        }

        (state.amount0, state.amount1,,) = _decreaseFullLiquidityAndCollectAndTakeFees(params.nfpm, params.tokenId, params.liquidity, params.deadline, params.amountRemoveMin0, params.amountRemoveMin1, params.gasFeeX64 + params.protocolFeeX64);

        if (params.action == Action.AUTO_ADJUST) {
            if (state.tickLower == params.newTickLower && state.tickUpper == params.newTickUpper) {
                revert SameRange();
            }

            // todo: takes returns to emit necessary events
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
                params.targetToken == state.token0 ? IERC20(state.token1) : IERC20(state.token0),
                
                params.amountIn0,
                params.amountOut0Min,
                params.swapData0,

                params.amountIn1,
                params.amountOut1Min,
                params.swapData1,

                params.amountAddMin0, 
                params.amountAddMin1, 
                ""
            ), false);
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
        } else {
            revert NotSupportedWhatToDo();
        }
        params.nfpm.transferFrom(address(this), params.userAddress, params.tokenId);
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
