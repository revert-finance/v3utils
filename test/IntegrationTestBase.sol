// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/V3Utils.sol";
import "../src/V3Automation.sol";


abstract contract IntegrationTestBase is Test {
    using stdStorage for StdStorage;

    int24 constant MIN_TICK_100 = -887272;
    int24 constant MIN_TICK_500 = -887270;

    IERC20 constant WETH_ERC20 = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 constant USDC = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8); // USDC.e
    IERC20 constant DAI = IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);


    INonfungiblePositionManager constant NPM = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    address EX0x = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF; // 0x exchange proxy
    address UNIVERSAL_ROUTER = 0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD; // uniswap universal router
    address KRYSTAL_ROUTER = 0x864F01c5E46b0712643B956BcA607bF883e0dbC5;

    // DAI/USDC.e 0.05% - one sided only DAI - current tick is near -276326 - no liquidity (-276320/-276310)
    uint256 constant TEST_NFT = 14518;
    address constant TEST_NFT_ACCOUNT = 0xa85da96711e60D4CAe5EA043452B7F4F8BfF77fa;
    address constant TEST_NFT_POOL = 0xd37Af656Abf91c7f548FfFC0133175b5e4d3d5e6;

    // // DAI/USDC.e  0.05% - in range - with liquidity and fees > 1 DAI
    uint256 constant TEST_NFT_3 = 457995; 
    address constant TEST_NFT_3_ACCOUNT = 0x96fFc054fdfce8A815d126D427bcFCD6A46373bd;
    address constant TEST_NFT_3_POOL = 0xd37Af656Abf91c7f548FfFC0133175b5e4d3d5e6;

    // DAI/USDC 0.05% - in range - with liquidity and fees
    uint constant TEST_NFT_5 = 1003543;
    address constant TEST_NFT_5_ACCOUNT = 0x9C2Bdc7Ff2b43d8d7Ec21A3C5aAeb35C9fb5ABC2;


    address constant TEST_FEE_ACCOUNT = 0x864F01c5E46b0712643B956BcA607bF883e0dbC5;
    address constant TEST_OWNER_ACCOUNT = 0x9f8F14D05fe689651Ee77aD26AF693DF7333692E;

    // address constant DAI_HOLDER = 0x1eED63EfBA5f81D95bfe37d82C8E736b974F477b;

    uint256 mainnetFork;

    V3Utils v3utils;
    V3Automation v3automation;

    function _setupBase() internal {

        mainnetFork = vm.createFork("https://rpc.ankr.com/arbitrum", 171544977);
        vm.selectFork(mainnetFork);

        v3utils = new V3Utils(KRYSTAL_ROUTER, TEST_OWNER_ACCOUNT, TEST_OWNER_ACCOUNT);
        v3automation = new V3Automation(KRYSTAL_ROUTER, TEST_OWNER_ACCOUNT, TEST_OWNER_ACCOUNT);
    }

    function _writeTokenBalance(address who, address token, uint256 amt) internal {
        stdstore
            .target(token)
            .sig(IERC20(token).balanceOf.selector)
            .with_key(who)
            .checked_write(amt);
    }

    function _increaseLiquidity()
        internal returns (uint128 liquidity)
    {
        _writeTokenBalance(TEST_NFT_ACCOUNT, address(DAI), 1000000000000000000);

        Common.SwapAndIncreaseLiquidityParams memory params = Common
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
                0,
                0
            );

        uint256 balanceBefore = DAI.balanceOf(TEST_NFT_ACCOUNT);

        vm.startPrank(TEST_NFT_ACCOUNT);
        DAI.approve(address(v3utils), 1000000000000000000);
        Common.SwapAndIncreaseResult memory result = v3utils.swapAndIncreaseLiquidity(params);
        vm.stopPrank();
        liquidity = result.liquidity;
        uint256 balanceAfter = DAI.balanceOf(TEST_NFT_ACCOUNT);

        // uniswap sometimes adds not full balance (this tests that leftover tokens were returned correctly)
        assertEq(balanceBefore - balanceAfter, 999999999999998821);

        assertEq(result.liquidity, 500625938064039);
        assertEq(result.added0, 999999999999998821); // added amount
        assertEq(result.added1, 0); // only added on one side

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