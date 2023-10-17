// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../IntegrationTestBase.sol";

import "../../../src/automators/AutoRange.sol";

import "v3-periphery/libraries/LiquidityAmounts.sol";

contract AutoRangeTest is IntegrationTestBase {
   
    AutoRange autoRange;

    function setUp() external {
        _setupBase();
        autoRange = new AutoRange(NPM, OPERATOR_ACCOUNT, WITHDRAWER_ACCOUNT, 60, 100, _getSwapRouterOptions());
    }

    function testSetTWAPSeconds() external {
        uint16 maxTWAPTickDifference = autoRange.maxTWAPTickDifference();
        autoRange.setTWAPConfig(maxTWAPTickDifference, 120);
        assertEq(autoRange.TWAPSeconds(), 120);

        vm.expectRevert(Automator.InvalidConfig.selector);
        autoRange.setTWAPConfig(maxTWAPTickDifference, 30);
    }

    function testSetMaxTWAPTickDifference() external {
        uint32 TWAPSeconds = autoRange.TWAPSeconds();
        autoRange.setTWAPConfig(5, TWAPSeconds);
        assertEq(autoRange.maxTWAPTickDifference(), 5);

        vm.expectRevert(Automator.InvalidConfig.selector);
        autoRange.setTWAPConfig(600, TWAPSeconds);
    }

    function testSetOperator() external {
        assertEq(autoRange.operators(TEST_NFT_ACCOUNT), false);
        autoRange.setOperator(TEST_NFT_ACCOUNT, true);
        assertEq(autoRange.operators(TEST_NFT_ACCOUNT), true);
    }

    function testUnauthorizedSetConfig() external {
        vm.expectRevert(Automator.Unauthorized.selector);
        vm.prank(TEST_NFT_ACCOUNT);
        autoRange.configToken(TEST_NFT_2, AutoRange.PositionConfig(0, 0, 0, 1, 0, 0, false, MAX_REWARD));
    }

    function testResetConfig() external {
        vm.prank(TEST_NFT_ACCOUNT);
        autoRange.configToken(TEST_NFT, AutoRange.PositionConfig(0, 0, 0, 0, 0, 0, false, MAX_REWARD));
    }

    function testInvalidConfig() external {
        vm.expectRevert(Automator.InvalidConfig.selector);
        vm.prank(TEST_NFT_ACCOUNT);
        autoRange.configToken(TEST_NFT, AutoRange.PositionConfig(0, 0, 1, 0, 0, 0, false, MAX_REWARD));
    }

    function testValidSetConfig() external {
        vm.prank(TEST_NFT_ACCOUNT);
        AutoRange.PositionConfig memory configIn = AutoRange.PositionConfig(1, -1, 0, 1, 123, 456, false, MAX_REWARD);
        autoRange.configToken(TEST_NFT, configIn);
        (int32 i1, int32 i2, int32 i3, int32 i4, uint64 i5, uint64 i6, bool i7, uint64 i8) = autoRange.positionConfigs(TEST_NFT);
        assertEq(abi.encode(configIn), abi.encode(AutoRange.PositionConfig(i1, i2, i3, i4, i5, i6, i7, i8)));
    }

    function testNonOperator() external {
        vm.expectRevert(Automator.Unauthorized.selector);
        vm.prank(TEST_NFT_ACCOUNT);
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT, false, 0, "", 0, 0, 0, block.timestamp, MAX_REWARD));
    }

    function testAdjustWithoutApprove() external {
        // out of range position
        vm.prank(TEST_NFT_2_ACCOUNT);
        autoRange.configToken(TEST_NFT_2, AutoRange.PositionConfig(0, 0, 0, 1, 0, 0, false, MAX_REWARD));

        (, , , , , , , uint128 liquidity, , , , ) = NPM.positions(TEST_NFT_2);

        // fails when sending NFT
        vm.expectRevert(abi.encodePacked("Not approved"));
        
        vm.prank(OPERATOR_ACCOUNT);
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT_2, false, 0, "", liquidity, 0, 0, block.timestamp, MAX_REWARD));
    }

    function testAdjustWithoutConfig() external {

        vm.prank(TEST_NFT_ACCOUNT);
        NPM.setApprovalForAll(address(autoRange), true);

        vm.expectRevert(Automator.NotConfigured.selector);
        vm.prank(OPERATOR_ACCOUNT);
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT, false, 0, "", 0, 0, 0, block.timestamp, MAX_REWARD));
    }

    function testAdjustNotAdjustable() external {
        vm.prank(TEST_NFT_2_ACCOUNT);
        NPM.setApprovalForAll(address(autoRange), true);

        vm.prank(TEST_NFT_2_ACCOUNT);
        autoRange.configToken(TEST_NFT_2_A, AutoRange.PositionConfig(0, 0, 0, 60, uint64(Q64 / 100), uint64(Q64 / 100), false, MAX_REWARD)); // 1% max fee, 1% max slippage

        (, , , , , , , uint128 liquidity, , , , ) = NPM.positions(TEST_NFT_2_A);

        // in range position cant be adjusted
        vm.expectRevert(Automator.NotReady.selector);
        vm.prank(OPERATOR_ACCOUNT);
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT_2_A, false, 0, "", liquidity, 0, 0, block.timestamp, MAX_REWARD));
    }

    function testAdjustOutOfRange() external {
        vm.prank(TEST_NFT_2_ACCOUNT);
        NPM.setApprovalForAll(address(autoRange), true);

        vm.prank(TEST_NFT_2_ACCOUNT);
        autoRange.configToken(TEST_NFT_2, AutoRange.PositionConfig(0, 0, -int32(uint32(type(uint24).max)), int32(uint32(type(uint24).max)), 0, 0, false, MAX_REWARD)); // 1% max fee, 1% max slippage

        (, , , , , , , uint128 liquidity, , , , ) = NPM.positions(TEST_NFT_2);

        // will be reverted because range Arithmetic over/underflow
        vm.expectRevert(abi.encodePacked("SafeCast: value doesn't fit in 24 bits"));
        vm.prank(OPERATOR_ACCOUNT);
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT_2, false, 0, "", liquidity, 0, 0, block.timestamp, MAX_REWARD));
    }

    function testLiquidityChanged() external {
        vm.prank(TEST_NFT_2_ACCOUNT);
        NPM.setApprovalForAll(address(autoRange), true);

        vm.prank(TEST_NFT_2_ACCOUNT);
        autoRange.configToken(TEST_NFT_2, AutoRange.PositionConfig(0, 0, -int32(uint32(type(uint24).max)), int32(uint32(type(uint24).max)), 0, 0, false, MAX_REWARD)); // 1% max fee, 1% max slippage

        // will be reverted because LiquidityChanged
        vm.expectRevert(Automator.LiquidityChanged.selector);
        vm.prank(OPERATOR_ACCOUNT);
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT_2, false, 0, "", 0, 0, 0, block.timestamp, MAX_REWARD));
    }

    struct SwapTestState {
        uint protocolDAIBalanceBefore;
        uint protocolWETHBalanceBefore;
        uint ownerDAIBalanceBefore;
        uint ownerWETHBalanceBefore;
        uint tokenId;
        uint128 liquidity;
        uint256 amount0;
        uint256 amount1;
        address token0;
        address token1;
        uint24 fee;
        uint128 liquidityOld;
    }

    function testAdjustWithoutSwap(bool onlyFees) external {

        // using out of range position TEST_NFT_2
        // available amounts -> 311677619940061890346 506903060556612041
        // added to new position -> 778675263877745419944 196199406163820963
        
        SwapTestState memory state;

        vm.prank(TEST_NFT_2_ACCOUNT);
        NPM.setApprovalForAll(address(autoRange), true);

        vm.prank(TEST_NFT_2_ACCOUNT);
        autoRange.configToken(TEST_NFT_2, AutoRange.PositionConfig(0, 0, 0, 60, uint64(Q64 / 100), uint64(Q64 / 100), onlyFees, onlyFees ? MAX_FEE_REWARD : MAX_REWARD)); // 1% max fee, 1% max slippage
        uint count = NPM.balanceOf(TEST_NFT_2_ACCOUNT);
        assertEq(count, 4);

        state.protocolDAIBalanceBefore = DAI.balanceOf(address(autoRange));
        state.protocolWETHBalanceBefore = WETH_ERC20.balanceOf(address(autoRange));

        state.ownerDAIBalanceBefore = DAI.balanceOf(TEST_NFT_2_ACCOUNT);
        state.ownerWETHBalanceBefore = TEST_NFT_2_ACCOUNT.balance;

        (, , , , , , , state.liquidity, , , , ) = NPM.positions(TEST_NFT_2);


        // test max withdraw slippage
        vm.prank(OPERATOR_ACCOUNT);
        vm.expectRevert("Price slippage check");
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT_2, false, 0, "", state.liquidity, type(uint).max, type(uint).max, block.timestamp, MAX_REWARD));

        vm.prank(OPERATOR_ACCOUNT);
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT_2, false, 0, "", state.liquidity, 0, 0, block.timestamp, onlyFees ? MAX_FEE_REWARD: MAX_REWARD)); // max fee with 1% is 7124618988448545

        // is not adjustable yet because config was removed
        (, , , , , , , state.liquidity, , , , ) = NPM.positions(TEST_NFT_2);
        vm.prank(OPERATOR_ACCOUNT);
        vm.expectRevert(Automator.NotConfigured.selector);
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT_2, false, 0, "", state.liquidity, 0, 0, block.timestamp, onlyFees ? MAX_FEE_REWARD: MAX_REWARD));

        // protocol fee
        assertEq(DAI.balanceOf(address(autoRange)) - state.protocolDAIBalanceBefore, onlyFees ? 15583880997003094503 : 777250922543795237);
        assertEq(WETH_ERC20.balanceOf(address(autoRange)) - state.protocolWETHBalanceBefore, onlyFees ? 4948445849078767 : 193185163020990);

        // leftovers returned to owner
        assertEq(DAI.balanceOf(TEST_NFT_2_ACCOUNT) - state.ownerDAIBalanceBefore, onlyFees ? 0 : 1); // all was added to position
        assertEq(TEST_NFT_2_ACCOUNT.balance - state.ownerWETHBalanceBefore, onlyFees ? 428360726854687034 : 429435810185194946); // leftover + fee + deposited = total in old position


        count = NPM.balanceOf(TEST_NFT_2_ACCOUNT);
        assertEq(count, 5);

        // new NFT is latest NFT - because of the order they are added
        state.tokenId = NPM.tokenOfOwnerByIndex(TEST_NFT_2_ACCOUNT, count - 1);

        (, , , , , , , state.liquidity, , , , ) = NPM.positions(state.tokenId);

        // is not adjustable yet because in range
        vm.prank(OPERATOR_ACCOUNT);
        vm.expectRevert(Automator.NotReady.selector);
        autoRange.execute(AutoRange.ExecuteParams(state.tokenId, false, 0, "", state.liquidity, 0, 0, block.timestamp, onlyFees ? MAX_FEE_REWARD: MAX_REWARD));

        // newly minted token
        assertEq(state.tokenId, 309207);

        (, , , , , , , state.liquidity, , , , ) = NPM.positions(state.tokenId);
        (, , , , , int24 tickLowerAfter, int24 tickUpperAfter , , , , , ) = NPM.positions(state.tokenId);
        (, , state.token0 , state.token1 , state.fee , , , state.liquidityOld, , , , ) = NPM.positions(TEST_NFT_2);

        IUniswapV3Pool pool = IUniswapV3Pool(PoolAddress.computeAddress(FACTORY, PoolAddress.getPoolKey(state.token0, state.token1, state.fee)));
        (uint160 sqrtPriceX96, int24 currentTick,,,,,) = pool.slot0();

        (state.amount0,  state.amount1) = LiquidityAmounts.getAmountsForLiquidity(sqrtPriceX96, TickMath.getSqrtRatioAtTick(tickLowerAfter), TickMath.getSqrtRatioAtTick(tickUpperAfter), state.liquidity);

        // new position amounts
        assertEq(state.amount0, onlyFees ? 296093738943058795842 : 310900369017518095107); //DAI
        assertEq(state.amount1, onlyFees ? 73593887852846239 : 77274065208396104); //WETH

        // check tick range correct
        assertEq(tickLowerAfter, -73260);
        assertEq(currentTick,  -73244);
        assertEq(tickUpperAfter, -73260 + 60);

        assertEq(state.liquidity, onlyFees ? 3493233994488865101709 : 3667918618704675260835);
        assertEq(state.liquidityOld, 0);
    }

    function testAdjustWithTooLargeSwap() external {
        
        vm.prank(TEST_NFT_2_ACCOUNT);
        NPM.setApprovalForAll(address(autoRange), true);

        vm.prank(TEST_NFT_2_ACCOUNT);
        autoRange.configToken(TEST_NFT_2, AutoRange.PositionConfig(0, 0, 0, 60, uint64(Q64 / 100), uint64(Q64 / 100), false, MAX_REWARD)); // 1% max fee, 1% max slippage

        (, , , , , , , uint128 liquidity, , , , ) = NPM.positions(TEST_NFT_2);

        vm.expectRevert(AutoRange.SwapAmountTooLarge.selector);
        vm.prank(OPERATOR_ACCOUNT);
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT_2, false, type(uint).max, _get03WETHToDAISwapData(), liquidity, 0, 0, block.timestamp, MAX_REWARD));
    }

    function testAdjustWithSwap(bool onlyFees) external {

        SwapTestState memory state;

        // using out of range position TEST_NFT_2
        // available amounts -> DAI 311677619940061890346 WETH 506903060556612041
        // swapping 0.3 WETH -> DAI (so more can be added to new position) 
        // added to new position -> 782948862604141727748 194702024655849100
        
        vm.prank(TEST_NFT_2_ACCOUNT);
        NPM.setApprovalForAll(address(autoRange), true);

        vm.prank(TEST_NFT_2_ACCOUNT);
        autoRange.configToken(TEST_NFT_2, AutoRange.PositionConfig(0, 0, 0, 60, uint64(Q64 / 100), uint64(Q64 / 100), onlyFees, onlyFees ? MAX_FEE_REWARD : MAX_REWARD)); // 1% max fee, 1% max slippage
       
        state.protocolDAIBalanceBefore = DAI.balanceOf(address(autoRange));
        state.protocolWETHBalanceBefore = WETH_ERC20.balanceOf(address(autoRange));

        state.ownerDAIBalanceBefore = DAI.balanceOf(TEST_NFT_2_ACCOUNT);
        state.ownerWETHBalanceBefore = TEST_NFT_2_ACCOUNT.balance;

        (, , , , , , , state.liquidity, , , , ) = NPM.positions(TEST_NFT_2);

        vm.prank(OPERATOR_ACCOUNT);
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT_2, false, 300000000000000000, _get03WETHToDAISwapData(), state.liquidity, 0, 0, block.timestamp, onlyFees ? MAX_FEE_REWARD : MAX_REWARD)); // max fee with 1% is 7124618988448545

        // protocol fee
        assertEq(DAI.balanceOf(address(autoRange)) - state.protocolDAIBalanceBefore, onlyFees ? 15583880997003094503 : 1913211476963758022);
        assertEq(WETH_ERC20.balanceOf(address(autoRange)) - state.protocolWETHBalanceBefore, onlyFees ? 4948445849078767 : 475527349470656);

        // leftovers returned to owner
        assertEq(DAI.balanceOf(TEST_NFT_2_ACCOUNT) - state.ownerDAIBalanceBefore, onlyFees ? 0 : 1);
        assertEq(TEST_NFT_2_ACCOUNT.balance - state.ownerWETHBalanceBefore, onlyFees ? 15141510088371046 : 16216593418878959);

        uint count = NPM.balanceOf(TEST_NFT_2_ACCOUNT);

        // new NFT is latest NFT - because of the order they are added
        state.tokenId = NPM.tokenOfOwnerByIndex(TEST_NFT_2_ACCOUNT, count - 1);

        // newly minted token
        assertEq(state.tokenId, 309207);

        (, , , , , , , state.liquidity, , , , ) = NPM.positions(state.tokenId);
        (, , , , , int24 tickLowerAfter, int24 tickUpperAfter , , , , , ) = NPM.positions(state.tokenId);
        (, , state.token0 , state.token1 , state.fee , , , state.liquidityOld, , , , ) = NPM.positions(TEST_NFT_2);

        IUniswapV3Pool pool = IUniswapV3Pool(PoolAddress.computeAddress(FACTORY, PoolAddress.getPoolKey(state.token0, state.token1, state.fee)));
        (uint160 sqrtPriceX96, int24 currentTick,,,,,) = pool.slot0();

        (state.amount0, state.amount1) = LiquidityAmounts.getAmountsForLiquidity(sqrtPriceX96, TickMath.getSqrtRatioAtTick(tickLowerAfter), TickMath.getSqrtRatioAtTick(tickUpperAfter), state.liquidity);

        // new position amounts
        assertEq(state.amount0, onlyFees ? 751613921265463873195 : 765284590785503209675); //DAI
        assertEq(state.amount1, onlyFees ? 186813104619162227 : 190210939788262425); //WETH

        // check tick range correct
        assertEq(tickLowerAfter, -73260);
        assertEq(currentTick,  -73244);
        assertEq(tickUpperAfter, -73260 + 60);

        assertEq(state.liquidity, onlyFees ? 8867338126999411584017 : 9028620995273798933977);
        assertEq(state.liquidityOld, 0);
    }

    function testDoubleAdjust() external {
                
        vm.prank(TEST_NFT_2_ACCOUNT);
        NPM.setApprovalForAll(address(autoRange), true);

        // bad config so it can be adjusted multiple times
        vm.prank(TEST_NFT_2_ACCOUNT);
        autoRange.configToken(TEST_NFT_2, AutoRange.PositionConfig(-100000, -100000, 0, 60, uint64(Q64 / 100), uint64(Q64 / 100), false, MAX_REWARD));

        (, , , , , , , uint128 liquidity, , , , ) = NPM.positions(TEST_NFT_2);

        // first adjust ok
        vm.prank(OPERATOR_ACCOUNT);
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT_2, false, 0, "", liquidity, 0, 0, block.timestamp, 0));

        uint count = NPM.balanceOf(TEST_NFT_2_ACCOUNT);
        uint tokenId = NPM.tokenOfOwnerByIndex(TEST_NFT_2_ACCOUNT, count - 1);

        // newly minted token
        assertEq(tokenId, 309207);

        (, , , , , , , liquidity, , , , ) = NPM.positions(tokenId);

        // second ajust leads to same range error
        vm.prank(OPERATOR_ACCOUNT);
        vm.expectRevert(AutoRange.SameRange.selector);
        autoRange.execute(AutoRange.ExecuteParams(tokenId, false, 0, "", liquidity, 0, 0, block.timestamp, 0));
    }

    function testOracleCheck() external {

        // create range adjustor with more strict oracle config    
        autoRange = new AutoRange(NPM, OPERATOR_ACCOUNT, WITHDRAWER_ACCOUNT, 60 * 30, 4, _getSwapRouterOptions());

        vm.prank(TEST_NFT_2_ACCOUNT);
        NPM.setApprovalForAll(address(autoRange), true);

        vm.prank(TEST_NFT_2_ACCOUNT);
        autoRange.configToken(TEST_NFT_2, AutoRange.PositionConfig(-100000, -100000, 0, 60, uint64(Q64 / 100), uint64(Q64 / 100), false, MAX_REWARD));

        (, , , , , , , uint128 liquidity, , , , ) = NPM.positions(TEST_NFT_2);

        // TWAPCheckFailed
        vm.prank(OPERATOR_ACCOUNT);
        vm.expectRevert(Automator.TWAPCheckFailed.selector);
        autoRange.execute(AutoRange.ExecuteParams(TEST_NFT_2, false, 0, "", liquidity, 0, 0, block.timestamp, 0));
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