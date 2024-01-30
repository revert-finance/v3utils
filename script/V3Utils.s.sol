// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/V3Utils.sol";

contract MyScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        INonfungiblePositionManager NPM = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
        address KRYSTAL_ROUTER = 0x864F01c5E46b0712643B956BcA607bF883e0dbC5;

        V3Utils v3Utils = new V3Utils(NPM, KRYSTAL_ROUTER);

        vm.stopBroadcast();
    }
}
