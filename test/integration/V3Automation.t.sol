// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import "../IntegrationTestBase.sol";

contract V3AutomationIntegrationTest is IntegrationTestBase {
    Signature.Order emptyUserConfig; // todo: remove this when we fill user configuration

    function setUp() external {
        _setupBase();
    }

    function testAutoAdjustRange() external {
        // add liquidity to existing (empty) position (add 1 DAI / 0 USDC)
        _increaseLiquidity();
        (address userAddress, uint256 privateKey) = makeAddrAndKey("positionOwnerAddress");

        vm.startPrank(TEST_NFT_ACCOUNT);
        NPM.safeTransferFrom(TEST_NFT_ACCOUNT, userAddress, TEST_NFT);
        vm.stopPrank();

        bytes memory signature = _signOrder(emptyUserConfig, privateKey);

        uint256 countBefore = NPM.balanceOf(userAddress);

        (, , , , , , , uint128 liquidityBefore, , , , ) = NPM.positions(
            TEST_NFT
        );

        V3Automation.ExecuteParams memory params = V3Automation.ExecuteParams(
            V3Automation.Action.AUTO_ADJUST,
            Common.Protocol.UNI_V3,
            NPM,
            userAddress,
            TEST_NFT,
            liquidityBefore,
            address(USDC),
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
            MIN_TICK_500,
            -MIN_TICK_500,
            true,
            0,
            0,
            emptyUserConfig,
            signature
        );

        // using approve / execute pattern
        vm.prank(userAddress);
        NPM.setApprovalForAll(address(v3automation), true);

        vm.prank(TEST_OWNER_ACCOUNT);

        v3automation.execute(params);

        // now we have 2 NFTs (1 empty)
        uint256 countAfter = NPM.balanceOf(userAddress);
        assertGt(countAfter, countBefore);

        (, , , , , , , uint128 liquidityAfter, , , , ) = NPM.positions(
            TEST_NFT
        );
        assertEq(liquidityAfter, 0);
    }

    function testAutoAdjustRangeNotOperator() external {
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
            true,
            0,
            0,
            emptyUserConfig,
            ""
        );

        // using approve / execute pattern
        vm.prank(TEST_NFT_ACCOUNT);
        NPM.setApprovalForAll(address(v3automation), true);

        vm.prank(TEST_NFT_ACCOUNT); // this is not a operator

        vm.expectRevert();
        v3automation.execute(params);
    }

    function testAutoAdjustWithInvalidNfpm() external {
        INonfungiblePositionManager invalidNfpm = INonfungiblePositionManager(0xC36442b4A4522E871399cD717aBDD847Ab11FE99);

        V3Automation.ExecuteParams memory params = V3Automation.ExecuteParams(
            V3Automation.Action.AUTO_ADJUST,
            Common.Protocol.UNI_V3,
            invalidNfpm,
            TEST_NFT_ACCOUNT,
            TEST_NFT,
            0,
            address(0),
            500000000000000000,
            400000,
            "",
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
            true,
            0,
            0,
            emptyUserConfig,
            ""
        );
        vm.prank(TEST_OWNER_ACCOUNT);

        vm.expectRevert();
        v3automation.execute(params);
    }

    event CancelOrder(address user, Signature.Order order, bytes signature);

    function testCancelOrder() external {
        (address userAddress, uint256 privateKey) = makeAddrAndKey("cancelOrderUser");
        bytes memory signature = _signOrder(emptyUserConfig, privateKey);

        vm.prank(userAddress);
        vm.expectEmit(false, false, false, true, address(v3automation));
        emit CancelOrder(userAddress, emptyUserConfig, signature);
        v3automation.cancelOrder(emptyUserConfig, signature);

        bool cancelled = v3automation.isOrderCancelled(signature);
        assertTrue(cancelled);
    }

    function testAutoExit() external {
        _increaseLiquidity();

        (address userAddress, uint256 privateKey) = makeAddrAndKey("positionOwnerAddress");
        vm.startPrank(TEST_NFT_ACCOUNT);
        NPM.safeTransferFrom(TEST_NFT_ACCOUNT, userAddress, TEST_NFT);
        vm.stopPrank();

        bytes memory signature = _signOrder(emptyUserConfig, privateKey);

        (, , , , , , , uint128 liquidityBefore, , , , ) = NPM.positions(
            TEST_NFT
        );

        uint256 minDestAmount = 400000;

        V3Automation.ExecuteParams memory params = V3Automation.ExecuteParams(
            V3Automation.Action.AUTO_EXIT,
            Common.Protocol.UNI_V3,
            NPM,
            userAddress,
            TEST_NFT,
            liquidityBefore,
            address(USDC),
            500000000000000000,
            minDestAmount,
            _get05DAIToUSDCSwapData(),
            0,
            0,
            "",
            0,
            0,
            block.timestamp,
            184467440737095520, // 0.01 * 2^64
            0,
            0,
            0,
            true,
            0,
            0,
            emptyUserConfig,
            signature
        );

        // using approve / execute pattern
        vm.prank(userAddress);
        NPM.setApprovalForAll(address(v3automation), true);

        uint256 balanceUSDCBefore = USDC.balanceOf(userAddress);

        vm.prank(TEST_OWNER_ACCOUNT);

        // Execute auto exit
        v3automation.execute(params);

        (, , , , , , , uint128 liquidityAfter, , , , ) = NPM.positions(
            TEST_NFT
        );

        uint256 balanceUSDCAfter = USDC.balanceOf(userAddress);
        assertEq(liquidityAfter, 0);
        assertGt(balanceUSDCAfter, balanceUSDCBefore + minDestAmount);
    }

    function testAutoCompound() external {
        _increaseLiquidity();

        (address userAddress, uint256 privateKey) = makeAddrAndKey("positionOwnerAddress");
        vm.startPrank(TEST_NFT_ACCOUNT);
        NPM.safeTransferFrom(TEST_NFT_ACCOUNT, userAddress, TEST_NFT);
        vm.stopPrank();

        bytes memory signature = _signOrder(emptyUserConfig, privateKey);
        (, , , , , , , uint128 liquidityBefore, , , , ) = NPM.positions(
            TEST_NFT
        );

        
        V3Automation.ExecuteParams memory params = V3Automation.ExecuteParams(
            V3Automation.Action.AUTO_COMPOUND,
            Common.Protocol.UNI_V3,
            NPM,
            userAddress,
            TEST_NFT,
            liquidityBefore,
            address(0),
            0,
            0,
            "",
            0,
            0,
            "",
            0,
            0,
            block.timestamp,
            0, // gas fee
            0, // protocol fee
            0,
            0,
            false,
            0,
            0,
            emptyUserConfig,
            signature
        );

        // using approve / execute pattern
        vm.prank(userAddress);
        NPM.setApprovalForAll(address(v3automation), true);

        vm.prank(TEST_OWNER_ACCOUNT);

        // Execute auto exit
        v3automation.execute(params);
    }

    function _signOrder(Signature.Order memory order, uint256 privateKey) internal view returns (bytes memory signature) {
        bytes32 digest = v3automation.hashTypedDataV4(v3automation.hash(order));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        signature = abi.encodePacked(r, s, v);
    }
}
