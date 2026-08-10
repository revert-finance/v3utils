// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {EkuboUtils, IWETH9} from "../../src/EkuboUtils.sol";
import {EkuboPoolKey, IEkuboPositions} from "../../src/interfaces/IEkuboPositions.sol";

contract EkuboUtilsIntegrationTest is Test {
    IEkuboPositions internal constant POSITIONS = IEkuboPositions(0x02D9876A21AF7545f8632C3af76eC90b5ad4b66D);
    address internal constant CORE = 0x00000000000014aA86C5d3c41765bb24e11bd701;
    IWETH9 internal constant WETH = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address internal constant ZERO_EX_ROUTER = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;

    uint256 internal constant POSITION_ID =
        115405844744126724027399150793600264461049412098266383761154101033925042376216;
    address internal constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    uint64 internal constant FEE = 737869762948382;
    uint256 internal constant FORK_BLOCK = 25_726_242;

    function testForkMovesCanonicalExtensionFreePositionToReplacementNft() external {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), FORK_BLOCK);
        EkuboUtils utils = new EkuboUtils(POSITIONS, CORE, WETH, ZERO_EX_ROUTER);
        uint256 forcedEtherBalance = address(utils).balance;
        EkuboUtils.PositionSpec memory position = EkuboUtils.PositionSpec({
            poolKey: EkuboPoolKey(WBTC, CBBTC, bytes32((uint256(FEE) << 32) | uint256(uint32(0x80000096)))),
            tickLower: 0,
            tickUpper: 450
        });

        address owner = POSITIONS.ownerOf(POSITION_ID);
        (uint128 liquidity,,,,) =
            POSITIONS.getPositionFeesAndLiquidity(POSITION_ID, position.poolKey, position.tickLower, position.tickUpper);
        assertGt(liquidity, 0);
        uint256 nftBalanceBefore = POSITIONS.balanceOf(owner);

        EkuboUtils.Instructions memory instructions;
        instructions.whatToDo = EkuboUtils.WhatToDo.CHANGE_RANGE;
        instructions.position = position;
        instructions.newPosition = position;
        instructions.collectFees = true;
        instructions.liquidity = liquidity;
        instructions.deadline = block.timestamp;
        instructions.recipient = owner;
        instructions.recipientNFT = owner;

        vm.prank(owner);
        POSITIONS.approve(address(utils), POSITION_ID);
        vm.prank(owner);
        utils.execute(POSITION_ID, instructions);

        (uint128 oldLiquidity,,,,) =
            POSITIONS.getPositionFeesAndLiquidity(POSITION_ID, position.poolKey, position.tickLower, position.tickUpper);
        assertEq(oldLiquidity, 0);
        assertEq(POSITIONS.ownerOf(POSITION_ID), owner);
        assertEq(POSITIONS.balanceOf(owner), nftBalanceBefore + 1);
        assertEq(address(utils).balance, forcedEtherBalance);
        assertEq(WETH.balanceOf(address(utils)), 0);
    }
}
