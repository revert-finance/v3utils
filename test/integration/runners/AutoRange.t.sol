// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../IntegrationTestBase.sol";

import "../../../src/automators/AutoRange.sol";

import "v3-periphery/libraries/LiquidityAmounts.sol";

contract AutoRangeTest is IntegrationTestBase {
   
    AutoRange autoRange;

    function setUp() external {
        _setupBase();

        autoRange = new AutoRange(NPM, EX0x, OPERATOR_ACCOUNT, 60, 100);
    }

    function testSetTWAPSeconds() external {
        uint16 maxTWAPTickDifference = autoRange.maxTWAPTickDifference();
        autoRange.setTWAPConfig(maxTWAPTickDifference, 120);
        assertEq(autoRange.TWAPSeconds(), 120);

        vm.expectRevert(Automator.InvalidConfig.selector);
        autoRange.setTWAPConfig(maxTWAPTickDifference, 60);
    }

    function testSetMaxTWAPTickDifference() external {
        uint32 TWAPSeconds = autoRange.TWAPSeconds();
        autoRange.setTWAPConfig(5, TWAPSeconds);
        assertEq(autoRange.maxTWAPTickDifference(), 5);

        vm.expectRevert(Automator.InvalidConfig.selector);
        autoRange.setTWAPConfig(10, TWAPSeconds);
    }

    function testSetOperator() external {
        assertEq(autoRange.operator(), OPERATOR_ACCOUNT);
        autoRange.setOperator(TEST_NFT_ACCOUNT);
        assertEq(autoRange.operator(), TEST_NFT_ACCOUNT);
    }


    function testUnauthorizedSetConfig() external {
        vm.expectRevert(Automator.Unauthorized.selector);
        vm.prank(TEST_NFT_ACCOUNT);
        autoRange.configToken(TEST_NFT_2, AutoRange.PositionConfig(0, 0, 0, 1, 0, 0));
    }

    function testResetConfig() external {
        vm.prank(TEST_NFT_ACCOUNT);
        autoRange.configToken(TEST_NFT, AutoRange.PositionConfig(0, 0, 0, 0, 0, 0));
    }

    function testInvalidConfig() external {
        vm.expectRevert(Automator.InvalidConfig.selector);
        vm.prank(TEST_NFT_ACCOUNT);
        autoRange.configToken(TEST_NFT, AutoRange.PositionConfig(0, 0, 1, 0, 0, 0));
    }

    function testValidSetConfig() external {
        vm.prank(TEST_NFT_ACCOUNT);
        AutoRange.PositionConfig memory configIn = AutoRange.PositionConfig(1, -1, 0, 1, 123, 456);
        autoRange.configToken(TEST_NFT, configIn);
        (int32 i1, int32 i2, int32 i3, int32 i4, uint64 i5, uint64 i6) = autoRange.positionConfigs(TEST_NFT);
        assertEq(abi.encode(configIn), abi.encode(AutoRange.PositionConfig(i1, i2, i3, i4, i5, i6)));
    }

    function testNonOperator() external {
        vm.expectRevert(Automator.Unauthorized.selector);
        vm.prank(TEST_NFT_ACCOUNT);
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT, false, 0, "", block.timestamp));
    }

    function testAdjustWithoutApprove() external {
        // out of range position
        vm.prank(TEST_NFT_2_ACCOUNT);
        autoRange.configToken(TEST_NFT_2, AutoRange.PositionConfig(0, 0, 0, 1, 0, 0));

        // fails when sending NFT
        vm.expectRevert(abi.encodePacked("Not approved"));
        
        vm.prank(OPERATOR_ACCOUNT);
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT_2, false, 0, "", block.timestamp));
    }

    function testAdjustWithoutConfig() external {

        vm.prank(TEST_NFT_ACCOUNT);
        NPM.setApprovalForAll(address(autoRange), true);

        vm.expectRevert(AutoRange.NotConfigured.selector);
        vm.prank(OPERATOR_ACCOUNT);
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT, false, 0, "", block.timestamp));
    }

    function testAdjustNotAdjustable() external {
        vm.prank(TEST_NFT_2_ACCOUNT);
        NPM.setApprovalForAll(address(autoRange), true);

        vm.prank(TEST_NFT_2_ACCOUNT);
        autoRange.configToken(TEST_NFT_2_A, AutoRange.PositionConfig(0, 0, 0, 60, uint64(Q64 / 100), uint64(Q64 / 100))); // 1% max fee, 1% max slippage

        // in range position cant be adjusted
        vm.expectRevert(AutoRange.NotReady.selector);
        vm.prank(OPERATOR_ACCOUNT);
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT_2_A, false, 0, "", block.timestamp));
    }

    function testAdjustOutOfRange() external {
        vm.prank(TEST_NFT_2_ACCOUNT);
        NPM.setApprovalForAll(address(autoRange), true);

        vm.prank(TEST_NFT_2_ACCOUNT);
        autoRange.configToken(TEST_NFT_2, AutoRange.PositionConfig(0, 0, -int32(uint32(type(uint24).max)), int32(uint32(type(uint24).max)), 0, 0)); // 1% max fee, 1% max slippage

        // will be reverted because range Arithmetic over/underflow
        vm.expectRevert(abi.encodePacked("SafeCast: value doesn't fit in 24 bits"));
        vm.prank(OPERATOR_ACCOUNT);
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT_2, false, 0, "", block.timestamp));
    }

    function testAdjustWithoutSwap() external {

        // using out of range position TEST_NFT_2
        // available amounts -> 311677619940061890346 506903060556612041
        // added to new position -> 311677619940061890345 77467250371417094
        
        vm.prank(TEST_NFT_2_ACCOUNT);
        NPM.setApprovalForAll(address(autoRange), true);

        vm.prank(TEST_NFT_2_ACCOUNT);
        autoRange.configToken(TEST_NFT_2, AutoRange.PositionConfig(0, 0, 0, 60, uint64(Q64 / 100), uint64(Q64 / 100))); // 1% max fee, 1% max slippage
        uint count = NPM.balanceOf(TEST_NFT_2_ACCOUNT);
        assertEq(count, 4);

        uint protocolDAIBalanceBefore = DAI.balanceOf(address(autoRange));
        uint protocolWETHBalanceBefore = WETH_ERC20.balanceOf(address(autoRange));

        uint ownerDAIBalanceBefore = DAI.balanceOf(TEST_NFT_2_ACCOUNT);
        uint ownerWETHBalanceBefore = TEST_NFT_2_ACCOUNT.balance;

        vm.prank(OPERATOR_ACCOUNT);
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT_2, false, 0, "", block.timestamp)); // max fee with 1% is 7124618988448545

        // is not adjustable yet because config was removed
        vm.prank(OPERATOR_ACCOUNT);
        vm.expectRevert(AutoRange.NotConfigured.selector);
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT_2, false, 0, "", block.timestamp));

        // protocol fee
        assertEq(DAI.balanceOf(address(autoRange)) - protocolDAIBalanceBefore, 777250922543795237);
        assertEq(WETH_ERC20.balanceOf(address(autoRange)) - protocolWETHBalanceBefore, 193185163020990);

        // leftovers returned to owner
        assertEq(DAI.balanceOf(TEST_NFT_2_ACCOUNT) - ownerDAIBalanceBefore, 1); // all was added to position
        assertEq(TEST_NFT_2_ACCOUNT.balance - ownerWETHBalanceBefore, 429435810185194946); // leftover + fee + deposited = total in old position

        count = NPM.balanceOf(TEST_NFT_2_ACCOUNT);
        assertEq(count, 5);

        // new NFT is latest NFT - because of the order they are added
        uint tokenId = NPM.tokenOfOwnerByIndex(TEST_NFT_2_ACCOUNT, count - 1);

        // is not adjustable yet because in range
        vm.prank(OPERATOR_ACCOUNT);
        vm.expectRevert(AutoRange.NotReady.selector);
        autoRange.execute(AutoRange.ExecuteParams(tokenId, false, 0, "", block.timestamp));

        // newly minted token
        assertEq(tokenId, 309207);

        (, , , , , int24 tickLowerAfter, int24 tickUpperAfter , uint128 liquidity, , , , ) = NPM.positions(tokenId);
        (, , address token0 , address token1 , uint24 fee , , , uint128 liquidityOld, , , , ) = NPM.positions(TEST_NFT_2);

        IUniswapV3Pool pool = IUniswapV3Pool(PoolAddress.computeAddress(FACTORY, PoolAddress.getPoolKey(token0, token1, fee)));
        (uint160 sqrtPriceX96, int24 currentTick,,,,,) = pool.slot0();

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(sqrtPriceX96, TickMath.getSqrtRatioAtTick(tickLowerAfter), TickMath.getSqrtRatioAtTick(tickUpperAfter), liquidity);

        // new position amounts
        assertEq(amount0, 310900369017518095107); //DAI
        assertEq(amount1, 77274065208396104); //WETH

        // check tick range correct
        assertEq(tickLowerAfter, -73260);
        assertEq(currentTick,  -73244);
        assertEq(tickUpperAfter, -73260 + 60);

        assertEq(liquidity, 3667918618704675260835);
        assertEq(liquidityOld, 0);
    }

    function testAdjustWithSwap() external {

        // using out of range position TEST_NFT_2
        // available amounts -> DAI 311677619940061890346 WETH 506903060556612041
        // swapping 0.3 WETH -> DAI (so more can be added to new position) 
        // added to new position -> 767197802262466967698 190686467137733081
        
        vm.prank(TEST_NFT_2_ACCOUNT);
        NPM.setApprovalForAll(address(autoRange), true);

        vm.prank(TEST_NFT_2_ACCOUNT);
        autoRange.configToken(TEST_NFT_2, AutoRange.PositionConfig(0, 0, 0, 60, uint64(Q64 / 100), uint64(Q64 / 100))); // 1% max fee, 1% max slippage
       
        uint protocolDAIBalanceBefore = DAI.balanceOf(address(autoRange));
        uint protocolWETHBalanceBefore = WETH_ERC20.balanceOf(address(autoRange));

        uint ownerDAIBalanceBefore = DAI.balanceOf(TEST_NFT_2_ACCOUNT);
        uint ownerWETHBalanceBefore = TEST_NFT_2_ACCOUNT.balance;

        vm.prank(OPERATOR_ACCOUNT);
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT_2, false, 300000000000000000, _get03WETHToDAISwapData(), block.timestamp)); // max fee with 1% is 7124618988448545

        // protocol fee
        assertEq(DAI.balanceOf(address(autoRange)) - protocolDAIBalanceBefore, 1913211476963758022);
        assertEq(WETH_ERC20.balanceOf(address(autoRange)) - protocolWETHBalanceBefore, 475527349470656);

        // leftovers returned to owner
        assertEq(DAI.balanceOf(TEST_NFT_2_ACCOUNT) - ownerDAIBalanceBefore, 1); // all was added to position
        assertEq(TEST_NFT_2_ACCOUNT.balance - ownerWETHBalanceBefore, 16216593418878959); // leftover + fee + deposited = total in old position

        uint count = NPM.balanceOf(TEST_NFT_2_ACCOUNT);

        // new NFT is latest NFT - because of the order they are added
        uint tokenId = NPM.tokenOfOwnerByIndex(TEST_NFT_2_ACCOUNT, count - 1);

        // newly minted token
        assertEq(tokenId, 309207);

        (, , , , , int24 tickLowerAfter, int24 tickUpperAfter , uint128 liquidity, , , , ) = NPM.positions(tokenId);
        (, , address token0 , address token1 , uint24 fee , , , uint128 liquidityOld, , , , ) = NPM.positions(TEST_NFT_2);

        IUniswapV3Pool pool = IUniswapV3Pool(PoolAddress.computeAddress(FACTORY, PoolAddress.getPoolKey(token0, token1, fee)));
        (uint160 sqrtPriceX96, int24 currentTick,,,,,) = pool.slot0();

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(sqrtPriceX96, TickMath.getSqrtRatioAtTick(tickLowerAfter), TickMath.getSqrtRatioAtTick(tickUpperAfter), liquidity);

        // new position amounts
        assertEq(amount0, 765284590785503209675); //DAI
        assertEq(amount1, 190210939788262425); //WETH

        // check tick range correct
        assertEq(tickLowerAfter, -73260);
        assertEq(currentTick,  -73244);
        assertEq(tickUpperAfter, -73260 + 60);

        assertEq(liquidity, 9028620995273798933977);
        assertEq(liquidityOld, 0);
    }

    function testDoubleAdjust() external {
                
        vm.prank(TEST_NFT_2_ACCOUNT);
        NPM.setApprovalForAll(address(autoRange), true);

        // bad config so it can be adjusted multiple times
        vm.prank(TEST_NFT_2_ACCOUNT);
        autoRange.configToken(TEST_NFT_2, AutoRange.PositionConfig(-100000, -100000, 0, 60, uint64(Q64 / 100), uint64(Q64 / 100)));

        // first adjust ok
        vm.prank(OPERATOR_ACCOUNT);
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT_2, false, 0, "", block.timestamp));

        uint count = NPM.balanceOf(TEST_NFT_2_ACCOUNT);
        uint tokenId = NPM.tokenOfOwnerByIndex(TEST_NFT_2_ACCOUNT, count - 1);

        // newly minted token
        assertEq(tokenId, 309207);

        // second ajust leads to same range error
        vm.prank(OPERATOR_ACCOUNT);
        vm.expectRevert(AutoRange.SameRange.selector);
        autoRange.execute(AutoRange.ExecuteParams(tokenId, false, 0, "", block.timestamp));
    }

    function testOracleCheck() external {

        // create range adjustor with more strict oracle config    
        autoRange = new AutoRange(NPM, EX0x, OPERATOR_ACCOUNT, 60 * 30, 4);

        vm.prank(TEST_NFT_2_ACCOUNT);
        NPM.setApprovalForAll(address(autoRange), true);

        vm.prank(TEST_NFT_2_ACCOUNT);
        autoRange.configToken(TEST_NFT_2, AutoRange.PositionConfig(-100000, -100000, 0, 60, uint64(Q64 / 100), uint64(Q64 / 100)));

        // TWAPCheckFailed
        vm.prank(OPERATOR_ACCOUNT);
        vm.expectRevert(Automator.TWAPCheckFailed.selector);
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT_2, false, 0, "", block.timestamp));
    }

    function _get03WETHToDAISwapData() internal view returns (bytes memory) {
        // https://api.0x.org/swap/v1/quote?sellToken=WETH&buyToken=DAI&sellAmount=300000000000000000&slippagePercentage=0.25
        return
            abi.encode(
                EX0x,
                hex"6af479b200000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000429d069189e00000000000000000000000000000000000000000000000000130ac08c36b9dfe37f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002bc02aaa39b223fe8d0a0e5c4f27ead9083c756cc20001f46b175474e89094c44da98b954eedeac495271d0f000000000000000000000000000000000000000000869584cd00000000000000000000000010000000000000000000000000000000000000110000000000000000000000000000000000000000000000ce62b248cc6402739e"
            );
    }
}