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

    IERC20 constant WETH_ERC20 = IERC20(0x4200000000000000000000000000000000000006);
    IERC20 constant USDC = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607); // USDC.e
    IERC20 constant DAI = IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);


    INonfungiblePositionManager constant NPM = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    address EX0x = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF; // 0x exchange proxy
    address UNIVERSAL_ROUTER = 0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD; // uniswap universal router
    address UNISWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564; // uniswap router 1.0
    address KRYSTAL_ROUTER = 0xf6f2dafa542FefAae22187632Ef30D2dAa252b4e;

    // USDC.e/DAI 0.01% - one sided only DAI - current tick is near -276326 - no liquidity (-276320/-276310)
    uint256 constant TEST_NFT = 24181;
    address constant TEST_NFT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address constant TEST_NFT_POOL = 0xbf16ef186e715668AA29ceF57e2fD7f9D48AdFE6;

    // DAI/USDC 0.05% - in range - with liquidity and fees
    uint256 constant TEST_NFT_3 = 4660; 
    address constant TEST_NFT_3_ACCOUNT = 0xa3eF006a7da5BcD1144d8BB86EfF1734f46A0c1E;
    address constant TEST_NFT_3_POOL = 0x6c6Bc977E13Df9b0de53b251522280BB72383700;

    // DAI/USDC 0.05% - in range - with liquidity and fees
    uint constant TEST_NFT_5 = 23901;
    address constant TEST_NFT_5_ACCOUNT = 0x082d3e0f04664b65127876e9A05e2183451c792a;


    address constant TEST_FEE_ACCOUNT = 0x8df57E3D9dDde355dCE1adb19eBCe93419ffa0FB;

    address constant DAI_HOLDER = 0x1eED63EfBA5f81D95bfe37d82C8E736b974F477b;

    uint256 mainnetFork;

    V3Utils v3utils;

    function _setupBase() internal {

        mainnetFork = vm.createFork("https://optimism.blockpi.network/v1/rpc/ea13fb164ec00d953327e733a13d9aaea5ec8325", 114896040);
        vm.selectFork(mainnetFork);

        v3utils = new V3Utils(NPM, KRYSTAL_ROUTER);
    }  

    function _getSwapRouterOptions() internal returns (address[] memory swapRouterOptions) {
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