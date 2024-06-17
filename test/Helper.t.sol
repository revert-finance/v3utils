pragma solidity ^0.8.0;

import "../src/V3Automation.sol";

contract V3AutomationHarness is V3Automation {
    function hash(Order memory obj) external pure returns (bytes32) {
        return super._hash(obj);
    }

    function hashTypedDataV4(bytes32 structHash) external view virtual returns (bytes32) {
        return super._hashTypedDataV4(structHash);
    }

    function getTypedDataHash(bytes32 domainSeparator, bytes32 structHash) external pure returns (bytes32 digest) {
        return super.toTypedDataHash(domainSeparator, structHash);
    }

    struct Permit {
        address spender;
        uint256 tokenId;
        uint256 nonce;
        uint256 deadline;
    }

    bytes32 public constant NFPM_PERMIT_TYPEHASH =
        0x49ecf333e5b8c95c40fdafc95c1ad136e8914a8fb55e9dc8bb01eaa83a2df9ad;
    // keccak256("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)")

    function hash(Permit memory obj) external pure returns (bytes32) {
        return keccak256(abi.encode(
            NFPM_PERMIT_TYPEHASH,
            obj.spender,
            obj.tokenId,
            obj.nonce,
            obj.deadline
        ));
    }
}
