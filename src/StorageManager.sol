// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { ISemver } from "src/universal/ISemver.sol";
import { NodeManager } from "src/NodeManager.sol";
import { Hashing } from "src/libraries/Hashing.sol";

struct NodeGroup {
    uint256 requiredAmountOfSignatures;
    address[] addrs;
}

struct NameSpace {
    address creator;
    address[] addr;
}

contract StorageManager is Initializable, ISemver {
    /// @notice Semantic version.
    /// @custom:semver 0.1.0
    string public constant version = "0.1.0";

    NodeManager public nodeManager;

    uint256 public nonce;

    mapping(bytes32 => NodeGroup) public nodeGroup;
    mapping(uint256 => NameSpace) public nameSpace;

    event NodeInfoStored(address indexed user, bytes32 indexed key, address[] addrs);
    event NameSpaceCreated(uint256 indexed id, address indexed creator, address[] addr);

    /// @notice Constructs the StorageManagement contract.
    constructor() { }

    /// @notice Initializer
    function initialize(NodeManager _nodeManager) public initializer {
        nodeManager = _nodeManager;
    }

    function storeAddressMapping(
        uint256 _requiredAmountOfSignatures,
        address[] calldata _addrs
    )
        external
        returns (bytes32 ksHash)
    {
        require(_addrs.length >= _requiredAmountOfSignatures, "StorageManager:tooManyRequiredSignatures");
        for (uint256 i = 0; i < _addrs.length; i++) {
            require(nodeManager.IsNodeBroadcast(_addrs[i]), "StorageManager:broadcast node address error");
        }

        NodeGroup memory info = NodeGroup({ requiredAmountOfSignatures: _requiredAmountOfSignatures, addrs: _addrs });
        ksHash = Hashing.hashAddresses(msg.sender, _requiredAmountOfSignatures, _addrs);

        nodeGroup[ksHash] = info;
        emit NodeInfoStored(msg.sender, ksHash, _addrs);
    }

    function createNameSpace(address[] calldata _addrs) external returns (uint256) {
        for (uint256 i = 0; i < _addrs.length; i++) {
            require(nodeManager.IsNodeStorage(_addrs[i]), "StorageManager:storage node address error");
        }

        uint256 id = ++nonce;
        NameSpace memory newNameSpace = NameSpace({ creator: msg.sender, addr: _addrs });
        nameSpace[id] = newNameSpace;

        emit NameSpaceCreated(id, msg.sender, _addrs);
        return id;
    }

    function NODEGROUP(bytes32 _key) public view returns (NodeGroup memory) {
        return nodeGroup[_key];
    }

    function NAMESPACE(uint256 _id) public view returns (NameSpace memory) {
        return nameSpace[_id];
    }

    function getKeyForAddresses(
        address[] calldata _addrs,
        uint256 _requiredAmountOfSignatures
    )
        external
        view
        returns (bytes32)
    {
        return Hashing.hashAddresses(msg.sender, _requiredAmountOfSignatures, _addrs);
    }
}
