// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Common.s.sol";
import "../src/V3Automation.sol";

contract V3AutomationScript is CommonScript {
    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        V3Automation v3automation = new V3Automation(krystalRouter, withdrawer);

        vm.stopBroadcast();
    }
}
