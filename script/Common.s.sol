// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/V3Automation.sol";

abstract contract CommonScript is Script {
    uint256 deployerPrivateKey; 
    address krystalRouter;
    address withdrawer;

    constructor() {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        krystalRouter = vm.envAddress("KRYSTAL_ROUTER");
        if (krystalRouter == address(0)) {
            revert();
        }
        withdrawer = vm.envAddress("WITHDRAWER");
        if (withdrawer == address(0)) {
            revert();
        }
    }
}
