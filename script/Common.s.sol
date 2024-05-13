// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/V3Automation.sol";
import "../src/V3Utils.sol";
import "@openzeppelin/contracts/utils/Create2.sol";

abstract contract CommonScript is Script {
    address krystalRouter;
    address admin;
    address withdrawer;
    bytes32 salt;
    address factory = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function getV3UtilsDeploymentAddress() internal view returns(address) {
        return Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(V3Utils).creationCode
                )
            ),
            factory
        );
    }

    function getV3AutomationDeploymentAddress() internal view returns(address) {
        return Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(V3Automation).creationCode
                )
            ),
            factory
        );
    }

    constructor() {
        salt = keccak256(bytes(vm.envString("SALT_SEED")));
        krystalRouter = vm.envAddress("KRYSTAL_ROUTER");
        admin = vm.envAddress("WITHDRAWER"); // for now, admin is the withdrawer
        withdrawer = vm.envAddress("WITHDRAWER");
        console.log("SALT:");
        console.logBytes32(salt);
        console.log("KRYSTAL_ROUTER: ", krystalRouter);
        console.log("ADMIN_ADDRESS: ", admin);
        console.log("WITHDRAWER: ", withdrawer);
    }
}
