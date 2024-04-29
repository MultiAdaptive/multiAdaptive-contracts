// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Hashing
/// @notice Hashing handles Domicon's various different hashing schemes.
library Hashing {

    /// @notice Used for computing the overall commitment state hash $r_i=H(cm_i||addr_i||r_{i-1})$
    function hashCommitment(bytes calldata _commitment,address _target,bytes32 _committeeHash) internal pure returns(bytes32){
        return keccak256(
            abi.encode(
                _commitment,
                _target,
                _committeeHash
            )
        );
    }

    /// @notice Used for generating a hash corresponding to a set of broadcast node addresses
    function hashAddresses(address _sender,address[] memory _addresses) internal pure returns (bytes32) {
        return keccak256(abi.encode(_sender,_addresses));
    }

    function hashSignatures(bytes[] calldata _signatures) internal pure returns (bytes32){
        return keccak256(abi.encode(_signatures));
    }

    /// @notice Used for generating a signature hash.
    function hashData(address _user,address _submiter,uint64 _index,uint64 _length,bytes memory _commit) internal view returns (bytes32) {
        uint64 _chainId;
        assembly {
            _chainId := chainid()
        }
        bytes memory data = abi.encode(
            _chainId,
            _user,
            _submiter,
            _index,
            _length,
            _commit
        );
        return keccak256(data);
    }

    function hashFold(uint _r,uint _n) internal view returns (bytes32) {
        return keccak256(abi.encode(_r,_n));
    }

    /// @notice Verify Signature.
    function verifySignature(bytes32 _dataHash, bytes memory signature,address _sender) internal pure returns (bool) {
        require(signature.length == 65, "Invalid signature length");
        uint8 v;
        bytes32 r;
        bytes32 s;
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        address signer = ecrecover(_dataHash, v, r, s);
        require(signer != address(0),"address is not avaible");
        return signer == _sender;
    }
}
