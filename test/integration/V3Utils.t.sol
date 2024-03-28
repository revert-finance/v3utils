// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../IntegrationTestBase.sol";

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
            0,
            0,
            0,
            0,
            0,
            TEST_NFT_ACCOUNT,
            TEST_NFT_ACCOUNT,
            false,
            "",
            ""
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
            100, // change fee as well
            MIN_TICK_100,
            -MIN_TICK_100,
            liquidityBefore, // take all liquidity
            0,
            0,
            block.timestamp,
            TEST_NFT_ACCOUNT,
            TEST_NFT_ACCOUNT,
            false,
            "",
            ""
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
            100, // change fee as well
            MIN_TICK_100,
            -MIN_TICK_100,
            liquidityBefore, // take all liquidity
            0,
            0,
            block.timestamp,
            TEST_NFT_ACCOUNT,
            TEST_NFT_ACCOUNT,
            false,
            "",
            ""
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
            100, // change fee as well
            MIN_TICK_100,
            -MIN_TICK_100,
            liquidityBefore, // take all liquidity
            0,
            0,
            block.timestamp,
            TEST_NFT_ACCOUNT,
            TEST_NFT_ACCOUNT,
            false,
            "",
            ""
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
            0,
            0,
            0,
            0,
            block.timestamp,
            TEST_NFT_3_ACCOUNT,
            TEST_NFT_3_ACCOUNT,
            false,
            "",
            ""
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
            0,
            0,
            0,
            0,
            block.timestamp,
            TEST_NFT_3_ACCOUNT,
            TEST_NFT_3_ACCOUNT,
            false,
            "",
            ""
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
        (uint128 liquidity, , ) = _increaseLiquidity();

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
            0,
            liquidity,
            0,
            0,
            block.timestamp,
            TEST_NFT_ACCOUNT,
            TEST_NFT_ACCOUNT,
            false,
            "",
            ""
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
        (uint128 liquidity, , ) = _increaseLiquidity();

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
            0,
            0,
            0,
            0,
            block.timestamp,
            TEST_NFT_ACCOUNT,
            TEST_NFT_ACCOUNT,
            false,
            "",
            ""
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
        v3utils.swapAndIncreaseLiquidity(params);
    }

    function testSwapAndIncreaseLiquidity() external {
        _writeTokenBalance(TEST_NFT_ACCOUNT, address(USDC), 1000000);
        V3Utils.SwapAndIncreaseLiquidityParams memory params = Common
            .SwapAndIncreaseLiquidityParams(
                Common.Protocol.UNI_V3,
                NPM,
                TEST_NFT,
                0,
                1000000,
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
        USDC.approve(address(v3utils), 1000000);
        uint256 feeBalanceBefore = USDC.balanceOf(TEST_FEE_ACCOUNT);

        vm.prank(TEST_NFT_ACCOUNT);
        (uint128 liquidity, uint256 amount0, uint256 amount1) = v3utils.swapAndIncreaseLiquidity(params);

        uint256 feeBalance = USDC.balanceOf(TEST_FEE_ACCOUNT);

        assertEq(liquidity, 495285928421852);
        assertEq(amount0, 989333334060081199);
        assertEq(1000000 / (feeBalance-feeBalanceBefore), 100);
        assertEq(amount1, 0); // one sided adding
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
                0
            );

        vm.prank(TEST_NFT_5_ACCOUNT);
        USDC.approve(address(v3utils), 3000000);

        uint256 usdcBefore = USDC.balanceOf(TEST_NFT_5_ACCOUNT);
        uint256 daiBefore = DAI.balanceOf(TEST_NFT_5_ACCOUNT);

        vm.prank(TEST_NFT_5_ACCOUNT);
        (uint128 liquidity, uint256 amount0, uint256 amount1) = v3utils.swapAndIncreaseLiquidity(params);
        uint256 usdcAfter = USDC.balanceOf(TEST_NFT_5_ACCOUNT);
        uint256 daiAfter = DAI.balanceOf(TEST_NFT_5_ACCOUNT);

        // close to 1% of swapped amount
        uint256 feeBalance = USDC.balanceOf(TEST_FEE_ACCOUNT);
        assertEq(feeBalance, 3346001);

        assertEq(liquidity, 1610525505274001);
        assertEq(amount0, 989333334060081225);
        assertEq(amount1, 620657);

        // all usdc spent
        assertEq(usdcBefore - usdcAfter, 1000000+amount1);
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
            ""
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
            2000000,
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
            ""
        );

        vm.prank(TEST_NFT_ACCOUNT);
        USDC.approve(address(v3utils), 2000000);

        vm.prank(TEST_NFT_ACCOUNT);
        (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        ) = v3utils.swapAndMint(params);

        uint256 feeBalance = USDC.balanceOf(TEST_FEE_ACCOUNT);
        assertEq(feeBalance-feeBalanceBefore, 10000); // fee is 1%

        assertGt(tokenId, 0);
        assertEq(liquidity, eLiquidity);
        assertEq(amount0, eAmount0);
        assertEq(amount1, eAmount1);
    }

    function testSwapAndMintWithETH() public {
        uint256 feeBalanceBefore = WETH_ERC20.balanceOf(TEST_FEE_ACCOUNT);
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
            ""
        );

        hoax(TEST_NFT_ACCOUNT);
        (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        ) = v3utils.swapAndMint{value: 1 ether}(params);

        assertGt(tokenId, 0);
        assertEq(liquidity, 1249239075875054);
        assertEq(amount0, 1249125286170506379296);
        assertEq(amount1, 1249352876);

        uint256 feeBalance = WETH_ERC20.balanceOf(TEST_FEE_ACCOUNT);
        assertEq(feeBalance-feeBalanceBefore, 10000000000000000);
    }

    function testSwapETHUSDC() public {
        uint256 feeBalanceBefore = WETH_ERC20.balanceOf(TEST_FEE_ACCOUNT);

        V3Utils.SwapParams memory params = V3Utils.SwapParams(
            IWETH9(address(WETH_ERC20)),
            WETH_ERC20,
            USDC,
            500000000000000000, // 0.5ETH
            1200106259,
            TEST_NFT_ACCOUNT,
            _get05ETHToUSDCSwapData(),
            false
        );

        hoax(TEST_NFT_ACCOUNT);
        uint256 amountOut = v3utils.swap{value: (1 ether) / 2}(params);

        // fee in output token
        uint256 inputTokenBalance = WETH_ERC20.balanceOf(address(v3utils));

        // swapped to USDC - fee
        assertGt(amountOut, 1200106259);

        // input token no leftovers allowed
        assertEq(inputTokenBalance, 0);

        uint256 feeBalance = WETH_ERC20.balanceOf(TEST_FEE_ACCOUNT);
        assertEq(feeBalance-feeBalanceBefore, 5000000000000000);
    }

    function testSwapUSDCDAI() public {
        _writeTokenBalance(TEST_NFT_ACCOUNT, address(USDC), 1000000);
        V3Utils.SwapParams memory params = V3Utils.SwapParams(
            IWETH9(address(WETH_ERC20)),
            USDC,
            DAI,
            1000000, // 1 USDC
            952520864916742832,
            TEST_NFT_ACCOUNT,
            _get1USDCToDAISwapData(),
            false
        );

        vm.startPrank(TEST_NFT_ACCOUNT);
        USDC.approve(address(v3utils), 1000000);
        uint256 amountOut = v3utils.swap(params);
        vm.stopPrank();

        uint256 inputTokenBalance = USDC.balanceOf(address(v3utils));

        // swapped to DAI
        assertGt(amountOut, 952520864916742832);

        // input token no leftovers allowed
        assertEq(inputTokenBalance, 0);

        uint256 feeBalance = DAI.balanceOf(TEST_FEE_ACCOUNT); // no fees yet
        assertEq(feeBalance, 1745313470292520678);

        uint256 otherFeeBalance = USDC.balanceOf(TEST_FEE_ACCOUNT);
        assertEq(otherFeeBalance, 3346001);
    }

    function testSwapSlippageError() public {
        _writeTokenBalance(TEST_NFT_ACCOUNT, address(USDC), 1000000);
        V3Utils.SwapParams memory params = V3Utils.SwapParams(
            IWETH9(address(WETH_ERC20)),
            USDC,
            DAI,
            1000000, // 1 USDC
            1100000000000000000, // 1,1 DAI
            TEST_NFT_ACCOUNT,
            _get1USDCToDAISwapData(),
            false
        );

        vm.startPrank(TEST_NFT_ACCOUNT);
        USDC.approve(address(v3utils), 1000000);

        vm.expectRevert(Common.SlippageError.selector);
        v3utils.swap(params);
        vm.stopPrank();
    }

    function testSwapDataError() public {
        _writeTokenBalance(TEST_NFT_ACCOUNT, address(USDC), 1000000);

        V3Utils.SwapParams memory params = V3Utils.SwapParams(
            IWETH9(address(WETH_ERC20)),
            USDC,
            DAI,
            1000000, // 1 USDC
            1 ether, // 1 DAI
            TEST_NFT_ACCOUNT,
            _getInvalidSwapData(),
            false
        );

        vm.startPrank(TEST_NFT_ACCOUNT);
        USDC.approve(address(v3utils), 1000000);

        vm.expectRevert(Common.SwapFailed.selector);
        v3utils.swap(params);
        vm.stopPrank();
    }

    function testSwapUSDCETH() public {
        _writeTokenBalance(TEST_NFT_ACCOUNT, address(USDC), 1000000);

        uint256 feeBalanceBefore = USDC.balanceOf(TEST_FEE_ACCOUNT);

        V3Utils.SwapParams memory params = V3Utils.SwapParams(
            IWETH9(address(WETH_ERC20)),
            USDC,
            WETH_ERC20,
            1000000, // 1 USDC
            385039270592026, // min amount out
            TEST_NFT_ACCOUNT,
            _get1USDCToWETHSwapData(),
            true // unwrap to real ETH
        );

        uint256 balanceBefore = TEST_NFT_ACCOUNT.balance;

        vm.startPrank(TEST_NFT_ACCOUNT);
        USDC.approve(address(v3utils), 1000000);
        uint256 amountOut = v3utils.swap(params);
        vm.stopPrank();

        uint256 inputTokenBalance = USDC.balanceOf(address(v3utils));
        uint256 balanceAfter = TEST_NFT_ACCOUNT.balance;

        // swapped to ETH - fee
        assertGt(amountOut, 385039270592026);
        assertEq(amountOut, balanceAfter - balanceBefore);

        // input token no leftovers allowed
        assertEq(inputTokenBalance, 0);

        uint256 feeBalance = USDC.balanceOf(TEST_FEE_ACCOUNT);
        assertEq(feeBalance-feeBalanceBefore, 10000);
    }

    function _increaseLiquidity()
        internal
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        _writeTokenBalance(TEST_NFT_ACCOUNT, address(DAI), 1000000000000000000);

        V3Utils.SwapAndIncreaseLiquidityParams memory params = Common
            .SwapAndIncreaseLiquidityParams(
                Common.Protocol.UNI_V3,
                NPM,
                TEST_NFT,
                1000000000000000000,
                0,
                TEST_NFT_ACCOUNT,
                block.timestamp,
                IERC20(address(0)),
                0, // no swap
                0,
                "",
                0, // no swap
                0,
                "",
                0,
                0
            );

        uint256 balanceBefore = DAI.balanceOf(TEST_NFT_ACCOUNT);

        vm.startPrank(TEST_NFT_ACCOUNT);
        DAI.approve(address(v3utils), 1000000000000000000);
        (liquidity, amount0, amount1) = v3utils.swapAndIncreaseLiquidity(params);
        vm.stopPrank();

        uint256 balanceAfter = DAI.balanceOf(TEST_NFT_ACCOUNT);

        // uniswap sometimes adds not full balance (this tests that leftover tokens were returned correctly)
        assertEq(balanceBefore - balanceAfter, 999999999999998821);

        assertEq(liquidity, 500625938064039);
        assertEq(amount0, 999999999999998821); // added amount
        assertEq(amount1, 0); // only added on one side

        uint256 balanceDAI = DAI.balanceOf(address(v3utils));
        uint256 balanceUSDC = USDC.balanceOf(address(v3utils));

        assertEq(balanceDAI, 0);
        assertEq(balanceUSDC, 0);
    }

    function _get1USDCToDAISwapData() internal pure returns (bytes memory) {
        // https://api-dev.krystal.team/arbitrum/v2/swap/buildTx?userAddress=0xB9778D7d29b856A53C6331C1855Daf7342F85931&dest=0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1&src=0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8&platformWallet=0x168E4c3AC8d89B00958B6bE6400B066f0347DDc9&srcAmount=1000000&minDestAmount=9949954458431&hint=0x5b7b226964223a22556e6973776170205633222c2273706c697456616c7565223a31303030307d5d&gasPrice=0&nonce=1&skipBalanceCheck=true
        // gasLimit=0x3d06d
        return hex"2db897d000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000d2fb643a7ba8497e7f1100b4b8b38bc52e60df800000000000000000000000000000000000000000000000000000000000f42400000000000000000000000000000000000000000000000000000090ca780433f000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000064000000000000000000000000168e4c3ac8d89b00958b6be6400b066f0347ddc900000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000002000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc8000000000000000000000000da10009cbd5d07dd0cecc66161fc93d7c9000da10000000000000000000000000000000000000000000000000000000000000017e592427a0aece92de3edee1f18e0157c058615640001f4000000000000000000";
    }

    function _get1USDCToWETHSwapData() internal pure returns (bytes memory) {
        // https://api-dev.krystal.team/arbitrum/v2/swap/buildTx?userAddress=0xB9778D7d29b856A53C6331C1855Daf7342F85931&dest=0x82aF49447D8a07e3bd95BD0d56f35241523fBab1&src=0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8&platformWallet=0x168E4c3AC8d89B00958B6bE6400B066f0347DDc9&srcAmount=1000000&minDestAmount=385039270592026&hint=0x5b7b226964223a22556e6973776170205633222c2273706c697456616c7565223a31303030307d5d&gasPrice=0&nonce=1&skipBalanceCheck=true
        return hex"2db897d000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000d2fb643a7ba8497e7f1100b4b8b38bc52e60df800000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000015e30f0f2be1a000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000064000000000000000000000000168e4c3ac8d89b00958b6be6400b066f0347ddc900000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000002000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc800000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab10000000000000000000000000000000000000000000000000000000000000017e592427a0aece92de3edee1f18e0157c058615640001f4000000000000000000";
    }

    function _get1DAIToUSDSwapData() internal pure returns (bytes memory) {
        // https://api-dev.krystal.team/arbitrum/v2/swap/buildTx?userAddress=0xB9778D7d29b856A53C6331C1855Daf7342F85931&dest=0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8&src=0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1&platformWallet=0x168E4c3AC8d89B00958B6bE6400B066f0347DDc9&srcAmount=990099009900989844&minDestAmount=900000&hint=0x5b7b226964223a22556e6973776170205633222c2273706c697456616c7565223a31303030307d5d&gasPrice=0&nonce=1&skipBalanceCheck=true
        return hex"2db897d000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000d2fb643a7ba8497e7f1100b4b8b38bc52e60df80000000000000000000000000000000000000000000000000dbd89cdc19d4d9400000000000000000000000000000000000000000000000000000000000dbba0000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000064000000000000000000000000168e4c3ac8d89b00958b6be6400b066f0347ddc900000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000003000000000000000000000000da10009cbd5d07dd0cecc66161fc93d7c9000da100000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc8000000000000000000000000000000000000000000000000000000000000001ae592427a0aece92de3edee1f18e0157c058615640001f40001f4000000000000";
    }

    function _get05DAIToUSDCSwapData() internal pure returns (bytes memory) {
        // https://api-dev.krystal.team/arbitrum/v2/swap/buildTx?userAddress=0xB9778D7d29b856A53C6331C1855Daf7342F85931&dest=0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8&src=0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1&platformWallet=0x168E4c3AC8d89B00958B6bE6400B066f0347DDc9&srcAmount=500000000000000000&minDestAmount=400000&hint=0x5b7b226964223a22556e6973776170205633222c2273706c697456616c7565223a31303030307d5d&gasPrice=0&nonce=1&skipBalanceCheck=true
       return hex"2db897d000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000d2fb643a7ba8497e7f1100b4b8b38bc52e60df800000000000000000000000000000000000000000000000006f05b59d3b200000000000000000000000000000000000000000000000000000000000000061a80000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000064000000000000000000000000168e4c3ac8d89b00958b6be6400b066f0347ddc900000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000003000000000000000000000000da10009cbd5d07dd0cecc66161fc93d7c9000da100000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc8000000000000000000000000000000000000000000000000000000000000001ae592427a0aece92de3edee1f18e0157c058615640001f40001f4000000000000";
    }

    function _get05ETHToDAISwapData() internal pure returns (bytes memory) {
        // https://api-dev.krystal.team/arbitrum/v2/swap/buildTx?userAddress=0xB9778D7d29b856A53C6331C1855Daf7342F85931&dest=0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1&src=0x82aF49447D8a07e3bd95BD0d56f35241523fBab1&platformWallet=0x168E4c3AC8d89B00958B6bE6400B066f0347DDc9&srcAmount=500000000000000000&minDestAmount=1200106259&hint=0x5b7b226964223a22556e6973776170205633222c2273706c697456616c7565223a31303030307d5d&gasPrice=0&nonce=1&skipBalanceCheck=true
        return hex"2db897d000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000d2fb643a7ba8497e7f1100b4b8b38bc52e60df800000000000000000000000000000000000000000000000006f05b59d3b200000000000000000000000000000000000000000000000000000000000047882b13000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000064000000000000000000000000168e4c3ac8d89b00958b6be6400b066f0347ddc90000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000000300000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc8000000000000000000000000da10009cbd5d07dd0cecc66161fc93d7c9000da1000000000000000000000000000000000000000000000000000000000000001ae592427a0aece92de3edee1f18e0157c058615640001f40001f4000000000000";
    }

    function _get05ETHToUSDCSwapData() internal pure returns (bytes memory) {
        // https://api-dev.krystal.team/arbitrum/v2/swap/buildTx?userAddress=0xB9778D7d29b856A53C6331C1855Daf7342F85931&dest=0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8&src=0x82aF49447D8a07e3bd95BD0d56f35241523fBab1&platformWallet=0x168E4c3AC8d89B00958B6bE6400B066f0347DDc9&srcAmount=500000000000000000&minDestAmount=1200106259&hint=0x5b7b226964223a22556e6973776170205633222c2273706c697456616c7565223a31303030307d5d&gasPrice=0&nonce=1&skipBalanceCheck=true
        return hex"2db897d000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000d2fb643a7ba8497e7f1100b4b8b38bc52e60df800000000000000000000000000000000000000000000000006f05b59d3b200000000000000000000000000000000000000000000000000000000000047882b13000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000064000000000000000000000000168e4c3ac8d89b00958b6be6400b066f0347ddc90000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000000200000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc80000000000000000000000000000000000000000000000000000000000000017e592427a0aece92de3edee1f18e0157c058615640001f4000000000000000000";
    }

    function _getInvalidSwapData() internal view returns (bytes memory) {
        return abi.encode(address(v3utils), hex"1234567890");
    }
}
