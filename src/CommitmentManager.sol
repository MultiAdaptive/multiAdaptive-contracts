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

contract CommitmentManager is Initializable, ISemver, Ownable {
    struct DaDetails {
        uint256 timestamp;
        bytes32 hashSignatures;
    }

    /// @notice Semantic version.
    /// @custom:semver 0.1.0
    string public constant version = "0.1.0";

    bytes32 public committeeRoot;

    uint256 public nonce;

    NodeManager public nodeManager;

    StorageManager public storageManagement;

    mapping(address => mapping(uint256 => Pairing.G1Point)) public userCommitments;
    mapping(uint256 => mapping(uint256 => Pairing.G1Point)) public nameSpaceCommitments;
    mapping(address => uint256) public indices;
    mapping(uint256 => uint256) public nameSpaceIndex;
    mapping(uint256 => Pairing.G1Point) public commitments;
    mapping(bytes32 => DaDetails) public daDetails;

    event SendDACommitment(
        address user,
        Pairing.G1Point commitment,
        uint256 timestamp,
        uint256 nonce,
        uint256 index,
        uint256 len,
        bytes32 root,
        bytes32 dasKey,
        bytes[] signatures
    );

    modifier onlyBroadcastNode() {
        require(nodeManager.IsNodeBroadcast(msg.sender), "CommitmentManager: broadcast node address error");
        _;
    }

    /// @notice Constructs the CommitmentManager contract.
    constructor() { }

    /// @notice Initializer
    function initialize(NodeManager _nodeManager, StorageManager _storageManagement) public initializer {
        nodeManager = _nodeManager;
        storageManagement = _storageManagement;
        _transferOwnership(tx.origin);
    }

    function SubmitCommitment(
        uint256 _length,
        bytes32 _nodeGroupKey,
        bytes[] calldata _signatures,
        uint256 _nameSpaceId,
        Pairing.G1Point calldata _commitment
    )
        external
        payable
    {
        NodeGroup memory info = storageManagement.NODEGROUP(_nodeGroupKey);
        require(msg.value > getGas(_length), "CommitmentManager: insufficient fee");
        require(info.addrs.length > 0, "CommitmentManager:key does not exist");
        require(info.addrs.length == _signatures.length, "CommitmentManager:mismatchedSignaturesCount");
        uint256 index = indices[tx.origin];

        uint256 num = validateSignatures(info, _signatures, _commitment, index, _length);
        require(num >= info.requiredAmountOfSignatures, "CommitmentManager:signature count mismatch");

        if (_nameSpaceId != 0) {
            handleNamespace(_nameSpaceId, _commitment, _length);
        }
        committeeRoot = Hashing.hashCommitmentRoot(_commitment.X, _commitment.Y, tx.origin, committeeRoot);

        emit SendDACommitment(
            tx.origin, _commitment, block.timestamp, nonce, index, _length, committeeRoot, _nodeGroupKey, _signatures
        );

        bytes32 hash = Hashing.hashCommitment(_commitment.X, _commitment.Y);

        daDetails[hash] = DaDetails({ timestamp: block.timestamp, hashSignatures: Hashing.hashSignatures(_signatures) });

        userCommitments[tx.origin][index] = _commitment;
        indices[tx.origin]++;
        nonce++;
    }

    function handleNamespace(uint256 _nameSpaceId, Pairing.G1Point calldata _commitment, uint256 _length) internal {
        NameSpace memory nameSpace = storageManagement.NAMESPACE(_nameSpaceId);

        require(nameSpace.creator != tx.origin, "StorageManager:the namespace is invalid or does not belong to you.");
        require(msg.value > 2 * getGas(_length), "CommitmentManager: insufficient fee");
        uint256 index = nameSpaceIndex[_nameSpaceId];
        nameSpaceCommitments[_nameSpaceId][index] = _commitment;
        nameSpaceIndex[_nameSpaceId]++;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "StorageManager: no balance to withdraw");
        payable(msg.sender).transfer(balance);
    }

    function getUserCommitment(address _user, uint256 _index) public view returns (Pairing.G1Point memory) {
        return userCommitments[_user][_index];
    }

    function getNameSpaceCommitment(
        uint256 _nameSpaceId,
        uint256 _index
    )
        public
        view
        returns (Pairing.G1Point memory)
    {
        return nameSpaceCommitments[_nameSpaceId][_index];
    }

    function COMMITMENTS(uint256 _nonce) public view returns (DaDetails memory) {
        bytes32 hash = Hashing.hashCommitment(commitments[_nonce].X, commitments[_nonce].Y);
        return daDetails[hash];
    }

    function COMMITMENTS(address _user, uint256 _index) public view returns (DaDetails memory) {
        bytes32 hash = Hashing.hashCommitment(userCommitments[_user][_index].X, userCommitments[_user][_index].Y);

        return daDetails[hash];
    }

    function validateSignatures(
        NodeGroup memory info,
        bytes[] calldata _signatures,
        Pairing.G1Point calldata _commitment,
        uint256 _index,
        uint256 _length
    )
        internal
        view
        returns (uint256)
    {
        uint256 num;
        for (uint256 i = 0; i < _signatures.length; i++) {
            if (!nodeManager.IsNodeBroadcast(info.addrs[i])) {
                continue;
            }

            if (checkSign(info.addrs[i], tx.origin, _index, _length, _signatures[i], _commitment)) {
                num++;
            }
        }
        return num;
    }

    function checkSign(
        address _user,
        address _target,
        uint256 _index,
        uint256 _length,
        bytes calldata _sign,
        Pairing.G1Point calldata _commitment
    )
        internal
        view
        returns (bool)
    {
        bytes32 hash = Hashing.hashData(_target, _index, _length, _commitment.X, _commitment.Y);
        return Hashing.verifySignature(hash, _sign, _user);
    }

    function getGas(uint256 _length) internal pure returns (uint256) {
        return _length;
    }
}
