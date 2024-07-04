// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Hashing
/// @notice Hashing handles MultiAdaptive's various different hashing schemes.
library Hashing {
    function hashCommitment(uint256 _x, uint256 _y) internal pure returns (bytes32) {
        return keccak256(abi.encode(_x, _y));
    }

    /// @notice Used for generating a hash corresponding to a set of broadcast node addresses
    function hashAddresses(
        uint256 _requiredAmountOfSignatures,
        address[] memory _addresses
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_requiredAmountOfSignatures, _addresses));
    }

    function hashAddresses(address _creator, address[] memory _addresses) internal pure returns (bytes32) {
        return keccak256(abi.encode(_creator, _addresses));
    }

    function hashSignatures(bytes[] calldata _signatures) internal pure returns (bytes32) {
        return keccak256(abi.encode(_signatures));
    }

    /// @notice Used for generating a signature hash.
    function hashData(
        address _target,
        uint256 _index,
        uint256 _length,
        uint256 _timeout,
        uint256 _x,
        uint256 _y
    )
        internal
        view
        returns (bytes32)
    {
        uint64 _chainId;
        assembly {
            _chainId := chainid()
        }
        bytes memory data = abi.encode(_chainId, _target, _index, _length, _timeout, _x, _y);
        return keccak256(data);
    }

    function hashFold(uint256 _r, uint256 _n) internal pure returns (bytes32) {
        return keccak256(abi.encode(_r, _n));
    }
}
