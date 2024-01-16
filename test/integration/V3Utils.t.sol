// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../IntegrationTestBase.sol";
import "forge-std/console.sol";

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
        vm.expectRevert(V3Utils.NotWETH.selector);
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
            address(USDC),
            1000000000000000001,
            400000,
            1000000000000000001,
            400000,
            _get05DAIToUSDCSwapData(),
            0,
            0,
            "",
            type(uint128).max, // take all fees
            type(uint128).max, // take all fees
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
            address(USDC),
            0,
            0,
            1000000000000000001,
            400000,
            _get05DAIToUSDCSwapData(),
            0,
            0,
            "",
            type(uint128).max, // take all fees
            type(uint128).max, // take all fees
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
        vm.expectRevert(V3Utils.AmountError.selector);
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
            address(USDC),
            0,
            0,
            500000000000000000,
            400000,
            _get05DAIToUSDCSwapData(),
            0,
            0,
            "",
            type(uint128).max, // take all fees
            type(uint128).max, // take all fees
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
        v3utils.execute(TEST_NFT, inst);

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
            address(0),
            0,
            0,
            0,
            0,
            "",
            0,
            0,
            "",
            type(uint128).max,
            type(uint128).max,
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

        assertEq(daiBefore, 14382879654257202832190);
        assertEq(usdcBefore, 754563026);
        assertEq(liquidityBefore, 12922419498089422291);

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

        assertEq(daiAfter, 14382879654257202838632);
        assertEq(usdcAfter, 806331571);
        assertEq(liquidityAfter, 13034529712992826193);
    }

    function testTransferWithCompoundSwap() external {
        V3Utils.Instructions memory inst = V3Utils.Instructions(
            V3Utils.WhatToDo.COMPOUND_FEES,
            address(USDC),
            0,
            0,
            500000000000000000,
            400000,
            _get05DAIToUSDCSwapData(),
            0,
            0,
            "",
            type(uint128).max,
            type(uint128).max,
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

        assertEq(daiBefore, 14382879654257202832190);
        assertEq(usdcBefore, 754563026);
        assertEq(liquidityBefore, 12922419498089422291);

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

        assertEq(daiAfter, 14382879654257202836992);
        assertEq(usdcAfter, 807250914);
        assertEq(liquidityAfter, 13034375296304506054);
    }

    function _testTransferWithWithdrawAndSwap() internal {
        // add liquidity to existing (empty) position (add 1 DAI / 0 USDC)
        (uint128 liquidity, , ) = _increaseLiquidity();

        uint256 countBefore = NPM.balanceOf(TEST_NFT_ACCOUNT);

        // swap half of DAI to USDC and add full range
        V3Utils.Instructions memory inst = V3Utils.Instructions(
            V3Utils.WhatToDo.WITHDRAW_AND_COLLECT_AND_SWAP,
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
            INonfungiblePositionManager.DecreaseLiquidityParams(
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
            address(USDC),
            0,
            0,
            990099009900989844, // uniswap returns 1 less when getting liquidity - this must be traded
            900000,
            _get1DAIToUSDSwapData(),
            0,
            0,
            "",
            uint128(amount0),
            uint128(amount1),
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
        V3Utils.SwapAndIncreaseLiquidityParams memory params = V3Utils
            .SwapAndIncreaseLiquidityParams(
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
        V3Utils.SwapAndIncreaseLiquidityParams memory params = V3Utils
            .SwapAndIncreaseLiquidityParams(
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

        vm.prank(TEST_NFT_ACCOUNT);
        (uint128 liquidity, uint256 amount0, uint256 amount1) = v3utils.swapAndIncreaseLiquidity(params);

        uint256 feeBalance = DAI.balanceOf(TEST_FEE_ACCOUNT);

        assertEq(liquidity, 1981476553512400);
        assertEq(amount0, 990241757080297141);
        assertEq(amount0 / feeBalance, 100);
        assertEq(amount1, 0); // one sided adding
    }

    function testSwapAndIncreaseLiquiditBothSides() external {

        // add liquidity to another positions which is not owned

        V3Utils.SwapAndIncreaseLiquidityParams memory params = V3Utils
            .SwapAndIncreaseLiquidityParams(
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
        USDC.approve(address(v3utils), 2000000);

        uint256 usdcBefore = USDC.balanceOf(TEST_NFT_ACCOUNT);
        uint256 daiBefore = DAI.balanceOf(TEST_NFT_ACCOUNT);

        vm.prank(TEST_NFT_ACCOUNT);
        (uint128 liquidity, uint256 amount0, uint256 amount1) = v3utils.swapAndIncreaseLiquidity(params);

        uint256 usdcAfter = USDC.balanceOf(TEST_NFT_ACCOUNT);
        uint256 daiAfter = DAI.balanceOf(TEST_NFT_ACCOUNT);

        // close to 1% of swapped amount
        uint256 feeBalance = DAI.balanceOf(TEST_FEE_ACCOUNT);
        assertEq(feeBalance, 9845545793003026);

        assertEq(liquidity, 19461088218850);
        assertEq(amount0, 907298600975927920);
        assertEq(amount1, 1000000);

        // all usdc spent
        assertEq(usdcBefore - usdcAfter, 2000000);
        //some dai returned - because not 100% correct swap ratio
        assertEq(daiAfter - daiBefore, 82943156104369254);
    }

    function testFailEmptySwapAndMint() external {
        V3Utils.SwapAndMintParams memory params = V3Utils.SwapAndMintParams(
            DAI,
            USDC,
            500,
            MIN_TICK_500,
            -MIN_TICK_500,
            0,
            0,
            TEST_NFT_ACCOUNT,
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
            MIN_TICK_100,
            -MIN_TICK_100,
            1000425982061,
            1000000,
            1000852145583157244
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
            -MIN_TICK_100 - 200000,
            -MIN_TICK_100,
            837906268063835506826,
            1000000,
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

        V3Utils.SwapAndMintParams memory params = V3Utils.SwapAndMintParams(
            USDC,
            DAI,
            100,
            lower,
            upper,
            2000000, // provide one-sided USDC
            0,
            TEST_NFT_ACCOUNT,
            TEST_NFT_ACCOUNT,
            block.timestamp,
            USDC,
            0,
            0,
            "",
            1000000,
            900000000000000000,
            _get1USDCToDAISwapData(),
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

        uint256 feeBalance = DAI.balanceOf(TEST_FEE_ACCOUNT);
        assertEq(feeBalance, 0); // fee has not yet been taken

        assertGt(tokenId, 0);
        assertEq(liquidity, eLiquidity);
        assertEq(amount0, eAmount0);
        assertEq(amount1, eAmount1);
    }

    function testSwapAndMintWithETH() public {
        V3Utils.SwapAndMintParams memory params = V3Utils.SwapAndMintParams(
            USDC,
            DAI,
            100,
            MIN_TICK_100,
            -MIN_TICK_100,
            0,
            0,
            TEST_NFT_ACCOUNT,
            TEST_NFT_ACCOUNT,
            block.timestamp,
            WETH_ERC20,
            500000000000000000, // 0.5ETH
            1200106259,
            _get05ETHToUSDCSwapData(),
            500000000000000000, // 0.5ETH
            1200237088369182962149,
            _get05ETHToDAISwapData(),
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
        assertEq(liquidity, 1262711689014102);
        assertEq(amount0, 1262174026);
        assertEq(amount1, 1263249581542393572951);

        uint256 feeBalance0 = DAI.balanceOf(TEST_FEE_ACCOUNT);
        uint256 feeBalance1 = USDC.balanceOf(TEST_FEE_ACCOUNT);
        assertEq(feeBalance0, 0);
        assertEq(feeBalance1, 0);
    }

    function testSwapETHUSDC() public {
        V3Utils.SwapParams memory params = V3Utils.SwapParams(
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

        uint256 feeBalance = USDC.balanceOf(TEST_FEE_ACCOUNT);
        assertEq(feeBalance, 0);
    }

    function testSwapUSDCDAI() public {
        _writeTokenBalance(TEST_NFT_ACCOUNT, address(USDC), 1000000);
        V3Utils.SwapParams memory params = V3Utils.SwapParams(
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
        assertEq(feeBalance, 0);

        uint256 otherFeeBalance = USDC.balanceOf(TEST_FEE_ACCOUNT);
        assertEq(otherFeeBalance, 0);
    }

    function testSwapSlippageError() public {
        _writeTokenBalance(TEST_NFT_ACCOUNT, address(USDC), 1000000);
        V3Utils.SwapParams memory params = V3Utils.SwapParams(
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

        vm.expectRevert(V3Utils.SlippageError.selector);
        v3utils.swap(params);
        vm.stopPrank();
    }

    function testSwapDataError() public {
        V3Utils.SwapParams memory params = V3Utils.SwapParams(
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

        vm.expectRevert(V3Utils.SwapFailed.selector);
        v3utils.swap(params);
        vm.stopPrank();
    }

    function testSwapUSDCETH() public {
        _writeTokenBalance(TEST_NFT_ACCOUNT, address(USDC), 1000000);
        V3Utils.SwapParams memory params = V3Utils.SwapParams(
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

        uint256 feeBalance = WETH_ERC20.balanceOf(TEST_FEE_ACCOUNT);
        assertEq(feeBalance, 0);
    }

    function _increaseLiquidity()
        internal
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        V3Utils.SwapAndIncreaseLiquidityParams memory params = V3Utils
            .SwapAndIncreaseLiquidityParams(
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
        assertEq(balanceBefore - balanceAfter, 999999999999999633);

        assertEq(liquidity, 2001002825163355);
        assertEq(amount0, 999999999999999633); // added amount
        assertEq(amount1, 0); // only added on one side

        uint256 balanceDAI = DAI.balanceOf(address(v3utils));
        uint256 balanceUSDC = USDC.balanceOf(address(v3utils));

        assertEq(balanceDAI, 0);
        assertEq(balanceUSDC, 0);
    }

    function _get1USDCToDAISwapData() internal view returns (bytes memory) {
        // https://api.krystal.app/optimism/v2/swap/buildTx?userAddress=0x04ff397401af494d68848fcaa4c78dca785d33fc&dest=0xda10009cbd5d07dd0cecc66161fc93d7c9000da1&src=0x7f5c764cbc14f9669b88837ca1490cca17c31607&platformWallet=0x168E4c3AC8d89B00958B6bE6400B066f0347DDc9&srcAmount=1000000&minDestAmount=994995445843105100&hint=0x5b7b226964223a22556e6973776170205633222c2273706c697456616c7565223a31303030307d5d&gasPrice=0&nonce=1
        // gasLimit=0x3d06d
        return hex"2db897d000000000000000000000000000000000000000000000000000000000000000200000000000000000000000002df3bfd49633b1e0bca2f154ab0f2268f7ebc22400000000000000000000000000000000000000000000000000000000000f42400000000000000000000000000000000000000000000000000d3808ae1282a2b0000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000168e4c3ac8d89b00958b6be6400b066f0347ddc900000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000000040000000000000000000000007f5c764cbc14f9669b88837ca1490cca17c316070000000000000000000000008ae125e8653821e851f12a49f7765db9a9ce73840000000000000000000000004200000000000000000000000000000000000006000000000000000000000000da10009cbd5d07dd0cecc66161fc93d7c9000da100000000000000000000000000000000000000000000000000000000000000149c12939390052919af3155f41bf4160fd3666a6f000000000000000000000000";
    }

    function _get1USDCToWETHSwapData() internal view returns (bytes memory) {
        return hex"2db897d000000000000000000000000000000000000000000000000000000000000000200000000000000000000000002df3bfd49633b1e0bca2f154ab0f2268f7ebc22400000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000015e30f0f2be1a000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000168e4c3ac8d89b00958b6be6400b066f0347ddc9000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000000030000000000000000000000007f5c764cbc14f9669b88837ca1490cca17c316070000000000000000000000008ae125e8653821e851f12a49f7765db9a9ce7384000000000000000000000000420000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000149c12939390052919af3155f41bf4160fd3666a6f000000000000000000000000";
    }

    function _get1DAIToUSDSwapData() internal view returns (bytes memory) {
        return hex"2db897d00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000dc1d0feeacb72a29b372cbcb685562947a3027910000000000000000000000000000000000000000000000000de0b6b3a764000000000000000000000000000000000000000000000000000000000000000e7b46000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000168e4c3ac8d89b00958b6be6400b066f0347ddc900000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000003000000000000000000000000da10009cbd5d07dd0cecc66161fc93d7c9000da100000000000000000000000042000000000000000000000000000000000000060000000000000000000000007f5c764cbc14f9669b88837ca1490cca17c31607000000000000000000000000000000000000000000000000000000000000001ae592427a0aece92de3edee1f18e0157c058615640001f40001f4000000000000";
    }

    function _get05DAIToUSDCSwapData() internal view returns (bytes memory) {
       return hex"2db897d00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000dc1d0feeacb72a29b372cbcb685562947a30279100000000000000000000000000000000000000000000000006f05b59d3b200000000000000000000000000000000000000000000000000000000000000073da5000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000168e4c3ac8d89b00958b6be6400b066f0347ddc900000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000003000000000000000000000000da10009cbd5d07dd0cecc66161fc93d7c9000da100000000000000000000000042000000000000000000000000000000000000060000000000000000000000007f5c764cbc14f9669b88837ca1490cca17c31607000000000000000000000000000000000000000000000000000000000000001ae592427a0aece92de3edee1f18e0157c058615640001f40001f4000000000000";
    }

    function _get05ETHToDAISwapData() internal view returns (bytes memory) {
        return hex"2db897d00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000dc1d0feeacb72a29b372cbcb685562947a30279100000000000000000000000000000000000000000000000006f05b59d3b2000000000000000000000000000000000000000000000000004110a2b8be3e46f1e5000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000168e4c3ac8d89b00958b6be6400b066f0347ddc90000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000000300000000000000000000000042000000000000000000000000000000000000060000000000000000000000007f5c764cbc14f9669b88837ca1490cca17c31607000000000000000000000000da10009cbd5d07dd0cecc66161fc93d7c9000da1000000000000000000000000000000000000000000000000000000000000001ae592427a0aece92de3edee1f18e0157c058615640001f40001f4000000000000";
    }

    function _get05ETHToUSDCSwapData() internal view returns (bytes memory) {
        return hex"2db897d00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000dc1d0feeacb72a29b372cbcb685562947a30279100000000000000000000000000000000000000000000000006f05b59d3b200000000000000000000000000000000000000000000000000000000000047882b13000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000168e4c3ac8d89b00958b6be6400b066f0347ddc90000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000000200000000000000000000000042000000000000000000000000000000000000060000000000000000000000007f5c764cbc14f9669b88837ca1490cca17c316070000000000000000000000000000000000000000000000000000000000000017e592427a0aece92de3edee1f18e0157c058615640001f4000000000000000000";
    }

    function _getInvalidSwapData() internal view returns (bytes memory) {
        return abi.encode(address(v3utils), hex"1234567890");
    }
}
