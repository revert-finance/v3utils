// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../IntegrationTestBase.sol";

contract CommonTest is IntegrationTestBase {
    function setUp() external {
        _setupBase();
    }

    function testSetWhitelistNfpmInvalidRole() external {
        (address userAddress,) = makeAddrAndKey("random user 1");
        vm.prank(userAddress);
        vm.expectRevert();
        address[] memory nfpms;
        nfpms[0] = userAddress;
        v3utils.setWhitelistNfpm(nfpms, true);
    }

    function testSetWhitelistNfpmSuccess() external {
        vm.prank(TEST_OWNER_ACCOUNT);

        address camelotNfpm = 0x00c7f3082833e796A5b3e4Bd59f6642FF44DCD15;
        address[] memory nfpms = new address[](1);
        nfpms[0] = camelotNfpm;
        v3utils.setWhitelistNfpm(nfpms, true);
        assertTrue(true);
    }

    function testWithdrawERC20InvalidRole() external {
        (address userAddress,) = makeAddrAndKey("random user 1");
        uint256 balance = 1000000;
        _writeTokenBalance(address(v3utils), address(USDC), balance);
        vm.prank(userAddress);
        vm.expectRevert();
        IERC20[] memory erc20;
        v3utils.withdrawERC20(erc20, userAddress);
    }

    function testWithdrawErc20() external {
        uint256 balance = 1000000;
        uint256 balanceBefore = USDC.balanceOf(TEST_OWNER_ACCOUNT);
        _writeTokenBalance(address(v3utils), address(USDC), balance);
        vm.prank(TEST_OWNER_ACCOUNT);
        IERC20[] memory erc20 = new IERC20[](1);
        erc20[0] = USDC;
        v3utils.withdrawERC20(erc20, TEST_OWNER_ACCOUNT);

        uint256 balanceAfter = USDC.balanceOf(TEST_OWNER_ACCOUNT);
        uint256 balanceV3Utils = USDC.balanceOf(address(v3utils));
        assertEq(balanceV3Utils, 0);
        assertEq(balanceAfter, balanceBefore + balance);
    }

    function testWithdrawNative() external {
        uint256 balanceBefore = address(TEST_OWNER_ACCOUNT).balance;
        vm.deal(address(v3utils), 1 ether);
        vm.prank(TEST_OWNER_ACCOUNT);

        v3utils.withdrawNative(TEST_OWNER_ACCOUNT);

        uint256 balanceAfter = address(TEST_OWNER_ACCOUNT).balance;
        assertEq(balanceAfter, balanceBefore + 1 ether);
    }
}
