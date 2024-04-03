// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../IntegrationTestBase.sol";

contract V3AutomationIntegrationTest is IntegrationTestBase {
   
    function setUp() external {
        _setupBase();
    }

    function testAutoAdjustRange() external {
        // add liquidity to existing (empty) position (add 1 DAI / 0 USDC)
        _increaseLiquidity();

        uint256 countBefore = NPM.balanceOf(TEST_NFT_ACCOUNT);

        (, , , , , , , uint128 liquidityBefore, , , , ) = NPM.positions(
            TEST_NFT
        );

        V3Automation.ExecuteParams memory params = V3Automation.ExecuteParams(
            V3Automation.Action.AUTO_ADJUST,
            Common.Protocol.UNI_V3,
            NPM,
            TEST_NFT_ACCOUNT,
            TEST_NFT,
            liquidityBefore,
            address(0),
            500000000000000000,
            400000,
            _get05DAIToUSDCSwapData(),
            0,
            0,
            "",
            0,
            0,
            block.timestamp,
            184467440737095520, // 0.01 * 2^64
            0,
            MIN_TICK_100,
            -MIN_TICK_100,
            0,
            0
        );

        // using approve / execute pattern
        vm.prank(TEST_NFT_ACCOUNT);
        NPM.setApprovalForAll(address(v3automation), true);

        vm.prank(TEST_OWNER_ACCOUNT);
        v3automation.execute(params);

        // now we have 2 NFTs (1 empty)
        uint256 countAfter = NPM.balanceOf(TEST_NFT_ACCOUNT);
        assertGt(countAfter, countBefore);

        (, , , , , , , uint128 liquidityAfter, , , , ) = NPM.positions(
            TEST_NFT
        );
        assertEq(liquidityAfter, 0);
    }

    function testAutoAdjustRange_NotOperator() external {
        // add liquidity to existing (empty) position (add 1 DAI / 0 USDC)
        _increaseLiquidity();

        (, , , , , , , uint128 liquidityBefore, , , , ) = NPM.positions(
            TEST_NFT
        );

        V3Automation.ExecuteParams memory params = V3Automation.ExecuteParams(
            V3Automation.Action.AUTO_ADJUST,
            Common.Protocol.UNI_V3,
            NPM,
            TEST_NFT_ACCOUNT,
            TEST_NFT,
            liquidityBefore,
            address(0),
            500000000000000000,
            400000,
            _get05DAIToUSDCSwapData(),
            0,
            0,
            "",
            0,
            0,
            block.timestamp,
            184467440737095520, // 0.01 * 2^64
            0,
            MIN_TICK_100,
            -MIN_TICK_100,
            0,
            0
        );

        // using approve / execute pattern
        vm.prank(TEST_NFT_ACCOUNT);
        NPM.setApprovalForAll(address(v3automation), true);

        vm.prank(TEST_NFT_ACCOUNT); // this is not a operator

        vm.expectRevert();
        v3automation.execute(params);
    }
}
