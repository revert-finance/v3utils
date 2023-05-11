// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../IntegrationTestBase.sol";

import "../../../src/runners/StopLossLimitor.sol";

contract StopLossLimitorTest is IntegrationTestBase {
    
    StopLossLimitor stopLossLimitor;

    function setUp() external {
        _setupBase();
        stopLossLimitor = new StopLossLimitor(NPM, EX0x, OPERATOR_ACCOUNT, 60, 100);
    }

    function _setConfig(
        uint tokenId,
        bool isActive,
        bool token0Swap,
        bool token1Swap,
        uint64 token0SlippageX64,
        uint64 token1SlippageX64,
        int24 token0TriggerTick,
        int24 token1TriggerTick
    ) internal {
        StopLossLimitor.PositionConfig memory config = StopLossLimitor.PositionConfig(
                isActive,
                token0Swap,
                token1Swap,
                token0SlippageX64,
                token1SlippageX64,
                token0TriggerTick,
                token1TriggerTick
            );

        vm.prank(TEST_NFT_ACCOUNT);
        stopLossLimitor.configToken(tokenId, config);
    }

    function testNoLiquidity() external {
        _setConfig(TEST_NFT, true, false, false, 0, 0, type(int24).min, type(int24).max);

        (, , , , , , , uint128 liquidity, , , , ) = NPM.positions(TEST_NFT);

        assertEq(liquidity, 0);

        vm.expectRevert(StopLossLimitor.NoLiquidity.selector);
        vm.prank(OPERATOR_ACCOUNT);
        stopLossLimitor.execute(StopLossLimitor.ExecuteParams(TEST_NFT, "", block.timestamp));
    }

    function _addLiquidity() internal returns (uint256 amount0, uint256 amount1) {
         // add onesided liquidity
        vm.startPrank(TEST_NFT_ACCOUNT);
        DAI.approve(address(NPM), 1000000000000000000);
        (, amount0, amount1) = NPM.increaseLiquidity(INonfungiblePositionManager.IncreaseLiquidityParams(TEST_NFT, 1000000000000000000, 0, 0, 0, block.timestamp));

        assertEq(amount0, 999999999999999633);
        assertEq(amount1, 0);

        vm.stopPrank();
    }

    function testRangesAndActions() external {

        (uint amount0, uint amount1) = _addLiquidity();
        
        (, ,address token0, address token1, uint24 fee , int24 tickLower, int24 tickUpper, uint128 liquidity, , , , ) = NPM.positions(TEST_NFT);

        IUniswapV3Pool pool = IUniswapV3Pool(PoolAddress.computeAddress(FACTORY, PoolAddress.PoolKey({token0: token0, token1: token1, fee: fee})));

        (, int24 tick, , , , , ) = pool.slot0();

        assertGt(liquidity, 0);
        assertEq(tickLower, -276320);
        assertEq(tickUpper, -276310);
        assertEq(tick, -276325);
    
        vm.prank(TEST_NFT_ACCOUNT);
        NPM.setApprovalForAll(address(stopLossLimitor), true);

        _setConfig(TEST_NFT, true, false, false, 0, 0, -276325, type(int24).max);
        vm.expectRevert(StopLossLimitor.NotInCondition.selector);
        vm.prank(OPERATOR_ACCOUNT);
        stopLossLimitor.execute(StopLossLimitor.ExecuteParams(TEST_NFT, "", block.timestamp));

        uint balanceBeforeOwner = DAI.balanceOf(TEST_NFT_ACCOUNT);

        _setConfig(TEST_NFT, true, false, false, 0, 0, -276324, type(int24).max);

        // execute limit order - without swap
        vm.prank(OPERATOR_ACCOUNT); 
        stopLossLimitor.execute(StopLossLimitor.ExecuteParams(TEST_NFT, "", block.timestamp));

        (, ,, , ,, ,liquidity, , , , ) = NPM.positions(TEST_NFT);
        assertEq(liquidity, 0);

        uint balanceAfterOwner = DAI.balanceOf(TEST_NFT_ACCOUNT);

        // check paid fee
        uint balanceBefore = DAI.balanceOf(address(this));
        stopLossLimitor.withdrawBalance(address(DAI), address(this));
        uint balanceAfter = DAI.balanceOf(address(this));

        assertEq(balanceAfterOwner + balanceAfter - balanceBeforeOwner - balanceBefore + 1, amount0); // +1 because Uniswap imprecision (remove same liquidity returns 1 less)

        // is not runnable anymore because configuration was removed
        vm.prank(OPERATOR_ACCOUNT);
        vm.expectRevert(StopLossLimitor.NotConfigured.selector);
        stopLossLimitor.execute(StopLossLimitor.ExecuteParams(TEST_NFT, "", block.timestamp));

        // add new liquidity
        (amount0, amount1) = _addLiquidity();

        // change to swap
        _setConfig(TEST_NFT, true, true, true, uint64(Q64 / 100), uint64(Q64 / 100), -276324, type(int24).max);

        // execute without swap data fails because not allowed by config
        vm.expectRevert(StopLossLimitor.MissingSwapData.selector);
        vm.prank(OPERATOR_ACCOUNT);
        stopLossLimitor.execute(StopLossLimitor.ExecuteParams(TEST_NFT, "", block.timestamp));

        // execute stop loss order - with swap
        uint swapBalanceBefore = USDC.balanceOf(TEST_NFT_ACCOUNT);

        vm.prank(OPERATOR_ACCOUNT);
        stopLossLimitor.execute(StopLossLimitor.ExecuteParams(TEST_NFT, _getDAIToUSDSwapData(), block.timestamp));
        uint swapBalanceAfter = USDC.balanceOf(TEST_NFT_ACCOUNT);
        
        // protocol fee
        balanceBefore = USDC.balanceOf(address(this));
        stopLossLimitor.withdrawBalance(address(USDC), address(this));
        balanceAfter = USDC.balanceOf(address(this));

        assertEq(swapBalanceAfter - swapBalanceBefore, 988879);
        assertEq(balanceAfter - balanceBefore, 4969);
    }

     function testDirectSendNFT() external {
        vm.prank(TEST_NFT_ACCOUNT);
        vm.expectRevert(abi.encodePacked("ERC721: transfer to non ERC721Receiver implementer")); // NFT manager doesnt resend original error for some reason
        NPM.safeTransferFrom(TEST_NFT_ACCOUNT, address(stopLossLimitor), TEST_NFT);
    }

    function testSetTWAPSeconds() external {
        uint16 maxTWAPTickDifference = stopLossLimitor.maxTWAPTickDifference();
        stopLossLimitor.setTWAPConfig(maxTWAPTickDifference, 120);
        assertEq(stopLossLimitor.TWAPSeconds(), 120);

        vm.expectRevert(Runner.InvalidConfig.selector);
        stopLossLimitor.setTWAPConfig(maxTWAPTickDifference, 60);
    }

    function testSetMaxTWAPTickDifference() external {
        uint32 TWAPSeconds = stopLossLimitor.TWAPSeconds();
        stopLossLimitor.setTWAPConfig(5, TWAPSeconds);
        assertEq(stopLossLimitor.maxTWAPTickDifference(), 5);

        vm.expectRevert(Runner.InvalidConfig.selector);
        stopLossLimitor.setTWAPConfig(10, TWAPSeconds);
    }

    function testSetOperator() external {
        assertEq(stopLossLimitor.operator(), OPERATOR_ACCOUNT);
        stopLossLimitor.setOperator(TEST_NFT_ACCOUNT);
        assertEq(stopLossLimitor.operator(), TEST_NFT_ACCOUNT);
    }


    function testUnauthorizedSetConfig() external {
        vm.expectRevert(Runner.Unauthorized.selector);
        vm.prank(TEST_NFT_ACCOUNT);
        stopLossLimitor.configToken(TEST_NFT_2, StopLossLimitor.PositionConfig(false, false, false, 0, 0, 0, 0));
    }

    function testResetConfig() external {
        vm.prank(TEST_NFT_ACCOUNT);
        stopLossLimitor.configToken(TEST_NFT, StopLossLimitor.PositionConfig(false, false, false, 0, 0, 0, 0));
    }

    function testInvalidConfig() external {
        vm.expectRevert(Runner.InvalidConfig.selector);
        vm.prank(TEST_NFT_ACCOUNT);
        stopLossLimitor.configToken(TEST_NFT, StopLossLimitor.PositionConfig(true, false, false,  0, 0, 800000, -800000));
    }

    function testValidSetConfig() external {
        vm.prank(TEST_NFT_ACCOUNT);
        StopLossLimitor.PositionConfig memory configIn = StopLossLimitor.PositionConfig(true, false, false, 0, 0, -800000, 800000);
        stopLossLimitor.configToken(TEST_NFT, configIn);
        (bool i1, bool i2, bool i3, uint64 i4, uint64 i5, int24 i6, int24 i7) = stopLossLimitor.positionConfigs(TEST_NFT);
        assertEq(abi.encode(configIn), abi.encode(StopLossLimitor.PositionConfig(i1, i2, i3, i4, i5, i6, i7)));
    }

    function testNonOperator() external {
        vm.expectRevert(Runner.Unauthorized.selector);
        vm.prank(TEST_NFT_ACCOUNT);
        stopLossLimitor.execute(StopLossLimitor.ExecuteParams(TEST_NFT, "", block.timestamp));
    }

    function testRunWithoutApprove() external {
        // out of range position
        vm.prank(TEST_NFT_2_ACCOUNT);
        stopLossLimitor.configToken(TEST_NFT_2, StopLossLimitor.PositionConfig(true, false, false, 0, 0, -84121, -78240));

        // fails when sending NFT
        vm.expectRevert(abi.encodePacked("Not approved"));
        
        vm.prank(OPERATOR_ACCOUNT);
        stopLossLimitor.execute(StopLossLimitor.ExecuteParams(TEST_NFT_2, "", block.timestamp));
    }

    function testRunWithoutConfig() external {

        vm.prank(TEST_NFT_ACCOUNT);
        NPM.setApprovalForAll(address(stopLossLimitor), true);

        vm.expectRevert(StopLossLimitor.NotConfigured.selector);
        vm.prank(OPERATOR_ACCOUNT);
        stopLossLimitor.execute(StopLossLimitor.ExecuteParams(TEST_NFT, "", block.timestamp));
    }

    function testRunNotReady() external {
        vm.prank(TEST_NFT_2_ACCOUNT);
        NPM.setApprovalForAll(address(stopLossLimitor), true);

        vm.prank(TEST_NFT_2_ACCOUNT);
        stopLossLimitor.configToken(TEST_NFT_2_A, StopLossLimitor.PositionConfig(true, false, false, 0, 0, -276331, -276320));

        // in range position cant be run
        vm.expectRevert(StopLossLimitor.NotInCondition.selector);
        vm.prank(OPERATOR_ACCOUNT);
        stopLossLimitor.execute(StopLossLimitor.ExecuteParams(TEST_NFT_2_A, "", block.timestamp));
    }

    function testOracleCheck() external {

        // create range adjustor with more strict oracle config    
        stopLossLimitor = new StopLossLimitor(NPM, EX0x, OPERATOR_ACCOUNT, 60 * 30, 4);

        vm.prank(TEST_NFT_2_ACCOUNT);
        NPM.setApprovalForAll(address(stopLossLimitor), true);

        vm.prank(TEST_NFT_2_ACCOUNT);
        stopLossLimitor.configToken(TEST_NFT_2, StopLossLimitor.PositionConfig(true, true, true, uint64(Q64 / 100), uint64(Q64 / 100), -84121, -78240));

        // TWAPCheckFailed
        vm.prank(OPERATOR_ACCOUNT);
        vm.expectRevert(Runner.TWAPCheckFailed.selector);
        stopLossLimitor.execute(StopLossLimitor.ExecuteParams(TEST_NFT_2, _getWETHToDAISwapData(), block.timestamp));
    }


    // tests LimitOrder without adding to module
    function testLimitOrder() external {

        // using out of range position TEST_NFT_2
        // available amounts -> DAI (fees) 311677619940061890346 WETH(fees + liquidity) 506903060556612041
        
        vm.prank(TEST_NFT_2_ACCOUNT);
        NPM.setApprovalForAll(address(stopLossLimitor), true);

        vm.prank(TEST_NFT_2_ACCOUNT);
        stopLossLimitor.configToken(TEST_NFT_2, StopLossLimitor.PositionConfig(true, false, false, uint64(Q64 / 100), uint64(Q64 / 100), -84121, -78240)); // 1% max slippage

        uint contractWETHBalanceBefore = WETH_ERC20.balanceOf(address(stopLossLimitor));
        uint contractDAIBalanceBefore = DAI.balanceOf(address(stopLossLimitor));

        uint ownerDAIBalanceBefore = DAI.balanceOf(TEST_NFT_2_ACCOUNT);
        uint ownerWETHBalanceBefore = TEST_NFT_2_ACCOUNT.balance;

        vm.prank(OPERATOR_ACCOUNT);
        stopLossLimitor.execute(StopLossLimitor.ExecuteParams(TEST_NFT_2, "", block.timestamp)); // max fee with 1% is 7124618988448545

        // is not runnable anymore because configuration was removed
        vm.prank(OPERATOR_ACCOUNT);
        vm.expectRevert(StopLossLimitor.NotConfigured.selector);
        stopLossLimitor.execute(StopLossLimitor.ExecuteParams(TEST_NFT_2, "", block.timestamp));

        // fee stored for owner in contract
        assertEq(WETH_ERC20.balanceOf(address(stopLossLimitor)) - contractWETHBalanceBefore, 2534515302783060);
        assertEq(DAI.balanceOf(address(stopLossLimitor)) - contractDAIBalanceBefore, 1558388099700309450);

        // leftovers returned to owner
        assertEq(DAI.balanceOf(TEST_NFT_2_ACCOUNT) - ownerDAIBalanceBefore, 310119231840361580896); // all available
        assertEq(TEST_NFT_2_ACCOUNT.balance - ownerWETHBalanceBefore, 504368545253828981); // all available
    }

    // tests StopLoss without adding to module
    function testStopLoss() external {
        // using out of range position TEST_NFT_2
        // available amounts -> DAI (fees) 311677619940061890346 WETH(fees + liquidity) 506903060556612041
        
        vm.prank(TEST_NFT_2_ACCOUNT);
        NPM.setApprovalForAll(address(stopLossLimitor), true);

        vm.prank(TEST_NFT_2_ACCOUNT);
        stopLossLimitor.configToken(TEST_NFT_2, StopLossLimitor.PositionConfig(true, true, true, uint64(Q64 / 100), uint64(Q64 / 100), -84121, -78240)); // 1% max slippage

        uint contractWETHBalanceBefore = WETH_ERC20.balanceOf(address(stopLossLimitor));
        uint contractDAIBalanceBefore = DAI.balanceOf(address(stopLossLimitor));

        uint ownerDAIBalanceBefore = DAI.balanceOf(TEST_NFT_2_ACCOUNT);
        uint ownerWETHBalanceBefore = TEST_NFT_2_ACCOUNT.balance;

        // is not runnable without swap
        vm.prank(OPERATOR_ACCOUNT);
        vm.expectRevert(StopLossLimitor.MissingSwapData.selector);
        stopLossLimitor.execute(StopLossLimitor.ExecuteParams(TEST_NFT_2, "", block.timestamp));

        vm.prank(OPERATOR_ACCOUNT);
        stopLossLimitor.execute(StopLossLimitor.ExecuteParams(TEST_NFT_2, _getWETHToDAISwapData(), block.timestamp));

        // is not runnable anymore because configuration was removed
        vm.prank(OPERATOR_ACCOUNT);
        vm.expectRevert(StopLossLimitor.NotConfigured.selector);
        stopLossLimitor.execute(StopLossLimitor.ExecuteParams(TEST_NFT_2, _getWETHToDAISwapData(), block.timestamp));

        // fee stored for owner in contract
        assertEq(WETH_ERC20.balanceOf(address(stopLossLimitor)) - contractWETHBalanceBefore, 0);
        assertEq(DAI.balanceOf(address(stopLossLimitor)) - contractDAIBalanceBefore, 5406774833810580731);

        // leftovers returned to owner
        assertEq(DAI.balanceOf(TEST_NFT_2_ACCOUNT) - ownerDAIBalanceBefore, 1075948191928305566472); // all available
        assertEq(TEST_NFT_2_ACCOUNT.balance - ownerWETHBalanceBefore, 0); // all available
    }

    function _getWETHToDAISwapData() internal view returns (bytes memory) {
        // https://api.0x.org/swap/v1/quote?sellToken=WETH&buyToken=DAI&sellAmount=506903060556612041&slippagePercentage=0.25
        return
            abi.encode(
                EX0x,
                hex"6af479b200000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000708e1a5dc0901c90000000000000000000000000000000000000000000000259f6c7a7e07497b8c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002bc02aaa39b223fe8d0a0e5c4f27ead9083c756cc20001f46b175474e89094c44da98b954eedeac495271d0f000000000000000000000000000000000000000000869584cd00000000000000000000000010000000000000000000000000000000000000110000000000000000000000000000000000000000000000c4cce18ee664276707"
            );
    }

    function _getDAIToUSDSwapData() internal view returns (bytes memory) {
        // https://api.0x.org/swap/v1/quote?sellToken=DAI&buyToken=USDC&sellAmount=999999999999999632&slippagePercentage=0.05
        return
            abi.encode(
                EX0x,
                hex"d9627aa400000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000de0b6b3a763fe9000000000000000000000000000000000000000000000000000000000000e777d000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48869584cd0000000000000000000000001000000000000000000000000000000000000011000000000000000000000000000000000000000000000045643479ef636e6e94"
            );
    }
}
