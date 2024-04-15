// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Create2.sol";
import "forge-std/Script.sol";
import "../src/V3Utils.sol";


contract MyScript is Script {
    bytes32 salt = keccak256("KRYSTAL_DEPLOYMENT_SALT");
    address factory = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address initOwner = vm.envAddress("OWNER");
        address krystalRouter = vm.envAddress("KRYSTAL_ROUTER");

        vm.startBroadcast(deployerPrivateKey);

        V3Utils v3Utils = new V3Utils{
            salt: salt
        }(krystalRouter, initOwner);

        vm.stopBroadcast();

        address deploymentAddress = Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(V3Utils).creationCode,
                    abi.encode(krystalRouter, initOwner)
                )
            ),
            factory
        );
        // forge verify-contract 0xfaacd9f7e68bb36c1029ab87d1d7325919e67cc0 src/V3Utils.sol:V3Utils --constructor-args $(cast abi-encode "constructor(address)" "0x70270C228c5B4279d1578799926873aa72446CcD")
        console.log("\nrun script below to verify contract: \n");
        console.log("forge verify-contract ", deploymentAddress, "src/V3Utils.sol:V3Utils --constructor-args $(cast abi-encode \"constructor(address,address)\" $KRYSTAL_ROUTER $OWNER) \n\n");
    }
}
