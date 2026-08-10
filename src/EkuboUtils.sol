// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {EkuboPoolKey, IEkuboPositions} from "./interfaces/IEkuboPositions.sol";

interface IWETH9 is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

/// @title EkuboUtils
/// @notice Ownerless utility for creating and managing canonical Ekubo concentrated-liquidity positions.
/// @dev Extensions and stableswap pools are deliberately unsupported. Ekubo's native token address(0)
///      is represented as WETH at this contract's user and swap boundaries.
contract EkuboUtils is IERC721Receiver {
    using SafeERC20 for IERC20;

    IEkuboPositions public immutable positions;
    address public immutable core;
    IWETH9 public immutable weth;
    address public immutable swapRouter;

    uint256 private _locked = 1;

    error AmountError();
    error AmountOverflow();
    error DeadlineExpired();
    error EtherSendFailed();
    error ExtensionsNotSupported();
    error FullWithdrawalRequired(uint128 available, uint128 requested);
    error InvalidPool();
    error InvalidRecipient();
    error InvalidTicks();
    error MissingSwapData();
    error NativeWrappedPairNotSupported();
    error NotSupportedWhatToDo();
    error InvalidEtherSender();
    error ReentrantCall();
    error SameToken();
    error SelfSend();
    error SlippageError();
    error StableswapNotSupported();
    error SwapFailed();
    error TargetTokenNotInPool();
    error TooMuchEtherSent();
    error TransferError();
    error WrongContract();

    event CompoundFees(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    event ChangeRange(uint256 indexed tokenId, uint256 indexed newTokenId);
    event Swap(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event SwapAndIncreaseLiquidity(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    event SwapAndMint(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    event WithdrawAndCollectAndSwap(uint256 indexed tokenId, address indexed token, uint256 amount);

    enum WhatToDo {
        CHANGE_RANGE,
        WITHDRAW_AND_COLLECT_AND_SWAP,
        COMPOUND_FEES
    }

    struct PositionSpec {
        EkuboPoolKey poolKey;
        int32 tickLower;
        int32 tickUpper;
    }

    struct Instructions {
        WhatToDo whatToDo;
        PositionSpec position;
        // address(0) means no swap for compounding/range changes. Use WETH to target native ETH.
        address targetToken;
        uint128 amountRemoveMin0;
        uint128 amountRemoveMin1;
        uint128 amountIn0;
        uint128 amountOut0Min;
        bytes swapData0;
        uint128 amountIn1;
        uint128 amountOut1Min;
        bytes swapData1;
        bool collectFees;
        PositionSpec newPosition;
        uint128 liquidity;
        uint128 minLiquidity;
        uint256 deadline;
        address recipient;
        address recipientNFT;
        bool unwrap;
        bytes returnData;
        bytes newPositionReturnData;
    }

    struct SwapParams {
        IERC20 tokenIn;
        IERC20 tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        address recipient;
        bytes swapData;
        bool unwrap;
    }

    struct SwapAndMintParams {
        PositionSpec position;
        uint256 amount0;
        uint256 amount1;
        address recipient;
        address recipientNFT;
        uint256 deadline;
        IERC20 swapSourceToken;
        uint256 amountIn0;
        uint256 amountOut0Min;
        bytes swapData0;
        uint256 amountIn1;
        uint256 amountOut1Min;
        bytes swapData1;
        uint128 minLiquidity;
        bytes returnData;
        bool unwrap;
    }

    struct SwapAndIncreaseLiquidityParams {
        uint256 tokenId;
        PositionSpec position;
        uint256 amount0;
        uint256 amount1;
        address recipient;
        uint256 deadline;
        IERC20 swapSourceToken;
        uint256 amountIn0;
        uint256 amountOut0Min;
        bytes swapData0;
        uint256 amountIn1;
        uint256 amountOut1Min;
        bytes swapData1;
        uint128 minLiquidity;
        bool unwrap;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert ReentrantCall();
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(IEkuboPositions _positions, address _core, IWETH9 _weth, address _swapRouter) {
        if (
            address(_positions) == address(0) || _core == address(0) || address(_weth) == address(0)
                || _swapRouter == address(0)
        ) {
            revert InvalidRecipient();
        }
        positions = _positions;
        core = _core;
        weth = _weth;
        swapRouter = _swapRouter;
    }

    /// @notice Pulls an approved Ekubo NFT into this contract and executes an operation.
    function execute(uint256 tokenId, Instructions calldata instructions) external {
        positions.safeTransferFrom(msg.sender, address(this), tokenId, abi.encode(instructions));
    }

    /// @notice Executes instructions supplied with an Ekubo NFT transfer, then returns the original NFT.
    function onERC721Received(address, address from, uint256 tokenId, bytes calldata data)
        external
        nonReentrant
        returns (bytes4)
    {
        if (msg.sender != address(positions)) revert WrongContract();
        if (from == address(this)) revert SelfSend();

        Instructions memory instructions = abi.decode(data, (Instructions));
        _checkDeadline(instructions.deadline);
        _validateRecipient(instructions.recipient);
        _validatePosition(instructions.position);

        (uint128 availableLiquidity,,,,) = positions.getPositionFeesAndLiquidity(
            tokenId, instructions.position.poolKey, instructions.position.tickLower, instructions.position.tickUpper
        );
        if (instructions.liquidity > availableLiquidity) revert AmountError();
        if (instructions.whatToDo == WhatToDo.CHANGE_RANGE && instructions.liquidity != availableLiquidity) {
            revert FullWithdrawalRequired(availableLiquidity, instructions.liquidity);
        }

        (uint256 amount0, uint256 amount1) =
            _withdraw(tokenId, instructions.position, instructions.liquidity, instructions.collectFees);
        if (amount0 < instructions.amountRemoveMin0 || amount1 < instructions.amountRemoveMin1) {
            revert SlippageError();
        }
        if (amount0 < instructions.amountIn0 || amount1 < instructions.amountIn1) revert AmountError();

        if (instructions.whatToDo == WhatToDo.COMPOUND_FEES) {
            (uint256 total0, uint256 total1) = _rebalancePositionAmounts(
                instructions.position,
                instructions.targetToken,
                amount0,
                amount1,
                instructions.amountIn0,
                instructions.amountOut0Min,
                instructions.swapData0,
                instructions.amountIn1,
                instructions.amountOut1Min,
                instructions.swapData1
            );
            (uint128 addedLiquidity, uint128 added0, uint128 added1) =
                _deposit(tokenId, instructions.position, total0, total1, instructions.minLiquidity);
            _returnLeftovers(
                instructions.recipient,
                instructions.position.poolKey,
                total0,
                total1,
                added0,
                added1,
                instructions.unwrap
            );
            emit CompoundFees(tokenId, addedLiquidity, added0, added1);
        } else if (instructions.whatToDo == WhatToDo.CHANGE_RANGE) {
            _validatePosition(instructions.newPosition);
            _requireSamePair(instructions.position.poolKey, instructions.newPosition.poolKey);
            _validateRecipient(instructions.recipientNFT);

            (uint256 total0, uint256 total1) = _rebalancePositionAmounts(
                instructions.position,
                instructions.targetToken,
                amount0,
                amount1,
                instructions.amountIn0,
                instructions.amountOut0Min,
                instructions.swapData0,
                instructions.amountIn1,
                instructions.amountOut1Min,
                instructions.swapData1
            );
            (uint256 newTokenId, uint128 addedLiquidity, uint128 added0, uint128 added1) =
                _mintAndDeposit(instructions.newPosition, total0, total1, instructions.minLiquidity);
            positions.safeTransferFrom(
                address(this), instructions.recipientNFT, newTokenId, instructions.newPositionReturnData
            );
            _returnLeftovers(
                instructions.recipient,
                instructions.newPosition.poolKey,
                total0,
                total1,
                added0,
                added1,
                instructions.unwrap
            );
            emit SwapAndMint(newTokenId, addedLiquidity, added0, added1);
            emit ChangeRange(tokenId, newTokenId);
        } else if (instructions.whatToDo == WhatToDo.WITHDRAW_AND_COLLECT_AND_SWAP) {
            _withdrawAndSwap(instructions, amount0, amount1, tokenId);
        } else {
            revert NotSupportedWhatToDo();
        }

        positions.safeTransferFrom(address(this), from, tokenId, instructions.returnData);
        return IERC721Receiver.onERC721Received.selector;
    }

    /// @notice Swaps an exact maximum input through the configured router and returns all resulting assets.
    function swap(SwapParams calldata params) external payable nonReentrant returns (uint256 amountOut) {
        if (address(params.tokenIn) == address(params.tokenOut)) revert SameToken();
        _validateRecipient(params.recipient);
        _prepareAdd(params.tokenIn, IERC20(address(0)), IERC20(address(0)), params.amountIn, 0, 0);

        (uint256 amountInDelta, uint256 amountOutDelta) =
            _swap(params.tokenIn, params.tokenOut, params.amountIn, params.minAmountOut, params.swapData);
        amountOut = amountOutDelta;
        if (amountOut != 0) _transferToken(params.recipient, params.tokenOut, amountOut, params.unwrap);
        if (amountInDelta < params.amountIn) {
            _transferToken(params.recipient, params.tokenIn, params.amountIn - amountInDelta, params.unwrap);
        }
    }

    /// @notice Swaps as requested and deposits the resulting pair into a newly minted Ekubo NFT.
    function swapAndMint(SwapAndMintParams calldata params)
        external
        payable
        nonReentrant
        returns (uint256 tokenId, uint128 liquidity, uint128 amount0, uint128 amount1)
    {
        _checkDeadline(params.deadline);
        _validatePosition(params.position);
        _validateRecipient(params.recipient);
        _validateRecipient(params.recipientNFT);

        (IERC20 token0, IERC20 token1) = _normalizedTokens(params.position.poolKey);
        _prepareAdd(
            token0, token1, params.swapSourceToken, params.amount0, params.amount1, params.amountIn0 + params.amountIn1
        );
        (uint256 total0, uint256 total1) = _swapAndPrepareAmounts(params, token0, token1);
        (tokenId, liquidity, amount0, amount1) = _mintAndDeposit(params.position, total0, total1, params.minLiquidity);
        positions.safeTransferFrom(address(this), params.recipientNFT, tokenId, params.returnData);
        _returnLeftovers(params.recipient, params.position.poolKey, total0, total1, amount0, amount1, params.unwrap);
        emit SwapAndMint(tokenId, liquidity, amount0, amount1);
    }

    /// @notice Swaps as requested and adds the resulting pair to an approved Ekubo NFT position.
    /// @dev Ekubo requires this contract to be approved for tokenId before calling this function.
    function swapAndIncreaseLiquidity(SwapAndIncreaseLiquidityParams calldata params)
        external
        payable
        nonReentrant
        returns (uint128 liquidity, uint128 amount0, uint128 amount1)
    {
        _checkDeadline(params.deadline);
        _validatePosition(params.position);
        _validateRecipient(params.recipient);

        (IERC20 token0, IERC20 token1) = _normalizedTokens(params.position.poolKey);
        _prepareAdd(
            token0, token1, params.swapSourceToken, params.amount0, params.amount1, params.amountIn0 + params.amountIn1
        );

        SwapAndMintParams memory mintParams = SwapAndMintParams({
            position: params.position,
            amount0: params.amount0,
            amount1: params.amount1,
            recipient: params.recipient,
            recipientNFT: address(0),
            deadline: params.deadline,
            swapSourceToken: params.swapSourceToken,
            amountIn0: params.amountIn0,
            amountOut0Min: params.amountOut0Min,
            swapData0: params.swapData0,
            amountIn1: params.amountIn1,
            amountOut1Min: params.amountOut1Min,
            swapData1: params.swapData1,
            minLiquidity: params.minLiquidity,
            returnData: "",
            unwrap: params.unwrap
        });
        (uint256 total0, uint256 total1) = _swapAndPrepareAmounts(mintParams, token0, token1);
        (liquidity, amount0, amount1) = _deposit(params.tokenId, params.position, total0, total1, params.minLiquidity);
        _returnLeftovers(params.recipient, params.position.poolKey, total0, total1, amount0, amount1, params.unwrap);
        emit SwapAndIncreaseLiquidity(params.tokenId, liquidity, amount0, amount1);
    }

    function _withdrawAndSwap(Instructions memory instructions, uint256 amount0, uint256 amount1, uint256 tokenId)
        internal
    {
        if (instructions.targetToken == address(0)) revert InvalidPool();
        (IERC20 token0, IERC20 token1) = _normalizedTokens(instructions.position.poolKey);
        IERC20 target = IERC20(instructions.targetToken);
        uint256 targetAmount;

        if (address(token0) == address(target)) {
            targetAmount += amount0;
        } else {
            (uint256 spent0, uint256 received0) =
                _swap(token0, target, amount0, instructions.amountOut0Min, instructions.swapData0);
            targetAmount += received0;
            if (spent0 < amount0) {
                _transferToken(instructions.recipient, token0, amount0 - spent0, instructions.unwrap);
            }
        }

        if (address(token1) == address(target)) {
            targetAmount += amount1;
        } else {
            (uint256 spent1, uint256 received1) =
                _swap(token1, target, amount1, instructions.amountOut1Min, instructions.swapData1);
            targetAmount += received1;
            if (spent1 < amount1) {
                _transferToken(instructions.recipient, token1, amount1 - spent1, instructions.unwrap);
            }
        }

        if (targetAmount != 0) _transferToken(instructions.recipient, target, targetAmount, instructions.unwrap);
        emit WithdrawAndCollectAndSwap(tokenId, address(target), targetAmount);
    }

    function _rebalancePositionAmounts(
        PositionSpec memory position,
        address targetToken,
        uint256 amount0,
        uint256 amount1,
        uint256 amountIn0,
        uint256 amountOut0Min,
        bytes memory swapData0,
        uint256 amountIn1,
        uint256 amountOut1Min,
        bytes memory swapData1
    ) internal returns (uint256 total0, uint256 total1) {
        (IERC20 token0, IERC20 token1) = _normalizedTokens(position.poolKey);
        total0 = amount0;
        total1 = amount1;

        if (targetToken == address(0)) return (total0, total1);
        if (targetToken == address(token0)) {
            (uint256 spent, uint256 received) = _swap(token1, token0, amountIn1, amountOut1Min, swapData1);
            total1 -= spent;
            total0 += received;
        } else if (targetToken == address(token1)) {
            (uint256 spent, uint256 received) = _swap(token0, token1, amountIn0, amountOut0Min, swapData0);
            total0 -= spent;
            total1 += received;
        } else {
            revert TargetTokenNotInPool();
        }
    }

    function _swapAndPrepareAmounts(SwapAndMintParams memory params, IERC20 token0, IERC20 token1)
        internal
        returns (uint256 total0, uint256 total1)
    {
        if (address(params.swapSourceToken) == address(token0)) {
            if (params.amount0 < params.amountIn1) revert AmountError();
            (uint256 spent, uint256 received) =
                _swap(token0, token1, params.amountIn1, params.amountOut1Min, params.swapData1);
            total0 = params.amount0 - spent;
            total1 = params.amount1 + received;
        } else if (address(params.swapSourceToken) == address(token1)) {
            if (params.amount1 < params.amountIn0) revert AmountError();
            (uint256 spent, uint256 received) =
                _swap(token1, token0, params.amountIn0, params.amountOut0Min, params.swapData0);
            total1 = params.amount1 - spent;
            total0 = params.amount0 + received;
        } else if (address(params.swapSourceToken) != address(0)) {
            (uint256 spent0, uint256 received0) =
                _swap(params.swapSourceToken, token0, params.amountIn0, params.amountOut0Min, params.swapData0);
            (uint256 spent1, uint256 received1) =
                _swap(params.swapSourceToken, token1, params.amountIn1, params.amountOut1Min, params.swapData1);
            total0 = params.amount0 + received0;
            total1 = params.amount1 + received1;
            uint256 leftover = params.amountIn0 + params.amountIn1 - spent0 - spent1;
            if (leftover != 0) {
                _transferToken(params.recipient, params.swapSourceToken, leftover, params.unwrap);
            }
        } else {
            total0 = params.amount0;
            total1 = params.amount1;
        }
    }

    function _prepareAdd(
        IERC20 token0,
        IERC20 token1,
        IERC20 otherToken,
        uint256 amount0,
        uint256 amount1,
        uint256 amountOther
    ) internal {
        uint256 supplied0;
        uint256 supplied1;
        uint256 suppliedOther;

        if (msg.value != 0) {
            weth.deposit{value: msg.value}();
            if (address(token0) == address(weth)) {
                supplied0 = msg.value;
                if (supplied0 > amount0) revert TooMuchEtherSent();
            } else if (address(token1) == address(weth)) {
                supplied1 = msg.value;
                if (supplied1 > amount1) revert TooMuchEtherSent();
            } else if (address(otherToken) == address(weth)) {
                suppliedOther = msg.value;
                if (suppliedOther > amountOther) revert TooMuchEtherSent();
            } else {
                revert TooMuchEtherSent();
            }
        }

        if (amount0 > supplied0) _pullExact(token0, amount0 - supplied0);
        if (amount1 > supplied1) _pullExact(token1, amount1 - supplied1);
        if (
            amountOther > suppliedOther && address(otherToken) != address(0) && address(otherToken) != address(token0)
                && address(otherToken) != address(token1)
        ) {
            _pullExact(otherToken, amountOther - suppliedOther);
        }
    }

    function _pullExact(IERC20 token, uint256 amount) internal {
        if (amount == 0) return;
        uint256 beforeBalance = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), amount);
        if (token.balanceOf(address(this)) - beforeBalance != amount) revert TransferError();
    }

    function _withdraw(uint256 tokenId, PositionSpec memory position, uint128 liquidity, bool withFees)
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        (IERC20 token0, IERC20 token1) = _normalizedTokens(position.poolKey);
        uint256 balance0Before = token0.balanceOf(address(this));
        uint256 balance1Before = token1.balanceOf(address(this));
        uint256 nativeBalanceBefore = address(this).balance;

        (uint128 withdrawn0, uint128 withdrawn1) = positions.withdraw(
            tokenId, position.poolKey, position.tickLower, position.tickUpper, liquidity, address(this), withFees
        );
        uint256 expectedNative = position.poolKey.token0 == address(0) ? withdrawn0 : 0;
        if (position.poolKey.token1 == address(0)) expectedNative += withdrawn1;
        _wrapNativeAmountAbove(nativeBalanceBefore, expectedNative);
        amount0 = withdrawn0;
        amount1 = withdrawn1;

        if (token0.balanceOf(address(this)) - balance0Before != amount0) revert TransferError();
        if (token1.balanceOf(address(this)) - balance1Before != amount1) revert TransferError();
    }

    function _deposit(
        uint256 tokenId,
        PositionSpec memory position,
        uint256 maxAmount0,
        uint256 maxAmount1,
        uint128 minLiquidity
    ) internal returns (uint128 liquidity, uint128 amount0, uint128 amount1) {
        (uint128 amount0Max, uint128 amount1Max) = _toUint128Pair(maxAmount0, maxAmount1);
        uint256 nativeBalanceBefore = address(this).balance;
        uint256 nativeAmount = _approveAndUnwrap(position.poolKey, maxAmount0, maxAmount1);

        if (nativeAmount == 0) {
            (liquidity, amount0, amount1) = positions.deposit(
                tokenId, position.poolKey, position.tickLower, position.tickUpper, amount0Max, amount1Max, minLiquidity
            );
        } else {
            bytes[] memory calls = new bytes[](2);
            calls[0] = abi.encodeCall(
                IEkuboPositions.deposit,
                (
                    tokenId,
                    position.poolKey,
                    position.tickLower,
                    position.tickUpper,
                    amount0Max,
                    amount1Max,
                    minLiquidity
                )
            );
            calls[1] = abi.encodeCall(IEkuboPositions.refundNativeToken, ());
            bytes[] memory results = positions.multicall{value: nativeAmount}(calls);
            (liquidity, amount0, amount1) = abi.decode(results[0], (uint128, uint128, uint128));
            uint256 nativeUsed = position.poolKey.token0 == address(0) ? amount0 : amount1;
            _wrapNativeAmountAbove(nativeBalanceBefore, nativeAmount - nativeUsed);
        }

        _resetPositionsApprovals(position.poolKey);
    }

    function _mintAndDeposit(PositionSpec memory position, uint256 maxAmount0, uint256 maxAmount1, uint128 minLiquidity)
        internal
        returns (uint256 tokenId, uint128 liquidity, uint128 amount0, uint128 amount1)
    {
        (uint128 amount0Max, uint128 amount1Max) = _toUint128Pair(maxAmount0, maxAmount1);
        uint256 nativeBalanceBefore = address(this).balance;
        uint256 nativeAmount = _approveAndUnwrap(position.poolKey, maxAmount0, maxAmount1);

        if (nativeAmount == 0) {
            (tokenId, liquidity, amount0, amount1) = positions.mintAndDeposit(
                position.poolKey, position.tickLower, position.tickUpper, amount0Max, amount1Max, minLiquidity
            );
        } else {
            bytes[] memory calls = new bytes[](2);
            calls[0] = abi.encodeCall(
                IEkuboPositions.mintAndDeposit,
                (position.poolKey, position.tickLower, position.tickUpper, amount0Max, amount1Max, minLiquidity)
            );
            calls[1] = abi.encodeCall(IEkuboPositions.refundNativeToken, ());
            bytes[] memory results = positions.multicall{value: nativeAmount}(calls);
            (tokenId, liquidity, amount0, amount1) = abi.decode(results[0], (uint256, uint128, uint128, uint128));
            uint256 nativeUsed = position.poolKey.token0 == address(0) ? amount0 : amount1;
            _wrapNativeAmountAbove(nativeBalanceBefore, nativeAmount - nativeUsed);
        }

        _resetPositionsApprovals(position.poolKey);
    }

    function _approveAndUnwrap(EkuboPoolKey memory poolKey, uint256 maxAmount0, uint256 maxAmount1)
        internal
        returns (uint256 nativeAmount)
    {
        if (poolKey.token0 == address(0)) {
            nativeAmount = maxAmount0;
        } else if (maxAmount0 != 0) {
            IERC20(poolKey.token0).safeApprove(address(positions), 0);
            IERC20(poolKey.token0).safeApprove(address(positions), maxAmount0);
        }

        if (poolKey.token1 == address(0)) {
            nativeAmount += maxAmount1;
        } else if (maxAmount1 != 0) {
            IERC20(poolKey.token1).safeApprove(address(positions), 0);
            IERC20(poolKey.token1).safeApprove(address(positions), maxAmount1);
        }

        if (nativeAmount != 0) weth.withdraw(nativeAmount);
    }

    function _resetPositionsApprovals(EkuboPoolKey memory poolKey) internal {
        if (poolKey.token0 != address(0)) IERC20(poolKey.token0).safeApprove(address(positions), 0);
        if (poolKey.token1 != address(0)) IERC20(poolKey.token1).safeApprove(address(positions), 0);
    }

    function _swap(IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn, uint256 amountOutMin, bytes memory swapData)
        internal
        returns (uint256 amountInDelta, uint256 amountOutDelta)
    {
        if (amountIn == 0) {
            if (amountOutMin != 0) revert SlippageError();
            return (0, 0);
        }
        if (swapData.length == 0) revert MissingSwapData();
        if (address(tokenIn) == address(tokenOut)) revert SameToken();

        uint256 balanceInBefore = tokenIn.balanceOf(address(this));
        uint256 balanceOutBefore = tokenOut.balanceOf(address(this));
        (address allowanceTarget, bytes memory data) = abi.decode(swapData, (address, bytes));
        tokenIn.safeApprove(allowanceTarget, 0);
        tokenIn.safeApprove(allowanceTarget, amountIn);

        (bool success,) = swapRouter.call(data);
        if (!success) revert SwapFailed();
        tokenIn.safeApprove(allowanceTarget, 0);

        amountInDelta = balanceInBefore - tokenIn.balanceOf(address(this));
        amountOutDelta = tokenOut.balanceOf(address(this)) - balanceOutBefore;
        if (amountInDelta > amountIn || amountOutDelta < amountOutMin) revert SlippageError();
        emit Swap(address(tokenIn), address(tokenOut), amountInDelta, amountOutDelta);
    }

    function _returnLeftovers(
        address recipient,
        EkuboPoolKey memory poolKey,
        uint256 total0,
        uint256 total1,
        uint256 added0,
        uint256 added1,
        bool unwrap
    ) internal {
        (IERC20 token0, IERC20 token1) = _normalizedTokens(poolKey);
        if (total0 > added0) _transferToken(recipient, token0, total0 - added0, unwrap);
        if (total1 > added1) _transferToken(recipient, token1, total1 - added1, unwrap);
    }

    function _transferToken(address recipient, IERC20 token, uint256 amount, bool unwrap) internal {
        if (address(token) == address(weth) && unwrap) {
            weth.withdraw(amount);
            (bool sent,) = recipient.call{value: amount}("");
            if (!sent) revert EtherSendFailed();
        } else {
            token.safeTransfer(recipient, amount);
        }
    }

    function _normalizedTokens(EkuboPoolKey memory poolKey) internal view returns (IERC20 token0, IERC20 token1) {
        token0 = IERC20(poolKey.token0 == address(0) ? address(weth) : poolKey.token0);
        token1 = IERC20(poolKey.token1 == address(0) ? address(weth) : poolKey.token1);
        if (address(token0) == address(token1)) revert NativeWrappedPairNotSupported();
    }

    function _validatePosition(PositionSpec memory position) internal view {
        EkuboPoolKey memory poolKey = position.poolKey;
        if (poolKey.token0 >= poolKey.token1) revert InvalidPool();

        uint256 config = uint256(poolKey.config);
        if (config >> 96 != 0) revert ExtensionsNotSupported();
        if ((config & 0x80000000) == 0) revert StableswapNotSupported();
        uint256 tickSpacing = config & 0x7fffffff;
        // Safe because the config mask limits tickSpacing to 31 bits.
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 signedTickSpacing = int256(tickSpacing);
        if (
            tickSpacing == 0 || position.tickLower >= position.tickUpper
                || int256(position.tickLower) % signedTickSpacing != 0
                || int256(position.tickUpper) % signedTickSpacing != 0
        ) revert InvalidTicks();
        _normalizedTokens(poolKey);
    }

    function _requireSamePair(EkuboPoolKey memory a, EkuboPoolKey memory b) internal pure {
        if (a.token0 != b.token0 || a.token1 != b.token1) revert InvalidPool();
    }

    function _checkDeadline(uint256 deadline) internal view {
        // A bounded timestamp is the intended transaction-expiry mechanism.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp > deadline) revert DeadlineExpired();
    }

    function _validateRecipient(address recipient) internal view {
        if (recipient == address(0) || recipient == address(this)) revert InvalidRecipient();
    }

    function _toUint128Pair(uint256 amount0, uint256 amount1) internal pure returns (uint128, uint128) {
        if (amount0 > type(uint128).max || amount1 > type(uint128).max) revert AmountOverflow();
        // Both casts are bounded by the check above.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint128 amount0Cast = uint128(amount0);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint128 amount1Cast = uint128(amount1);
        return (amount0Cast, amount1Cast);
    }

    function _wrapNativeAmountAbove(uint256 baseline, uint256 expectedAmount) internal {
        uint256 balance = address(this).balance;
        if (balance < baseline || balance - baseline != expectedAmount) revert TransferError();
        if (expectedAmount != 0) weth.deposit{value: expectedAmount}();
    }

    receive() external payable {
        if (msg.sender != address(weth) && msg.sender != address(positions) && msg.sender != core) {
            revert InvalidEtherSender();
        }
    }
}
