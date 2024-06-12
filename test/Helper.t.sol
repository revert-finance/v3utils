pragma solidity ^0.8.0;

import "../src/V3Automation.sol";

contract V3AutomationHarness is V3Automation {
    function hash(Order memory obj) external pure returns (bytes32) {
        return super._hash(obj);
    }

    function hashTypedDataV4(bytes32 structHash) external view virtual returns (bytes32) {
        return super._hashTypedDataV4(structHash);
    }
}
