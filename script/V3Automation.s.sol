// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Common.s.sol";
import "../src/V3Automation.sol";

contract V3AutomationScript is CommonScript {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        V3Automation v3automation = new V3Automation{
            salt: salt
        }(krystalRouter, admin, withdrawer);

        vm.stopBroadcast();
    }
}
