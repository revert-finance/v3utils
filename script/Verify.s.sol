// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./Common.s.sol";

contract VerifyV3UtilsScript is CommonScript {
    function run() view external {
        address deploymentAddress = getV3UtilsDeploymentAddress();
        console.log("deployment address: ", deploymentAddress);
        console.log("\nrun script below to verify contract: \n");
        console.log(
            string.concat(
                "forge verify-contract ", 
                Strings.toHexString(deploymentAddress),
                " src/V3Utils.sol:V3Utils"
            )
        );    
    }

    function test() external {}
}

contract VerifyV3AutomationScript is CommonScript {
    function run() view external {
        address deploymentAddress = getV3AutomationDeploymentAddress();
        console.log("deployment address: ", deploymentAddress);
        console.log("\nrun script below to verify contract: \n");
        console.log(
            string.concat(
                "forge verify-contract ", 
                Strings.toHexString(deploymentAddress),
                " src/V3Automation.sol:V3Automation"
            )
        );    
    }

    function test() external {}
}
