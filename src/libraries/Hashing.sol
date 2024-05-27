// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Hashing
/// @notice Hashing handles Domicon's various different hashing schemes.
library Hashing {


    function hashCommitment(uint256 _x,uint256 _y) internal pure returns(bytes32){
        return keccak256(
            abi.encode(
                _x,
                _y
            )
        );
    }

    /// @notice Used for computing the overall commitment state hash $r_i=H(cm_i||addr_i||r_{i-1})$
    function hashCommitmentRoot(uint256 _x,uint256 _y,address _target,bytes32 _committeeHash) internal pure returns(bytes32){
        return keccak256(
            abi.encode(
                _x,
                _y,
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
    function hashData(address _target,uint64 _index,uint64 _length,uint256 _x,uint256 _y) internal view returns (bytes32) {
        uint64 _chainId;
        assembly {
            _chainId := chainid()
        }
        bytes memory data = abi.encode(
            _chainId,
            _target,
            _index,
            _length,
            _x,
            _y
        );
        return keccak256(data);
    }

    function hashFold(uint _r,uint _n) internal pure returns (bytes32) {
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
