// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { ISemver } from "src/universal/ISemver.sol";

/// @notice Struct containing information about a node.
struct NodeInfo {
    string url;
    string name;
    uint256 stakedTokens;
    string location;
    uint256 maxStorageSpace;
    address addr;
}

/// @title NodeManager
/// @notice This contract manages the registration and information of broadcast and storage nodes.
contract NodeManager is Initializable, ISemver {
    /// @notice Semantic version.
    /// @custom:semver 0.1.0
    string public constant version = "0.1.0";

    /// @notice Mapping from node address to broadcasting node information.
    mapping(address => NodeInfo) public broadcastingNodes;

    /// @notice List of all broadcasting node addresses.
    address[] public broadcastNodeList;

    /// @notice Mapping from node address to storage node information.
    mapping(address => NodeInfo) public storageNodes;

    /// @notice List of all storage node addresses.
    address[] public storageNodeList;

    /// @notice Event emitted when a new broadcast node is registered.
    /// @param add Address of the broadcast node.
    /// @param url URL of the broadcast node.
    /// @param name Name of the broadcast node.
    /// @param stakedTokens Amount of tokens staked by the broadcast node.
    event BroadcastNode(address indexed add, string url, string name, uint256 stakedTokens);

    /// @notice Event emitted when a new storage node is registered.
    /// @param add Address of the storage node.
    /// @param url URL of the storage node.
    /// @param name Name of the storage node.
    /// @param stakedTokens Amount of tokens staked by the storage node.
    event StorageNode(address indexed add, string url, string name, uint256 stakedTokens);

    /// @notice Modifier to allow only EOAs (Externally Owned Accounts) to call the function.
    ///         This is a basic protection to prevent contract calls.
    modifier onlyEOA() {
        require(!Address.isContract(msg.sender), "NodeManager: function can only be called from an EOA");
        _;
    }

    /// @notice Constructs the NodeManager contract.
    constructor() { }

    /// @notice Initializer
    function initialize() public initializer { }

    /// @notice Registers a new broadcast node.
    /// @param info Struct containing information about the broadcast node.
    function registerBroadcastNode(NodeInfo calldata info) external onlyEOA {
        // require(msg.value == info.stakedTokens);
        require(!isNodeStorage(msg.sender), "NodeManager: already a storage node");
        if (!isNodeBroadcast(msg.sender)) {
            broadcastNodeList.push(info.addr);
        }
        broadcastingNodes[info.addr] = info;
        emit BroadcastNode(info.addr, info.url, info.name, info.stakedTokens);
    }

    /// @notice Registers a new storage node.
    /// @param info Struct containing information about the storage node.
    function registerStorageNode(NodeInfo calldata info) external onlyEOA {
        // require(msg.value == info.stakedTokens);
        require(!isNodeBroadcast(msg.sender), "NodeManager: already a broadcast node");

        if (!isNodeStorage(msg.sender)) {
            storageNodeList.push(info.addr);
        }
        storageNodes[info.addr] = info;
        emit StorageNode(info.addr, info.url, info.name, info.stakedTokens);
    }

    /// @notice Retrieves information about all broadcasting nodes.
    /// @return nodes Array of NodeInfo structs containing information about all broadcasting nodes.
    function getBroadcastingNodes() external view returns (NodeInfo[] memory nodes) {
        uint256 totalNodes = broadcastNodeList.length;
        nodes = new NodeInfo[](totalNodes);

        for (uint256 i = 0; i < totalNodes; i++) {
            nodes[i] = broadcastingNodes[broadcastNodeList[i]];
        }
    }

    /// @notice Retrieves information about all storage nodes.
    /// @return nodes Array of NodeInfo structs containing information about all storage nodes.
    function getStorageNodes() external view returns (NodeInfo[] memory nodes) {
        uint256 totalNodes = storageNodeList.length;
        nodes = new NodeInfo[](totalNodes);

        for (uint256 i = 0; i < totalNodes; i++) {
            nodes[i] = storageNodes[storageNodeList[i]];
        }
    }

    /// @notice Checks if an address is a broadcast node.
    /// @param addr Address to check.
    /// @return True if the address is a broadcast node, false otherwise.
    function isNodeBroadcast(address addr) public view returns (bool) {
        return broadcastingNodes[addr].stakedTokens != 0;
    }

    /// @notice Checks if an address is a storage node.
    /// @param addr Address to check.
    /// @return True if the address is a storage node, false otherwise.
    function isNodeStorage(address addr) public view returns (bool) {
        return storageNodes[addr].stakedTokens != 0;
    }
}
