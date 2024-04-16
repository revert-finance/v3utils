// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/V3Utils.sol";


contract V3UtilsScript is Script {
    bytes32 salt = keccak256("KRYSTAL_DEPLOYMENT_SALT");
    address factory = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address withdrawer = vm.envAddress("WITHDRAWER");
        address krystalRouter = vm.envAddress("KRYSTAL_ROUTER");

        vm.startBroadcast(deployerPrivateKey);

        V3Utils v3Utils = new V3Utils{
            salt: salt
        }(krystalRouter, withdrawer);

        vm.stopBroadcast();
    }
}
