// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/V3Automation.sol";

contract V3AutomationScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address KRYSTAL_ROUTER = 0x864F01c5E46b0712643B956BcA607bF883e0dbC5;
        V3Automation v3automation = new V3Automation(KRYSTAL_ROUTER, 0x04Ff397401AF494d68848FCaa4c78dCa785d33FC);

        vm.stopBroadcast();
    }
}
