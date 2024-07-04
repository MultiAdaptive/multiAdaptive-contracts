// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { ISemver } from "src/universal/ISemver.sol";
import { NodeManager } from "src/NodeManager.sol";
import { Hashing } from "src/libraries/Hashing.sol";

/// @notice Struct containing information about a group of nodes.
struct NodeGroup {
    uint256 requiredAmountOfSignatures;
    address[] addrs;
}

/// @notice Struct containing information about a namespace.
struct NameSpace {
    address creator;
    address[] addr;
}

/// @title StorageManager
/// @notice
contract StorageManager is Initializable, ISemver {
    /// @notice Semantic version.
    /// @custom:semver 0.1.0
    string public constant version = "0.1.0";

    /// @notice Instance of the NodeManager contract.
    NodeManager public nodeManager;

    /// @notice Mapping from a hash to a NodeGroup.
    mapping(bytes32 => NodeGroup) public nodeGroup;

    mapping(bytes32 => NameSpace) public nameSpace;

    /// @notice Emitted when a new node group is registered.
    event NodeGroupRegistered(
        address indexed creator, bytes32 indexed key, uint256 requiredAmountOfSignatures, address[] nodeAddresses
    );

    /// @notice Emitted when a new namespace is registered.
    event NameSpaceRegistered(address indexed creator, bytes32 indexed key, address[] nodeAddresses);

    /// @notice Constructs the StorageManagement contract.
    constructor() { }

    /// @notice Initializer
    /// @param _nodeManager Address of the NodeManager contract.
    function initialize(NodeManager _nodeManager) public initializer {
        nodeManager = _nodeManager;
    }

    /// @notice Registers a new node group.
    /// @param _requiredAmountOfSignatures The number of required signatures for the node group.
    /// @param _nodeAddresses The broadcast node addresses in the group.
    /// @return nodeGroupKey The key of the registered node group.
    function registerNodeGroup(
        uint256 _requiredAmountOfSignatures,
        address[] calldata _nodeAddresses
    )
        external
        returns (bytes32 nodeGroupKey)
    {
        require(_nodeAddresses.length >= _requiredAmountOfSignatures, "StorageManager:tooManyRequiredSignatures");
        for (uint256 i = 0; i < _nodeAddresses.length; i++) {
            require(nodeManager.isNodeBroadcast(_nodeAddresses[i]), "StorageManager:broadcast node address error");
        }

        address[] memory nodeAddresses = sortAddresses(_nodeAddresses);

        NodeGroup memory info =
            NodeGroup({ requiredAmountOfSignatures: _requiredAmountOfSignatures, addrs: nodeAddresses });
        nodeGroupKey = Hashing.hashAddresses(_requiredAmountOfSignatures, nodeAddresses);

        nodeGroup[nodeGroupKey] = info;
        emit NodeGroupRegistered(msg.sender, nodeGroupKey, _requiredAmountOfSignatures, _nodeAddresses);
    }

    /// @notice Registers a new namespace.
    /// @param _nodeAddresses The storage node addresses in the namespace.
    /// @return nameSpaceKey The key of the registered namespace.
    function registerNameSpace(address[] calldata _nodeAddresses) external returns (bytes32 nameSpaceKey) {
        for (uint256 i = 0; i < _nodeAddresses.length; i++) {
            require(nodeManager.isNodeStorage(_nodeAddresses[i]), "StorageManager:storage node address error");
        }

        address[] memory nodeAddresses = sortAddresses(_nodeAddresses);

        NameSpace memory newNameSpace = NameSpace({ creator: msg.sender, addr: nodeAddresses });
        nameSpaceKey = Hashing.hashAddresses(msg.sender, nodeAddresses);

        nameSpace[nameSpaceKey] = newNameSpace;

        emit NameSpaceRegistered(msg.sender, nameSpaceKey, _nodeAddresses);
    }

    /// @notice Returns the node group key for given addresses and required signatures.
    /// @param _nodeAddresses The addresses of the nodes in the group.
    /// @param _requiredAmountOfSignatures The number of required signatures for the node group.
    /// @return The key of the node group.
    function getNodeGroupKey(
        address[] calldata _nodeAddresses,
        uint256 _requiredAmountOfSignatures
    )
        external
        pure
        returns (bytes32)
    {
        return Hashing.hashAddresses(_requiredAmountOfSignatures, _nodeAddresses);
    }

    /// @notice Returns the namespace key for given addresses.
    /// @param _nodeAddresses The addresses of the nodes in the namespace.
    /// @return The key of the namespace.
    function getNameSpaceKey(address[] calldata _nodeAddresses) external view returns (bytes32) {
        return Hashing.hashAddresses(msg.sender, _nodeAddresses);
    }

    /// @notice Retrieves information about a node group by its hash key.
    /// @param _key Hash key of the node group.
    /// @return NodeGroup information associated with the hash key.
    function NODEGROUP(bytes32 _key) public view returns (NodeGroup memory) {
        return nodeGroup[_key];
    }

    /// @notice Retrieves information about a namespace by its hash key.
    /// @param _key Hash key of the namespace.
    /// @return NameSpace information associated with the hash key.
    function NAMESPACE(bytes32 _key) public view returns (NameSpace memory) {
        return nameSpace[_key];
    }

    /// @notice Sorts an array of addresses in ascending order.
    /// @param addresses The array of addresses to be sorted.
    /// @return The sorted array of addresses.
    function sortAddresses(address[] memory addresses) public pure returns (address[] memory) {
        uint256 length = addresses.length;
        for (uint256 i = 1; i < length; i++) {
            address key = addresses[i];
            int256 j = int256(i) - 1;
            while (j >= 0 && addresses[uint256(j)] > key) {
                addresses[uint256(j + 1)] = addresses[uint256(j)];
                j--;
            }
            addresses[uint256(j + 1)] = key;
        }
        return addresses;
    }
}
