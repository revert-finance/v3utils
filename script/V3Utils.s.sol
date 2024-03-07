// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/V3Utils.sol";

contract MyScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address KRYSTAL_ROUTER = 0x70270C228c5B4279d1578799926873aa72446CcD;
        V3Utils v3Utils = new V3Utils(KRYSTAL_ROUTER);

        vm.stopBroadcast();
    }
}
