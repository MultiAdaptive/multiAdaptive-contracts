// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { ISemver } from "src/universal/ISemver.sol";
import { NodeManager } from "src/NodeManager.sol";
import { StorageManager, NodeGroup, NameSpace } from "src/StorageManager.sol";
import { Hashing } from "src/libraries/Hashing.sol";
import { Pairing } from "src/kzg/Pairing.sol";

/// @title CommitmentManager
/// @notice This contract manages DA data commitments, including the submission of commitments,
/// verification of signatures from broadcast nodes, and storage of related data.
contract CommitmentManager is Initializable, ISemver, Ownable {
    struct DADetails {
        uint256 timestamp;
        bytes32 hashSignatures;
    }

    /// @notice Semantic version.
    /// @custom:semver 0.1.0
    string public constant version = "0.1.0";

    /// @notice Nonce for the next commitment to be submitted.
    uint256 public nonce;

    /// @notice Node Manager contract.
    NodeManager public nodeManager;

    /// @notice Storage Manager contract.
    StorageManager public storageManagement;

    /// @notice Mapping of user address and index to their commitments.
    mapping(address => mapping(uint256 => Pairing.G1Point)) public userCommitments;

    /// @notice Mapping of namespace Key and index to namespace commitments.
    mapping(bytes32 => mapping(uint256 => Pairing.G1Point)) public nameSpaceCommitments;

    /// @notice The next index of the commitment submitted by the user.
    mapping(address => uint256) public indices;

    mapping(bytes32 => uint256) public nameSpaceIndex;

    /// @notice Mapping of nonce to commitments.
    mapping(uint256 => Pairing.G1Point) public commitments;

    /// @notice Mapping of commitment hash to DADetails.
    mapping(bytes32 => DADetails) public daDetails;

    /// @notice Event emitted when a DA commitment is sent.
    event SendDACommitment(
        Pairing.G1Point commitment,
        uint256 timestamp,
        uint256 nonce,
        uint256 index,
        uint256 len,
        bytes32 nodeGroupKey,
        bytes32 nameSpaceKey,
        bytes[] signatures
    );

    /// @notice Constructs the CommitmentManager contract.
    constructor() { }

    /// @notice Initializer function to set up the contract with NodeManager and StorageManager.
    /// @param _nodeManager Address of the NodeManager contract.
    /// @param _storageManagement Address of the StorageManager contract.
    function initialize(NodeManager _nodeManager, StorageManager _storageManagement) public initializer {
        nodeManager = _nodeManager;
        storageManagement = _storageManagement;
        _transferOwnership(tx.origin);
    }

    /// @notice Submit a new DA commitment.
    /// @param _length Length of the data.
    /// @param _timeout Commitment timeout.
    /// @param _nameSpaceKey Key of the namespace.
    /// @param _nodeGroupKey Key of the node group.
    /// @param _signatures Array of signatures from broadcast nodes.
    /// @param _commitment The commitment data.
    function submitCommitment(
        uint256 _length,
        uint256 _timeout,
        bytes32 _nameSpaceKey,
        bytes32 _nodeGroupKey,
        bytes[] calldata _signatures,
        Pairing.G1Point calldata _commitment
    )
        external
        payable
    {
        NodeGroup memory info = storageManagement.NODEGROUP(_nodeGroupKey);
        // require(msg.value > _getGas(_length), "CommitmentManager: insufficient fee");
        require(info.addrs.length > 0, "CommitmentManager:key does not exist");
        require(info.addrs.length == _signatures.length, "CommitmentManager:mismatchedSignaturesCount");
        require(block.timestamp < _timeout, "CommitmentManager:timeout");
        uint256 index = indices[tx.origin];

        uint256 num = _validateSignatures(info, _signatures, _commitment, index, _length, _timeout);
        require(num >= info.requiredAmountOfSignatures, "CommitmentManager:signature count mismatch");

        if (_nameSpaceKey != bytes32(0)) {
            _handleNamespace(_nameSpaceKey, _commitment, _length);
        }

        emit SendDACommitment(
            _commitment, block.timestamp, nonce, index, _length, _nodeGroupKey, _nameSpaceKey, _signatures
        );

        bytes32 hash = Hashing.hashCommitment(_commitment.X, _commitment.Y);

        daDetails[hash] = DADetails({ timestamp: block.timestamp, hashSignatures: Hashing.hashSignatures(_signatures) });

        userCommitments[tx.origin][index] = _commitment;
        indices[tx.origin]++;
        nonce++;
    }

    /// @notice Allows the owner to withdraw the contract balance.
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "StorageManager: no balance to withdraw");
        payable(msg.sender).transfer(balance);
    }

    /// @notice Retrieves a user's commitment by index.
    /// @param _user Address of the user.
    /// @param _index Index of the commitment.
    /// @return The commitment corresponding to the user and index.
    function getUserCommitment(address _user, uint256 _index) public view returns (Pairing.G1Point memory) {
        return userCommitments[_user][_index];
    }

    /// @notice Retrieve a namespace commitment by namespace key and index.
    /// @param _nameSpaceKey Key of the namespace.
    /// @param _index Index of the commitment.
    /// @return The commitment corresponding to the namespace key and index.
    function getNameSpaceCommitment(
        bytes32 _nameSpaceKey,
        uint256 _index
    )
        public
        view
        returns (Pairing.G1Point memory)
    {
        return nameSpaceCommitments[_nameSpaceKey][_index];
    }

    /// @notice Retrieves DA details by nonce.
    /// @param _nonce Nonce of the commitment.
    /// @return The DA details corresponding to the nonce.
    function getDADetailsByNonce(uint256 _nonce) public view returns (DADetails memory) {
        bytes32 hash = Hashing.hashCommitment(commitments[_nonce].X, commitments[_nonce].Y);
        return daDetails[hash];
    }

    /// @notice Retrieves DA details by user and index.
    /// @param _user Address of the user.
    /// @param _index Index of the commitment.
    /// @return The DA details corresponding to the user and index.
    function getDADetailsByUserAndIndex(address _user, uint256 _index) public view returns (DADetails memory) {
        bytes32 hash = Hashing.hashCommitment(userCommitments[_user][_index].X, userCommitments[_user][_index].Y);
        return daDetails[hash];
    }

    /// @notice Handle namespace-specific logic for commitments.
    /// @param _nameSpaceKey Key of the namespace.
    /// @param _commitment The commitment data.
    /// @param _length Length of the data.
    function _handleNamespace(bytes32 _nameSpaceKey, Pairing.G1Point calldata _commitment, uint256 _length) internal {
        NameSpace memory nameSpace = storageManagement.NAMESPACE(_nameSpaceKey);

        require(nameSpace.creator == tx.origin, "StorageManager:the namespace is invalid or does not belong to you.");
        // require(msg.value > 2 * _getGas(_length), "CommitmentManager: insufficient fee");
        uint256 index = nameSpaceIndex[_nameSpaceKey];
        nameSpaceCommitments[_nameSpaceKey][index] = _commitment;
        nameSpaceIndex[_nameSpaceKey]++;
    }

    /// @notice Validates signatures for a commitment.
    /// @param info Node group information.
    /// @param _signatures Array of signatures.
    /// @param _commitment The commitment being validated.
    /// @param _index Index of the commitment.
    /// @param _length Length of the data being committed.
    /// @param _timeout Timeout for the commitment.
    /// @return The number of valid signatures.
    function _validateSignatures(
        NodeGroup memory info,
        bytes[] calldata _signatures,
        Pairing.G1Point calldata _commitment,
        uint256 _index,
        uint256 _length,
        uint256 _timeout
    )
        internal
        view
        returns (uint256)
    {
        uint256 num;
        for (uint256 i = 0; i < _signatures.length; i++) {
            if (!nodeManager.isNodeBroadcast(info.addrs[i])) {
                continue;
            }

            if (_checkSign(info.addrs[i], tx.origin, _index, _length, _timeout, _signatures[i], _commitment)) {
                num++;
            }
        }
        return num;
    }

    /// @notice Checks a signature for a commitment.
    /// @param _user Address of the user who signed.
    /// @param _target Target address.
    /// @param _index Index of the commitment.
    /// @param _length Length of the data being committed.
    /// @param _timeout Timeout for the commitment.
    /// @param _sign The signature being checked.
    /// @param _commitment The commitment being checked.
    /// @return True if the signature is valid, false otherwise.
    function _checkSign(
        address _user,
        address _target,
        uint256 _index,
        uint256 _length,
        uint256 _timeout,
        bytes calldata _sign,
        Pairing.G1Point calldata _commitment
    )
        internal
        view
        returns (bool)
    {
        bytes32 hash = Hashing.hashData(_target, _index, _length, _timeout, _commitment.X, _commitment.Y);
        return _verifySignature(hash, _sign, _user);
    }

    /// @notice Verifies a cryptographic signature against a hash of data, ensuring it was signed by a specific address.
    /// @param _dataHash The hash of the data that was signed.
    /// @param _signature The signature bytes array (concatenated `r`, `s`, `v`).
    /// @param _sender The expected address of the signer.
    /// @return Returns true if the signature is valid for the given sender, false otherwise.
    function _verifySignature(
        bytes32 _dataHash,
        bytes memory _signature,
        address _sender
    )
        internal
        pure
        returns (bool)
    {
        if (_signature.length != 65) {
            return false;
        }
        uint8 v;
        bytes32 r;
        bytes32 s;
        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := byte(0, mload(add(_signature, 96)))
        }

        address signer = ecrecover(_dataHash, v, r, s);
        if (signer == address(0)) {
            return false;
        }
        return signer == _sender;
    }

    /// @notice Gets the gas cost for a given length of data.
    /// @param _length Length of the data.
    /// @return The gas cost.
    function _getGas(uint256 _length) internal pure returns (uint256) {
        return _length;
    }
}
