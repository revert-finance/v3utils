// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/V3Utils.sol";
import "ds-test/test.sol";


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
    address UNISWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564; // uniswap router 1.0
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

    // address constant DAI_HOLDER = 0x1eED63EfBA5f81D95bfe37d82C8E736b974F477b;

    uint256 mainnetFork;

    V3Utils v3utils;

    function _setupBase() internal {

        mainnetFork = vm.createFork("https://rpc.ankr.com/arbitrum", 171544977);
        vm.selectFork(mainnetFork);

        v3utils = new V3Utils(KRYSTAL_ROUTER, TEST_FEE_ACCOUNT);
    }  

    function _getSwapRouterOptions() internal view returns (address[] memory swapRouterOptions) {
        swapRouterOptions = new address[](3);
        swapRouterOptions[0] = EX0x;
        swapRouterOptions[1] = UNIVERSAL_ROUTER;
        swapRouterOptions[2] = UNISWAP_ROUTER;
    }

    function _writeTokenBalance(address who, address token, uint256 amt) internal {
        stdstore
            .target(token)
            .sig(IERC20(token).balanceOf.selector)
            .with_key(who)
            .checked_write(amt);
    }
}