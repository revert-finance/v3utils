// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Common.s.sol";
import "../src/V3Utils.sol";

contract V3UtilsScript is CommonScript {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        V3Utils v3Utils = new V3Utils{
            salt: salt
        }(krystalRouter, admin, withdrawer);

        vm.stopBroadcast();
    }
}
