// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Create2.sol";
import "../src/V3Utils.sol";
import "../src/V3Automation.sol";
import "./Common.s.sol";

contract VerifyV3UtilsScript is CommonScript {
    function run() external {
        address deploymentAddress = Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(V3Utils).creationCode,
                    abi.encode(krystalRouter, admin, withdrawer)
                )
            ),
            factory
        );
        console.log("deployment address: ", deploymentAddress);
        console.log("\nrun script below to verify contract: \n");
        console.log("forge verify-contract ", deploymentAddress, "src/V3Utils.sol:V3Utils --constructor-args $(cast abi-encode \"constructor(address,address,address)\" $KRYSTAL_ROUTER $ADMIN_ADDRESS $WITHDRAWER) \n\n");    
    }
}

contract VerifyV3AutomationScript is CommonScript {
    function run() external {
        address deploymentAddress = Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(V3Automation).creationCode,
                    abi.encode(krystalRouter, admin, withdrawer)
                )
            ),
            factory
        );
        console.log("deployment address: ", deploymentAddress);
        console.log("\nrun script below to verify contract: \n");
        console.log("forge verify-contract ", deploymentAddress, "src/V3Automation.sol:V3Automation --constructor-args $(cast abi-encode \"constructor(address,address,address)\" $KRYSTAL_ROUTER $ADMIN_ADDRESS $WITHDRAWER) \n\n");
    }
}