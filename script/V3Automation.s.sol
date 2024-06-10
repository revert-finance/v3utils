// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Common.s.sol";

contract V3AutomationScript is CommonScript {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        V3Automation v3automation = new V3Automation{
            salt: salt
        }();

        vm.stopBroadcast();
    }

    function test() external {}
}
