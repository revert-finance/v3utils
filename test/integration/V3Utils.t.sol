// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../IntegrationTestBase.sol";
import "../../src/Pausable.sol";

contract V3UtilsIntegrationTest is IntegrationTestBase {

    function setUp() external {
        _setupBase();
    }

    function testUnauthorizedTransfer() external {
        vm.expectRevert(
            abi.encodePacked(
                "ERC721: transfer caller is not owner nor approved"
            )
        );
        V3Utils.Instructions memory inst = V3Utils.Instructions(
            V3Utils.WhatToDo.CHANGE_RANGE,
            Common.Protocol.UNI_V3,
            address(0),
            0,
            0,
            0,
            0,
            "",
            0,
            0,
            "",
            0,
            0,
            true,
            0,
            0,
            0,
            0,
            TEST_NFT_ACCOUNT,
            false,
            0
        );
        NPM.safeTransferFrom(
            TEST_NFT_ACCOUNT,
            address(v3utils),
            TEST_NFT,
            abi.encode(inst)
        );
    }

    function testInvalidInstructions() external {
        // reverts with ERC721Receiver error if Instructions are invalid
        vm.expectRevert(
            abi.encodePacked(
                "ERC721: transfer to non ERC721Receiver implementer"
            )
        );
        vm.prank(TEST_NFT_ACCOUNT);
        NPM.safeTransferFrom(
            TEST_NFT_ACCOUNT,
            address(v3utils),
            TEST_NFT,
            abi.encode(true, false, 1, "test")
        );
    }

    function testSendEtherNotAllowed() external {
        bool success;
        vm.expectRevert(Common.NotWETH.selector);
        (success,) = address(v3utils).call{value: 123}("");
    }

    function testTransferDecreaseSlippageError() external {
        // add liquidity to existing (empty) position (add 1 DAI / 0 USDC)
        _increaseLiquidity();

        (, , , , , , , uint128 liquidityBefore, , , , ) = NPM.positions(
            TEST_NFT
        );

        // swap a bit more dai than available - fails with slippage error because not enough liquidity + fees is collected
        V3Utils.Instructions memory inst = V3Utils.Instructions(
            V3Utils.WhatToDo.CHANGE_RANGE,
            Common.Protocol.UNI_V3,
            address(USDC),
            1000000000000000001,
            400000,
            1000000000000000001,
            400000,
            _get05DAIToUSDCSwapData(),
            0,
            0,
            "",
            MIN_TICK_100,
            -MIN_TICK_100,
            true,
            liquidityBefore, // take all liquidity
            0,
            0,
            block.timestamp,
            TEST_NFT_ACCOUNT,
            false,
            0
        );

        vm.prank(TEST_NFT_ACCOUNT);
        vm.expectRevert("Price slippage check");
        NPM.safeTransferFrom(
            TEST_NFT_ACCOUNT,
            address(v3utils),
            TEST_NFT,
            abi.encode(inst)
        );
    }

    function testTransferAmountError() external {
        // add liquidity to existing (empty) position (add 1 DAI / 0 USDC)
        _increaseLiquidity();

        (, , , , , , , uint128 liquidityBefore, , , , ) = NPM.positions(
            TEST_NFT
        );

        // swap a bit more dai than available - fails with slippage error because not enough liquidity + fees is collected
        V3Utils.Instructions memory inst = V3Utils.Instructions(
            V3Utils.WhatToDo.CHANGE_RANGE,
            Common.Protocol.UNI_V3,
            address(USDC),
            0,
            0,
            1000000000000000001,
            400000,
            _get05DAIToUSDCSwapData(),
            0,
            0,
            "",
            MIN_TICK_100,
            -MIN_TICK_100,
            true,
            liquidityBefore, // take all liquidity
            0,
            0,
            block.timestamp,
            TEST_NFT_ACCOUNT,
            false,
            0
        );

        vm.prank(TEST_NFT_ACCOUNT);
        vm.expectRevert(Common.AmountError.selector);

        NPM.safeTransferFrom(
            TEST_NFT_ACCOUNT,
            address(v3utils),
            TEST_NFT,
            abi.encode(inst)
        );
    }

    function testTransferWithChangeRange() external {
        // add liquidity to existing (empty) position (add 1 DAI / 0 USDC)
        _increaseLiquidity();

        uint256 countBefore = NPM.balanceOf(TEST_NFT_ACCOUNT);

        (, , , , , , , uint128 liquidityBefore, , , , ) = NPM.positions(
            TEST_NFT
        );

        // swap half of DAI to USDC and add full range
        V3Utils.Instructions memory inst = V3Utils.Instructions(
            V3Utils.WhatToDo.CHANGE_RANGE,
            Common.Protocol.UNI_V3,
            address(USDC),
            0,
            0,
            500000000000000000,
            400000,
            _get05DAIToUSDCSwapData(),
            0,
            0,
            "",
            MIN_TICK_500,
            -MIN_TICK_500,
            true,
            liquidityBefore, // take all liquidity
            0,
            0,
            block.timestamp,
            TEST_NFT_ACCOUNT,
            false,
            0
        );

        // using approve / execute pattern
        vm.prank(TEST_NFT_ACCOUNT);
        NPM.approve(address(v3utils), TEST_NFT);

        vm.prank(TEST_NFT_ACCOUNT);
        v3utils.execute(NPM, TEST_NFT, inst);

        // now we have 2 NFTs (1 empty)
        uint256 countAfter = NPM.balanceOf(TEST_NFT_ACCOUNT);
        assertGt(countAfter, countBefore);

        (, , , , , , , uint128 liquidityAfter, , , , ) = NPM.positions(
            TEST_NFT
        );
        assertEq(liquidityAfter, 0);
    }

    function testTransferWithCompoundNoSwap() external {
        V3Utils.Instructions memory inst = V3Utils.Instructions(
            V3Utils.WhatToDo.COMPOUND_FEES,
            Common.Protocol.UNI_V3,
            address(0),
            0,
            0,
            0,
            0,
            "",
            0,
            0,
            "",
            0,
            0,
            true,
            0,
            0,
            0,
            block.timestamp,
            TEST_NFT_3_ACCOUNT,
            false,
            0
        );

        uint256 daiBefore = DAI.balanceOf(TEST_NFT_3_ACCOUNT);
        uint256 usdcBefore = USDC.balanceOf(TEST_NFT_3_ACCOUNT);
        (, , , , , , , uint128 liquidityBefore, , , , ) = NPM.positions(
            TEST_NFT_3
        );

        assertEq(daiBefore, 0);
        assertEq(usdcBefore, 0);
        assertEq(liquidityBefore, 4700646086778448669);

        vm.prank(TEST_NFT_3_ACCOUNT);
        NPM.safeTransferFrom(
            TEST_NFT_3_ACCOUNT,
            address(v3utils),
            TEST_NFT_3,
            abi.encode(inst)
        );

        uint256 daiAfter = DAI.balanceOf(TEST_NFT_3_ACCOUNT);
        uint256 usdcAfter = USDC.balanceOf(TEST_NFT_3_ACCOUNT);
        (, , , , , , , uint128 liquidityAfter, , , , ) = NPM.positions(
            TEST_NFT_3
        );

        assertEq(daiAfter, 155);
        assertEq(usdcAfter, 278462);
        assertEq(liquidityAfter, 4708207787955793582);
    }

    function testTransferWithCompoundSwap() external {
        _writeTokenBalance(TEST_NFT_ACCOUNT, address(DAI), 500000000000000000);


        V3Utils.Instructions memory inst = V3Utils.Instructions(
            V3Utils.WhatToDo.COMPOUND_FEES,
            Common.Protocol.UNI_V3,
            address(USDC),
            0,
            0,
            500000000000000000,
            400000,
            _get05DAIToUSDCSwapData(),
            0,
            0,
            "",
            0,
            0,
            true,
            0,
            0,
            0,
            block.timestamp,
            TEST_NFT_3_ACCOUNT,
            false,
            0
        );

        uint256 daiBefore = DAI.balanceOf(TEST_NFT_3_ACCOUNT);
        uint256 usdcBefore = USDC.balanceOf(TEST_NFT_3_ACCOUNT);
        (, , , , , , , uint128 liquidityBefore, , , , ) = NPM.positions(
            TEST_NFT_3
        );

        assertEq(daiBefore, 0);
        assertEq(usdcBefore, 0);
        assertEq(liquidityBefore, 4700646086778448669);

        vm.prank(TEST_NFT_3_ACCOUNT);
        NPM.safeTransferFrom(
            TEST_NFT_3_ACCOUNT,
            address(v3utils),
            TEST_NFT_3,
            abi.encode(inst)
        );

        uint256 daiAfter = DAI.balanceOf(TEST_NFT_3_ACCOUNT);
        uint256 usdcAfter = USDC.balanceOf(TEST_NFT_3_ACCOUNT);
        (, , , , , , , uint128 liquidityAfter, , , , ) = NPM.positions(
            TEST_NFT_3
        );

        assertEq(daiAfter, 438);
        assertEq(usdcAfter, 1269729);
        assertEq(liquidityAfter, 4707158096697198378);
    }

    function _testTransferWithWithdrawAndSwap() internal {
        // add liquidity to existing (empty) position (add 1 DAI / 0 USDC)
        uint128 liquidity = _increaseLiquidity();

        uint256 countBefore = NPM.balanceOf(TEST_NFT_ACCOUNT);

        // swap half of DAI to USDC and add full range
        V3Utils.Instructions memory inst = V3Utils.Instructions(
            V3Utils.WhatToDo.WITHDRAW_AND_COLLECT_AND_SWAP,
            Common.Protocol.UNI_V3,
            address(USDC),
            0,
            0,
            990099009900989844, // uniswap returns 1 less when getting liquidity - this must be traded
            900000,
            _get1DAIToUSDSwapData(),
            0,
            0,
            "",
            0,
            0,
            true,
            liquidity,
            0,
            0,
            block.timestamp,
            TEST_NFT_ACCOUNT,
            false,
            0
        );

        vm.prank(TEST_NFT_ACCOUNT);
        NPM.safeTransferFrom(
            TEST_NFT_ACCOUNT,
            address(v3utils),
            TEST_NFT,
            abi.encode(inst)
        );

        uint256 countAfter = NPM.balanceOf(TEST_NFT_ACCOUNT);

        assertEq(countAfter, countBefore); // nft returned
    }

    function _testTransferWithCollectAndSwap() internal {
        // add liquidity to existing (empty) position (add 1 DAI / 0 USDC)
        uint128 liquidity = _increaseLiquidity();

        // decrease liquidity without collect (simulate fee growth)
        vm.prank(TEST_NFT_ACCOUNT);
        (uint256 amount0, uint256 amount1) = NPM.decreaseLiquidity(
            univ3.INonfungiblePositionManager.DecreaseLiquidityParams(
                TEST_NFT,
                liquidity,
                0,
                0,
                block.timestamp
            )
        );

        // should be same amount as added
        assertEq(amount0, 1000000000000000000);
        assertEq(amount1, 0);

        uint256 countBefore = NPM.balanceOf(TEST_NFT_ACCOUNT);

        // swap half of DAI to USDC and add full range
        V3Utils.Instructions memory inst = V3Utils.Instructions(
            V3Utils.WhatToDo.WITHDRAW_AND_COLLECT_AND_SWAP,
            Common.Protocol.UNI_V3,
            address(USDC),
            0,
            0,
            990099009900989844, // uniswap returns 1 less when getting liquidity - this must be traded
            900000,
            _get1DAIToUSDSwapData(),
            0,
            0,
            "",
            0,
            0,
            true,
            0,
            0,
            0,
            block.timestamp,
            TEST_NFT_ACCOUNT,
            false,
            0
        );

        vm.prank(TEST_NFT_ACCOUNT);
        NPM.safeTransferFrom(
            TEST_NFT_ACCOUNT,
            address(v3utils),
            TEST_NFT,
            abi.encode(inst)
        );

        uint256 countAfter = NPM.balanceOf(TEST_NFT_ACCOUNT);

        assertEq(countAfter, countBefore); // nft returned
    }

    function testFailEmptySwapAndIncreaseLiquidity() external {
        V3Utils.SwapAndIncreaseLiquidityParams memory params = Common
            .SwapAndIncreaseLiquidityParams(
                Common.Protocol.UNI_V3,
                NPM,
                TEST_NFT,
                0,
                0,
                0,
                TEST_NFT_ACCOUNT,
                block.timestamp,
                IERC20(address(0)),
                0,
                0,
                "",
                0,
                0,
                "",
                0,
                0,
                0
            );

        vm.prank(TEST_NFT_ACCOUNT);
        v3utils.swapAndIncreaseLiquidity(params);
    }

    function testSwapAndIncreaseLiquidity() external {
        uint64 protocolFeeX64 = 18446744073709552; // 0.1%

        uint256 balanceUSDC = 1001001;
        _writeTokenBalance(TEST_NFT_ACCOUNT, address(USDC), balanceUSDC);
        V3Utils.SwapAndIncreaseLiquidityParams memory params = Common
            .SwapAndIncreaseLiquidityParams(
                Common.Protocol.UNI_V3,
                NPM,
                TEST_NFT,
                0,
                balanceUSDC,
                0,
                TEST_NFT_ACCOUNT,
                block.timestamp,
                USDC,
                1000000,
                900000000000000000,
                _get1USDCToDAISwapData(),
                0,
                0,
                "",
                0,
                0,
                protocolFeeX64
            );

        vm.prank(TEST_NFT_ACCOUNT);
        USDC.approve(address(v3utils), balanceUSDC);
        uint256 feeBalanceBefore = USDC.balanceOf(TEST_FEE_ACCOUNT);

        vm.prank(TEST_NFT_ACCOUNT);
        Common.SwapAndIncreaseLiquidityResult memory result = v3utils.swapAndIncreaseLiquidity(params);

        uint256 feeBalance = USDC.balanceOf(TEST_FEE_ACCOUNT);

        assertEq(result.liquidity, 495285928421852);
        assertEq(result.added0, 989333334060081199);
        assertEq(1000000 / (feeBalance-feeBalanceBefore), 100);
        assertEq(result.added1, 0); // one sided adding
    }

    function testSwapAndIncreaseLiquidityBothSides() external {
        _writeTokenBalance(TEST_NFT_5_ACCOUNT, address(USDC), 3000000);
        // add liquidity to another positions which is not owned

        V3Utils.SwapAndIncreaseLiquidityParams memory params = Common
            .SwapAndIncreaseLiquidityParams(
                Common.Protocol.UNI_V3,
                NPM,
                TEST_NFT_5,
                0,
                2000000,
                0,
                TEST_NFT_5_ACCOUNT,
                block.timestamp,
                USDC,
                1000000,
                900000000000000000,
                _get1USDCToDAISwapData(),
                0,
                0,
                "",
                0,
                0,
                0
            );

        vm.prank(TEST_NFT_5_ACCOUNT);
        USDC.approve(address(v3utils), 3000000);

        uint256 usdcBefore = USDC.balanceOf(TEST_NFT_5_ACCOUNT);
        uint256 daiBefore = DAI.balanceOf(TEST_NFT_5_ACCOUNT);

        vm.prank(TEST_NFT_5_ACCOUNT);
        Common.SwapAndIncreaseLiquidityResult memory result = v3utils.swapAndIncreaseLiquidity(params);
        uint256 usdcAfter = USDC.balanceOf(TEST_NFT_5_ACCOUNT);
        uint256 daiAfter = DAI.balanceOf(TEST_NFT_5_ACCOUNT);

        // close to 1% of swapped amount
        uint256 feeBalance = USDC.balanceOf(TEST_FEE_ACCOUNT);
        assertEq(feeBalance, 3346001);

        assertEq(result.liquidity, 1610525505274001);
        assertEq(result.added0, 989333334060081225);
        assertEq(result.added1, 620657);

        // all usdc spent
        assertEq(usdcBefore - usdcAfter, 1000000+result.added1);
        //some dai returned - because not 100% correct swap ratio
        assertEq(daiAfter - daiBefore, 47);
    }

    function testSwapAndIncreaseLiquidityInvalidOwner() external {

        _writeTokenBalance(TEST_NFT_ACCOUNT, address(USDC), 3000000);
        // add liquidity to another positions which is not owned

        V3Utils.SwapAndIncreaseLiquidityParams memory params = Common
            .SwapAndIncreaseLiquidityParams(
                Common.Protocol.UNI_V3,
                NPM,
                TEST_NFT_5,
                0,
                2000000,
                0,
                TEST_NFT_ACCOUNT,
                block.timestamp,
                USDC,
                1000000,
                900000000000000000,
                _get1USDCToDAISwapData(),
                0,
                0,
                "",
                0,
                0,
                0
            );

        vm.prank(TEST_NFT_ACCOUNT);
        USDC.approve(address(v3utils), 3000000);

        vm.prank(TEST_NFT_ACCOUNT);
        vm.expectRevert(bytes("sender is not owner of position"));
        v3utils.swapAndIncreaseLiquidity(params);
    }

    function testFailEmptySwapAndMint() external {
        V3Utils.SwapAndMintParams memory params = Common.SwapAndMintParams(
            Common.Protocol.UNI_V3,
            NPM,
            DAI,
            USDC,
            500,
            MIN_TICK_500,
            -MIN_TICK_500,
            0,
            0,
            0,
            0,
            TEST_NFT_ACCOUNT,
            block.timestamp,
            IERC20(address(0)),
            0,
            0,
            "",
            0,
            0,
            "",
            0,
            0
        );

        vm.prank(TEST_NFT_ACCOUNT);
        v3utils.swapAndMint(params);
    }

    function testSwapAndMint() external {
        _testSwapAndMint(
            MIN_TICK_500,
            -MIN_TICK_500,
            989419165008,
            989333334059719092,
            989506
        );
    }

    function testSwapAndMintOneSided0() external {
        _testSwapAndMint(
            MIN_TICK_500,
            MIN_TICK_500 + 200000,
            837822485815257126640,
            0,
            1000000
        );
    }

    function testSwapAndMintOneSided1() external {
        _testSwapAndMint(
            -MIN_TICK_500 - 200000,
            -MIN_TICK_500,
            828885713242110370160956058744911,
            989333334060081272,
            0
        );
    }

    function _testSwapAndMint(
        int24 lower,
        int24 upper,
        uint256 eLiquidity,
        uint256 eAmount0,
        uint256 eAmount1
    ) internal {
        _writeTokenBalance(TEST_NFT_ACCOUNT, address(USDC), 3000000);

        uint256 feeBalanceBefore = USDC.balanceOf(TEST_FEE_ACCOUNT);

        V3Utils.SwapAndMintParams memory params = Common.SwapAndMintParams(
            Common.Protocol.UNI_V3,
            NPM,
            DAI,
            USDC,
            500,
            lower,
            upper,
            0,
            0,
            2000000,
            0,
            TEST_NFT_ACCOUNT,
            block.timestamp,
            USDC,
            1000000,
            900000000000000000,
            _get1USDCToDAISwapData(),
            0,
            0,
            "",
            0,
            0
        );

        vm.prank(TEST_NFT_ACCOUNT);
        USDC.approve(address(v3utils), 2000000);

        vm.prank(TEST_NFT_ACCOUNT);
        Common.SwapAndMintResult memory result = v3utils.swapAndMint(params);

        uint256 feeBalance = USDC.balanceOf(TEST_FEE_ACCOUNT);
        assertEq(feeBalance-feeBalanceBefore, 10000); // fee is 1%

        assertGt(result.tokenId, 0);
        assertEq(result.liquidity, eLiquidity);
        assertEq(result.added0, eAmount0);
        assertEq(result.added1, eAmount1);
    }

    function testSwapAndMintWithETH() public {
        uint64 protocolFeeX64 = 18446744073709552; // 0.1%
        uint256 feeBalanceBefore = WETH_ERC20.balanceOf(TEST_FEE_ACCOUNT);

        uint256 feeTakerBalanceBefore = WETH_ERC20.balanceOf(TEST_OWNER_ACCOUNT);

        V3Utils.SwapAndMintParams memory params = Common.SwapAndMintParams(
            Common.Protocol.UNI_V3,
            NPM,
            DAI,
            USDC,
            500,
            MIN_TICK_500,
            -MIN_TICK_500,
            protocolFeeX64,
            0,
            0,
            1.1 ether,
            TEST_NFT_ACCOUNT,
            block.timestamp,
            WETH_ERC20,
            500000000000000000, // 0.5ETH
            662616334956561731436,
            _get05ETHToDAISwapData(),
            500000000000000000, // 0.5ETH
            661794703,
            _get05ETHToUSDCSwapData(),
            0,
            0
        );

        hoax(TEST_NFT_ACCOUNT);
        Common.SwapAndMintResult memory result = v3utils.swapAndMint{value: 1.1 ether}(params);

        assertGt(result.tokenId, 0);
        assertEq(result.liquidity, 1249239075875054);
        assertEq(result.added0, 1249125286170506379296);
        assertEq(result.added1, 1249352876);

        uint256 feeBalance = WETH_ERC20.balanceOf(TEST_FEE_ACCOUNT);
        uint256 feeTakerBalanceAfter = WETH_ERC20.balanceOf(TEST_OWNER_ACCOUNT);
        assertEq(feeBalance-feeBalanceBefore, 10000000000000000);
        assertGt(feeTakerBalanceAfter, feeTakerBalanceBefore);
    }

    function testSwapAndIncreaseLiquidityAndCollectFees() external {
        uint64 protocolFeeX64 = 18446744073709552; // 0.1%

        

        uint256 feeTakerBalanceBefore = WETH_ERC20.balanceOf(TEST_OWNER_ACCOUNT);
        (, , , , , , , uint128 liquidityBefore, , , , ) = NPM.positions(
            TEST_NFT
        );

        _writeTokenBalance(TEST_NFT_ACCOUNT, address(WETH_ERC20), 1.5 ether);

        V3Utils.SwapAndIncreaseLiquidityParams memory params = Common.SwapAndIncreaseLiquidityParams(
            Common.Protocol.UNI_V3,
            NPM,
            TEST_NFT,
            0,
            0,
            1.5 ether,
            TEST_NFT_ACCOUNT,
            block.timestamp,
            WETH_ERC20,
            500000000000000000, // 0.5ETH
            662616334956561731436,
            _get05ETHToDAISwapData(),
            500000000000000000, // 0.5ETH
            661794703,
            _get05ETHToUSDCSwapData(),
            0,
            0,
            protocolFeeX64
        );

        vm.startPrank(TEST_NFT_ACCOUNT);

        WETH_ERC20.approve(address(v3utils), 1.5 ether);
        Common.SwapAndIncreaseLiquidityResult memory result = v3utils.swapAndIncreaseLiquidity(params);

        vm.stopPrank();

        uint256 feeTakerBalanceAfter = WETH_ERC20.balanceOf(TEST_OWNER_ACCOUNT);

        assertGt(result.liquidity, liquidityBefore);
        assertGt(feeTakerBalanceAfter, feeTakerBalanceBefore);
    }

    function testWithdrawAndSwapAndCollectProtocolFees() external {
        // add liquidity to existing (empty) position (add 1 DAI / 0 USDC)
        uint128 liquidity = _increaseLiquidity();

        uint256 countBefore = NPM.balanceOf(TEST_NFT_ACCOUNT);

        uint64 protocolFeeX64 = 18446744073709552; // 0.1%

        V3Utils.Instructions memory inst = V3Utils.Instructions(
            V3Utils.WhatToDo.WITHDRAW_AND_COLLECT_AND_SWAP,
            Common.Protocol.UNI_V3,
            address(USDC),
            0,
            0,
            990099009900989844, // uniswap returns 1 less when getting liquidity - this must be traded
            900000,
            _get1DAIToUSDSwapData(),
            0,
            0,
            "",
            0,
            0,
            true,
            liquidity,
            0,
            0,
            block.timestamp,
            TEST_NFT_ACCOUNT,
            false,
            protocolFeeX64
        );

        uint256 balanceDAIFeeTakerBefore = DAI.balanceOf(TEST_OWNER_ACCOUNT);

        vm.prank(TEST_NFT_ACCOUNT);
        NPM.safeTransferFrom(
            TEST_NFT_ACCOUNT,
            address(v3utils),
            TEST_NFT,
            abi.encode(inst)
        );
        vm.stopPrank();

        uint256 countAfter = NPM.balanceOf(TEST_NFT_ACCOUNT);

        uint256 balanceDAIFeeTakerAfter = DAI.balanceOf(TEST_OWNER_ACCOUNT);

        assertEq(countAfter, countBefore); // nft returned
        assertGt(balanceDAIFeeTakerAfter, balanceDAIFeeTakerBefore);
    }

    function testPauseContract() external {
        vm.prank(TEST_OWNER_ACCOUNT);
        v3utils.pause();

        vm.expectRevert(Pausable.EnforcedPause.selector);

        hoax(TEST_NFT_ACCOUNT, 1 ether);
        V3Utils.SwapAndMintParams memory params = Common.SwapAndMintParams(
            Common.Protocol.UNI_V3,
            NPM,
            DAI,
            USDC,
            500,
            MIN_TICK_500,
            -MIN_TICK_500,
            0,
            0,
            0,
            1 ether,
            TEST_NFT_ACCOUNT,
            block.timestamp,
            WETH_ERC20,
            500000000000000000, // 0.5ETH
            662616334956561731436,
            _get05ETHToDAISwapData(),
            500000000000000000, // 0.5ETH
            661794703,
            _get05ETHToUSDCSwapData(),
            0,
            0
        );
        v3utils.swapAndMint{value: 1 ether}(params);
    }
}
