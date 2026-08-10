// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @notice The three fields Ekubo hashes to identify a pool.
struct EkuboPoolKey {
    address token0;
    address token1;
    bytes32 config;
}
/// @notice ABI used by EkuboUtils for Ekubo's canonical Positions contract.
/// @dev Kept local so the utility does not depend on Ekubo's source-available license.
interface IEkuboPositions is IERC721 {
    function getPositionFeesAndLiquidity(uint256 id, EkuboPoolKey memory poolKey, int32 tickLower, int32 tickUpper)
        external
        view
        returns (uint128 liquidity, uint128 principal0, uint128 principal1, uint128 fees0, uint128 fees1);

    function deposit(
        uint256 id,
        EkuboPoolKey memory poolKey,
        int32 tickLower,
        int32 tickUpper,
        uint128 maxAmount0,
        uint128 maxAmount1,
        uint128 minLiquidity
    ) external payable returns (uint128 liquidity, uint128 amount0, uint128 amount1);

    function withdraw(
        uint256 id,
        EkuboPoolKey memory poolKey,
        int32 tickLower,
        int32 tickUpper,
        uint128 liquidity,
        address recipient,
        bool withFees
    ) external payable returns (uint128 amount0, uint128 amount1);

    function mintAndDeposit(
        EkuboPoolKey memory poolKey,
        int32 tickLower,
        int32 tickUpper,
        uint128 maxAmount0,
        uint128 maxAmount1,
        uint128 minLiquidity
    ) external payable returns (uint256 id, uint128 liquidity, uint128 amount0, uint128 amount1);

    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);

    function refundNativeToken() external payable;
}
