// SPDX-License-Identifier: MIT
// modified version of @openzeppelin
pragma solidity ^0.8.20;

abstract contract EIP712 {
    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 private immutable _cachedDomainSeparator;

    constructor(string memory name, string memory version) {
        _cachedDomainSeparator = keccak256(
            abi.encode(
                TYPE_HASH, 
                keccak256(bytes(name)), 
                keccak256(bytes(version)), 
                block.chainid, 
                address(this)
            )
        );
    }

    /**
     * @dev Returns the domain separator for the current chain.
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        return _cachedDomainSeparator;
    }

    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return toTypedDataHash(_domainSeparatorV4(), structHash);
    }

    /**
     * @dev Returns the keccak256 digest of an EIP-712 typed data (EIP-191 version `0x01`).
     *
     * The digest is calculated from a `domainSeparator` and a `structHash`, by prefixing them with
     * `\x19\x01` and hashing the result. It corresponds to the hash signed by the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`] JSON-RPC method as part of EIP-712.
     *
     * See {ECDSA-recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32 digest) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, hex"19_01")
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            digest := keccak256(ptr, 0x42)
        }
    }
}
