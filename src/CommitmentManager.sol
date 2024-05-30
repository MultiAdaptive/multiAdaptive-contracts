// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { ISemver } from "src/universal/ISemver.sol";
import { NodeManager } from "src/NodeManager.sol";
import { StorageManager, NodeGroup } from "src/StorageManager.sol";
import { Hashing } from "src/libraries/Hashing.sol";
import { Pairing } from "src/kzg/Pairing.sol";

contract CommitmentManager is Initializable, ISemver {
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
    mapping(address => uint256) public indices;
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
    }

    function SubmitCommitment(
        uint64 _index,
        uint64 _length,
        bytes32 _dasKey,
        bytes[] calldata _signatures,
        Pairing.G1Point calldata _commitment
    )
        external
        payable
    {
        NodeGroup memory info = storageManagement.DASKEYSETINFO(_dasKey);
        require(info.addrs.length > 0, "CommitmentManager:key does not exist");
        require(info.addrs.length == _signatures.length, "CommitmentManager:mismatchedSignaturesCount");
        require(indices[tx.origin] == _index, "CommitmentManager:index error");

        uint256 num;
        for (uint256 i = 0; i < _signatures.length; i++) {
            if (!nodeManager.IsNodeBroadcast(info.addrs[i])) {
                continue;
            }

            if (checkSign(info.addrs[i], tx.origin, _index, _length, _signatures[i], _commitment)) {
                num++;
            }
        }

        require(num >= info.requiredAmountOfSignatures, "CommitmentManager:signature count mismatch");

        committeeRoot = Hashing.hashCommitmentRoot(_commitment.X, _commitment.Y, tx.origin, committeeRoot);

        emit SendDACommitment(
            tx.origin, _commitment, block.timestamp, nonce, _index, _length, committeeRoot, _dasKey, _signatures
        );

        bytes32 hash = Hashing.hashCommitment(_commitment.X, _commitment.Y);

        daDetails[hash] = DaDetails({ timestamp: block.timestamp, hashSignatures: Hashing.hashSignatures(_signatures) });

        userCommitments[tx.origin][_index] = _commitment;
        indices[tx.origin]++;
        nonce++;
    }

    function getUserCommitments(address _user, uint256 _index) public view returns (Pairing.G1Point memory) {
        return userCommitments[_user][_index];
    }

    function COMMITMENTS(uint256 _nonce) public view returns (DaDetails memory) {
        bytes32 hash = Hashing.hashCommitment(commitments[_nonce].X, commitments[_nonce].Y);
        return daDetails[hash];
    }

    function COMMITMENTS(address _user, uint256 _index) public view returns (DaDetails memory) {
        bytes32 hash = Hashing.hashCommitment(userCommitments[_user][_index].X, userCommitments[_user][_index].Y);

        return daDetails[hash];
    }

    function checkSign(
        address _user,
        address _target,
        uint64 _index,
        uint64 _length,
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
