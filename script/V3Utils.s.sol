// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/V3Utils.sol";

contract MyScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address KRYSTAL_ROUTER = 0x864F01c5E46b0712643B956BcA607bF883e0dbC5;
        V3Utils v3Utils = new V3Utils(KRYSTAL_ROUTER);

        vm.stopBroadcast();
    }
}
