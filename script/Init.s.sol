// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Common.s.sol";
import "../src/V3Automation.sol";
import "../src/V3Utils.sol";
import "@openzeppelin/contracts/utils/Create2.sol";

// NOTE: This script is use when deploy transaction is made but initialization is not

interface IV3Initializer {
    function initialize(address _swapRouter, address admin, address withdrawer, address feeTaker, address[] calldata nfpms) external;
}

contract V3AutomationInitializeScript is CommonScript {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deploymentAddress = getV3AutomationDeploymentAddress();

        vm.startBroadcast(deployerPrivateKey);
        IV3Initializer v3automation = IV3Initializer(deploymentAddress);
        v3automation.initialize(krystalRouter, admin, withdrawer, vm.envAddress("FEE_TAKER"), vm.envAddress("NFPMS", ","));

        vm.stopBroadcast();
    }

    function test() external {}
}

contract V3UtilsInitializeScript is CommonScript {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deploymentAddress = getV3UtilsDeploymentAddress();

        vm.startBroadcast(deployerPrivateKey);
        IV3Initializer v3utils = IV3Initializer(deploymentAddress);
        v3utils.initialize(krystalRouter, admin, withdrawer, vm.envAddress("FEE_TAKER"), vm.envAddress("NFPMS", ","));

        vm.stopBroadcast();
    }

    function test() external {}
}
