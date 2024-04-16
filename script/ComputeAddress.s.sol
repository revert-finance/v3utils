// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Create2.sol";
import "forge-std/Script.sol";
import "../src/V3Utils.sol";

contract VerifyV3UtilsScript is Script {
    bytes32 salt = keccak256("KRYSTAL_DEPLOYMENT_SALT");
    address factory = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    function run() external {
        address initOwner = vm.envAddress("WITHDRAWER");
        address krystalRouter = vm.envAddress("KRYSTAL_ROUTER");
        console.log("WITHDRAWER: ", initOwner, " KRYSTAL_ROUTER: ", krystalRouter);
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
        console.log("\nrun script below to verify contract: \n");
        console.log("forge verify-contract ", deploymentAddress, "src/V3Utils.sol:V3Utils --constructor-args $(cast abi-encode \"constructor(address,address)\" $KRYSTAL_ROUTER $WITHDRAWER) \n\n");
    }
}