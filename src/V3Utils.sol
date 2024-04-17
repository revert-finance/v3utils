// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "./Common.sol";

/// @title v3Utils v1.0
/// @notice Utility functions for Uniswap V3 positions
/// This is a completely ownerless/stateless contract - does not hold any ERC20 or NFTs.
/// It can be simply redeployed when new / better functionality is implemented
contract V3Utils is IERC721Receiver, Common {

    using SafeCast for uint256;
    /// @notice Constructor
    /// @param _swapRouter Krystal Exchange Proxy
    constructor(address _swapRouter, address admin, address withdrawer) Common(_swapRouter, admin, withdrawer) {}

    /// @notice Action which should be executed on provided NFT
    enum WhatToDo {
        CHANGE_RANGE,
        WITHDRAW_AND_COLLECT_AND_SWAP,
        COMPOUND_FEES
    }

    /// @notice Complete description of what should be executed on provided NFT - different fields are used depending on specified WhatToDo 
    struct Instructions {
        // what action to perform on provided Uniswap v3 position
        WhatToDo whatToDo;

        // protocol to provide lp
        Protocol protocol;

        // target token for swaps (if this is address(0) no swaps are executed)
        address targetToken;

        // for removing liquidity slippage
        uint256 amountRemoveMin0;
        uint256 amountRemoveMin1;

        // amountIn0 is used for swap and also as minAmount0 for decreased liquidity + collected fees
        uint256 amountIn0;
        // if token0 needs to be swapped to targetToken - set values
        uint256 amountOut0Min;
        bytes swapData0; // encoded data from 0x api call (address,bytes) - allowanceTarget,data

        // amountIn1 is used for swap and also as minAmount1 for decreased liquidity + collected fees
        uint256 amountIn1;
        // if token1 needs to be swapped to targetToken - set values
        uint256 amountOut1Min;
        bytes swapData1; // encoded data from 0x api call (address,bytes) - allowanceTarget,data

        // for creating new positions with CHANGE_RANGE
        int24 tickLower;
        int24 tickUpper;
        
        bool compoundFees;

        // remove liquidity amount for COMPOUND_FEES (in this case should be probably 0) / CHANGE_RANGE / WITHDRAW_AND_COLLECT_AND_SWAP
        uint128 liquidity;

        // for adding liquidity slippage
        uint256 amountAddMin0;
        uint256 amountAddMin1;

        // for all uniswap deadlineable functions
        uint256 deadline;

        // left over tokens will be sent to this address
        address recipient;

        // if tokenIn or tokenOut is WETH - unwrap
        bool unwrap;

        // protocol fees
        uint64 protocolFees;
    }

    /// @notice Execute instruction by pulling approved NFT instead of direct safeTransferFrom call from owner
    /// @param tokenId Token to process
    /// @param instructions Instructions to execute
    function execute(INonfungiblePositionManager _nfpm, uint256 tokenId, Instructions calldata instructions)  whenNotPaused() external
    {
        // must be approved beforehand
        _nfpm.safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            abi.encode(instructions)
        );
    }

    /// @notice ERC721 callback function. Called on safeTransferFrom and does manipulation as configured in encoded Instructions parameter. 
    /// At the end the NFT (and any newly minted NFT) is returned to sender. The leftover tokens are sent to instructions.recipient.
    function onERC721Received(address, address from, uint256 tokenId, bytes calldata data)  whenNotPaused() external override returns (bytes4) {
        INonfungiblePositionManager nfpm = INonfungiblePositionManager(msg.sender);
        // not allowed to send to itself
        if (from == address(this)) {
            revert SelfSend();
        }

        Instructions memory instructions = abi.decode(data, (Instructions));

        (address token0,address token1,uint128 liquidity,,,uint24 fee) = _getPosition(nfpm, instructions.protocol, tokenId);

        (uint256 amount0, uint256 amount1) = _decreaseLiquidityAndCollectFees(DecreaseAndCollectFeesParams(nfpm, IERC20(token0), IERC20(token1), tokenId, instructions.liquidity, instructions.deadline, instructions.amountRemoveMin0, instructions.amountRemoveMin1, instructions.compoundFees));

        // check if enough tokens are available for swaps
        if (amount0 < instructions.amountIn0 || amount1 < instructions.amountIn1) {
            revert AmountError();
        }

        if (instructions.whatToDo == WhatToDo.COMPOUND_FEES) {
            if (instructions.targetToken == token0) {
                (liquidity, amount0, amount1) = _swapAndIncrease(SwapAndIncreaseLiquidityParams(instructions.protocol, nfpm, tokenId, amount0, amount1, instructions.recipient, instructions.deadline, IERC20(token1), instructions.amountIn1, instructions.amountOut1Min, instructions.swapData1, 0, 0, "", instructions.amountAddMin0, instructions.amountAddMin1), IERC20(token0), IERC20(token1), instructions.unwrap);
            } else if (instructions.targetToken == token1) {
                (liquidity, amount0, amount1) = _swapAndIncrease(SwapAndIncreaseLiquidityParams(instructions.protocol, nfpm, tokenId, amount0, amount1, instructions.recipient, instructions.deadline, IERC20(token0), 0, 0, "", instructions.amountIn0, instructions.amountOut0Min, instructions.swapData0, instructions.amountAddMin0, instructions.amountAddMin1), IERC20(token0), IERC20(token1), instructions.unwrap);
            } else {
                // no swap is done here
                (liquidity,amount0, amount1) = _swapAndIncrease(SwapAndIncreaseLiquidityParams(instructions.protocol, nfpm, tokenId, amount0, amount1, instructions.recipient, instructions.deadline, IERC20(address(0)), 0, 0, "", 0, 0, "", instructions.amountAddMin0, instructions.amountAddMin1), IERC20(token0), IERC20(token1), instructions.unwrap);
            }
            emit CompoundFees(address(nfpm), tokenId, liquidity, amount0, amount1);            
        } else if (instructions.whatToDo == WhatToDo.CHANGE_RANGE) {

            uint256 newTokenId;
            uint256 newLiquidity;
            uint256 token0Added;
            uint256 token1Added;
            if (instructions.targetToken == token0) {
                (newTokenId, newLiquidity, token0Added, token1Added) = _swapAndMint(SwapAndMintParams(instructions.protocol, nfpm, IERC20(token0), IERC20(token1), fee, instructions.tickLower, instructions.tickUpper, amount0, amount1, instructions.recipient, instructions.deadline, IERC20(token1), instructions.amountIn1, instructions.amountOut1Min, instructions.swapData1, 0, 0, "", instructions.amountAddMin0, instructions.amountAddMin1), instructions.unwrap);
            } else if (instructions.targetToken == token1) {
                (newTokenId, newLiquidity, token0Added, token1Added) = _swapAndMint(SwapAndMintParams(instructions.protocol, nfpm, IERC20(token0), IERC20(token1), fee, instructions.tickLower, instructions.tickUpper, amount0, amount1, instructions.recipient, instructions.deadline, IERC20(token0), 0, 0, "", instructions.amountIn0, instructions.amountOut0Min, instructions.swapData0, instructions.amountAddMin0, instructions.amountAddMin1), instructions.unwrap);
            } else {
                // no swap is done here
                (newTokenId, newLiquidity, token0Added, token1Added) = _swapAndMint(SwapAndMintParams(instructions.protocol, nfpm, IERC20(token0), IERC20(token1), fee, instructions.tickLower, instructions.tickUpper, amount0, amount1, instructions.recipient, instructions.deadline, IERC20(address(0)), 0, 0, "", 0, 0, "", instructions.amountAddMin0, instructions.amountAddMin1), instructions.unwrap);
            }

            emit ChangeRange(msg.sender, tokenId, newTokenId, newLiquidity, token0Added, token1Added);
        } else if (instructions.whatToDo == WhatToDo.WITHDRAW_AND_COLLECT_AND_SWAP) {
            IWETH9 weth = _getWeth9(nfpm, instructions.protocol);
            uint256 targetAmount;
            if (token0 != instructions.targetToken) {
                (uint256 amountInDelta, uint256 amountOutDelta) = _swap(IERC20(token0), IERC20(instructions.targetToken), amount0, instructions.amountOut0Min, instructions.swapData0);
                if (amountInDelta < amount0) {
                    _transferToken(weth, instructions.recipient, IERC20(token0), amount0 - amountInDelta, instructions.unwrap);
                }
                targetAmount += amountOutDelta;
            } else {
                targetAmount += amount0; 
            }
            if (token1 != instructions.targetToken) {
                (uint256 amountInDelta, uint256 amountOutDelta) = _swap(IERC20(token1), IERC20(instructions.targetToken), amount1, instructions.amountOut1Min, instructions.swapData1);
                if (amountInDelta < amount1) {
                    _transferToken(weth, instructions.recipient, IERC20(token1), amount1 - amountInDelta, instructions.unwrap);
                }
                targetAmount += amountOutDelta;
            } else {
                targetAmount += amount1; 
            }

            // send complete target amount
            if (targetAmount != 0 && instructions.targetToken != address(0)) {
                _transferToken(weth, instructions.recipient, IERC20(instructions.targetToken), targetAmount, instructions.unwrap);
            }

            emit WithdrawAndCollectAndSwap(address(nfpm), tokenId, instructions.targetToken, targetAmount);
        } else {
            revert NotSupportedWhatToDo();
        }
        
        // return token to owner (this line guarantees that token is returned to originating owner)
        nfpm.transferFrom(address(this), from, tokenId);

        return IERC721Receiver.onERC721Received.selector;
    }

    /// @notice Params for swap() function
    struct SwapParams {
        IWETH9 weth;
        IERC20 tokenIn;
        IERC20 tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        address recipient; // recipient of tokenOut and leftover tokenIn (if any leftover)
        bytes swapData;
        bool unwrap; // if tokenIn or tokenOut is WETH - unwrap
    }

    /// @notice Swaps amountIn of tokenIn for tokenOut - returning at least minAmountOut
    /// @param params Swap configuration
    /// If tokenIn is wrapped native token - both the token or the wrapped token can be sent (the sum of both must be equal to amountIn)
    /// Optionally unwraps any wrapped native token and returns native token instead
    function swap(SwapParams calldata params)  whenNotPaused() external payable returns (uint256 amountOut) {

        if (params.tokenIn == params.tokenOut) {
            revert SameToken();
        }

        _prepareSwap(params.weth, params.tokenIn, IERC20(address(0)), IERC20(address(0)), params.amountIn, 0, 0);

        uint256 amountInDelta;
        (amountInDelta, amountOut) = _swap(params.tokenIn, params.tokenOut, params.amountIn, params.minAmountOut, params.swapData);

        // send swapped amount of tokenOut
        if (amountOut != 0) {
            _transferToken(params.weth, params.recipient, params.tokenOut, amountOut, params.unwrap);
        }

        // if not all was swapped - return leftovers of tokenIn
        uint256 leftOver = params.amountIn - amountInDelta;
        if (leftOver != 0) {
            _transferToken(params.weth, params.recipient, params.tokenIn, leftOver, params.unwrap);
        }
    }

    /// @notice Does 1 or 2 swaps from swapSourceToken to token0 and token1 and adds as much as possible liquidity to a newly minted position.
    /// @param params Swap and mint configuration
    /// Newly minted NFT and leftover tokens are returned to recipient
    function swapAndMint(SwapAndMintParams calldata params)  whenNotPaused() external payable returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) {
        if (params.token0 == params.token1) {
            revert SameToken();
        }
        IWETH9 weth = _getWeth9(params.nfpm, params.protocol);
        _prepareSwap(weth, params.token0, params.token1, params.swapSourceToken, params.amount0, params.amount1, params.amountIn0 + params.amountIn1);
        (tokenId, liquidity, amount0, amount1) = _swapAndMint(params, msg.value != 0);
    }

    /// @notice Does 1 or 2 swaps from swapSourceToken to token0 and token1 and adds as much as possible liquidity to any existing position (no need to be position owner).
    /// @param params Swap and increase liquidity configuration
    // Sends any leftover tokens to recipient.
    function swapAndIncreaseLiquidity(SwapAndIncreaseLiquidityParams calldata params)  whenNotPaused() external payable returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        address owner = params.nfpm.ownerOf(params.tokenId);
        require(owner == msg.sender, "sender is not owner of position");
        (address token0,address token1,,,,) = _getPosition(params.nfpm, params.protocol, params.tokenId);
        IWETH9 weth = _getWeth9(params.nfpm, params.protocol);
        _prepareSwap(weth, IERC20(token0), IERC20(token1), params.swapSourceToken, params.amount0, params.amount1, params.amountIn0 + params.amountIn1);
        (liquidity, amount0, amount1) = _swapAndIncrease(params, IERC20(token0), IERC20(token1), msg.value != 0);
    }
    // needed for WETH unwrapping
    receive() external payable{}
}