// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Common.s.sol";
import "../src/V3Utils.sol";

contract V3UtilsScript is CommonScript {
    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        V3Utils v3Utils = new V3Utils(krystalRouter, withdrawer);

        vm.stopBroadcast();
    }
}
