// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/V3Automation.sol";

abstract contract CommonScript is Script {
    address krystalRouter;
    address admin;
    address withdrawer;
    bytes32 salt = keccak256("KRYSTAL_DEPLOYMENT_SALT");
    address factory = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    constructor() {
        krystalRouter = vm.envAddress("KRYSTAL_ROUTER");
        admin = vm.envAddress("ADMIN_ADDRESS");
        withdrawer = vm.envAddress("WITHDRAWER");
        console.log("KRYSTAL_ROUTER: ", krystalRouter);
        console.log("ADMIN_ADDRESS: ", admin);
        console.log("WITHDRAWER: ", withdrawer);
    }
}
