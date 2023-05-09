// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Runner.sol";

/// @title StopLossLimitor
/// @notice Lets a v3 position to be automatically removed or swapped to the opposite token when it reaches a certain tick. 
/// A revert controlled bot is responsible for the execution of optimized swaps (using external swap router)
/// Positions need to approved for all NFTs for the contract and configured with addToken method
contract StopLossLimitor is Runner {

    error NotFound();
    error NoLiquidity();
    error NotConfigured();
    error NotInCondition();
    error MissingSwapData();
    error OnlyContractOwnerCanSwap();
    error ConfigError();

    event Executed(
        address account,
        bool isSwap,
        uint256 tokenId,
        uint256 amountReturned0,
        uint256 amountReturned1,
        address token0,
        address token1
    );
    event PositionConfigured(
        uint256 indexed tokenId,
        bool isActive,
        bool token0Swap,
        bool token1Swap,
        uint64 token0SlippageX64,
        uint64 token1SlippageX64,
        int24 token0TriggerTick,
        int24 token1TriggerTick
    );

    constructor(INonfungiblePositionManager _npm, address _swapRouter, address _operator, uint32 _TWAPSeconds, uint16 _maxTWAPTickDifference) Runner(_npm, _swapRouter, _operator, _TWAPSeconds, _maxTWAPTickDifference) {
    }

    struct PositionConfig {

        // if position is active
        bool isActive;

        // should swap token to other token when triggered
        bool token0Swap;
        bool token1Swap;

        // max price difference from current pool price for swap / Q64
        uint64 token0SlippageX64;
        uint64 token1SlippageX64;

        // when should action be triggered (when this tick is reached - allow execute)
        int24 token0TriggerTick;
        int24 token1TriggerTick;
    }

    mapping (uint256 => PositionConfig) public positionConfigs;


    /// @notice params for execute()
    struct ExecuteParams {
        uint256 tokenId; // tokenid to process
        bytes swapData; // if its a swap order - must include swap data
        uint256 deadline; // for uniswap operations - operator promises fair value
    }

    struct ExecuteState {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 amount0;
        uint256 amount1;
        uint256 amountOutMin;
        uint256 amountInDelta;
        uint256 amountOutDelta;
        IUniswapV3Pool pool;
        uint256 protocolReward0;
        uint256 protocolReward1;
        uint256 swapAmount;
        int24 tick;
        bool isSwap;
        bool isAbove;
        address owner;
    }

    /**
     * @notice Handle token (must be in correct state)
     * Can only be called only from configured operator account
     * Swap needs to be done with max price difference from current pool price - otherwise reverts
     */
    function execute(ExecuteParams memory params) external {

        if (msg.sender != operator) {
            revert Unauthorized();
        }

        ExecuteState memory state;
        PositionConfig storage config = positionConfigs[params.tokenId];

        if (!config.isActive) {
            revert NotConfigured();
        }

        // get position info
        (,,state.token0, state.token1, state.fee, state.tickLower, state.tickUpper, state.liquidity, , , , ) =  nonfungiblePositionManager.positions(params.tokenId);

        // so can be executed only once
        if (state.liquidity == 0) {
            revert NoLiquidity();
        }

        state.pool = _getPool(state.token0, state.token1, state.fee);
        (,state.tick,,,,,) = state.pool.slot0();

        // not triggered
        if (config.token0TriggerTick <= state.tick && state.tick <= config.token1TriggerTick) {
            revert NotInCondition();
        }
    
        state.isAbove = state.tick > config.token1TriggerTick;
        state.isSwap = !state.isAbove && config.token0Swap || state.isAbove && config.token1Swap;
       
        // decrease full liquidity for given position (one sided only) - and return fees as well
        (state.amount0, state.amount1) = _decreaseFullLiquidityAndCollect(params.tokenId, state.liquidity, params.deadline);

        // swap to other token
        if (state.isSwap) {
            if (params.swapData.length == 0) {
                revert MissingSwapData();
            }

            state.swapAmount = state.isAbove ? state.amount1 : state.amount0;
            
            // checks if price in valid oracle range and calculates amountOutMin
            (state.amountOutMin,,,) = _validateSwap(!state.isAbove, state.swapAmount, state.pool, TWAPSeconds, maxTWAPTickDifference, state.isAbove ? config.token1SlippageX64 : config.token0SlippageX64);

            (state.amountInDelta, state.amountOutDelta) = _swap(swapRouter, state.isAbove ? IERC20(state.token1) : IERC20(state.token0), state.isAbove ? IERC20(state.token0) : IERC20(state.token1), state.swapAmount, state.amountOutMin, params.swapData);

            state.amount0 = state.isAbove ? state.amount0 + state.amountOutDelta : state.amount0 - state.amountInDelta;
            state.amount1 = state.isAbove ? state.amount1 - state.amountInDelta : state.amount1 + state.amountOutDelta;
        }
     
        // protocol reward is removed from both token amounts and kept in contract for later retrieval
        state.protocolReward0 = state.amount0 * protocolRewardX64 / Q64;
        state.protocolReward1 = state.amount1 * protocolRewardX64 / Q64;
        state.amount0 -= state.protocolReward0;
        state.amount1 -= state.protocolReward1;

        state.owner = nonfungiblePositionManager.ownerOf(params.tokenId);
        if (state.amount0 > 0) {
            _transferToken(state.owner, IERC20(state.token0), state.amount0, true);
        }
        if (state.amount1 > 0) {
            _transferToken(state.owner, IERC20(state.token1), state.amount1, true);
        }

        // log event
        emit Executed(msg.sender, state.isSwap, params.tokenId, state.amount0, state.amount1, state.token0, state.token1);
    }

    // function to configure a token to be used with this runner
    // it needs to have approvals set for this contract beforehand
    function configToken(uint256 tokenId, PositionConfig memory config) external {
        address owner = nonfungiblePositionManager.ownerOf(tokenId);
        if (owner != msg.sender) {
            revert Unauthorized();
        }

        (,,address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper,,,,,) = nonfungiblePositionManager.positions(tokenId);

        if (config.isActive) {
            // trigger ticks have to be on the correct side of position range
            (,,,,, int24 tickLower, int24 tickUpper,,,,,) = nonfungiblePositionManager.positions(tokenId);
            if (tickLower <= config.token0TriggerTick || tickUpper > config.token1TriggerTick) {
                revert InvalidConfig();
            }
        }

        positionConfigs[tokenId] = config;

        emit PositionConfigured(
            tokenId,
            config.isActive,
            config.token0Swap,
            config.token1Swap,
            config.token0SlippageX64,
            config.token1SlippageX64,
            config.token0TriggerTick,
            config.token1TriggerTick
        );
    }
}