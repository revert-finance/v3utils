// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/V3Utils.sol";


contract MyScript is Script {
    bytes32 salt = keccak256("KRYSTAL_DEPLOYMENT_SALT");
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address initOwner = vm.envAddress("OWNER");
        address krystalRouter = vm.envAddress("KRYSTAL_ROUTER");

        vm.startBroadcast(deployerPrivateKey);

        V3Utils v3Utils = new V3Utils{
            salt: salt
        }(krystalRouter, initOwner);

        vm.stopBroadcast();
    }
}
