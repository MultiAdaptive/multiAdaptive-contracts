// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { ISemver } from "src/universal/ISemver.sol";

contract NodeManager is Initializable, ISemver {
    /// @notice Semantic version.
    /// @custom:semver 0.1.0
    string public constant version = "0.1.0";

    struct NodeInfo {
        string url;
        string name;
        uint256 stakedTokens;
        string location;
        uint256 maxStorageSpace;
        address addr;
    }

    mapping(address => NodeInfo) public broadcastingNodes;
    address[] public broadcastNodeList;
    mapping(address => NodeInfo) public storageNodes;
    address[] public storageNodeList;

    event BroadcastNode(address indexed add, string url, string name, uint256 stakedTokens);

    event StorageNode(address indexed add, string url, string name, uint256 stakedTokens);

    /// @notice Constructs the NodeManager contract.
    constructor() { }

    /// @notice Initializer
    function initialize() public initializer { }

    function RegisterBroadcastNode(NodeInfo calldata info) external payable {
        require(info.addr == tx.origin);
        require(msg.value == info.stakedTokens);

        broadcastNodeList.push(info.addr);
        broadcastingNodes[info.addr] = info;
        emit BroadcastNode(info.addr, info.url, info.name, info.stakedTokens);
    }

    function RegisterStorageNode(NodeInfo calldata info) external payable {
        require(info.addr == tx.origin);
        require(msg.value == info.stakedTokens);

        storageNodeList.push(info.addr);
        storageNodes[info.addr] = info;
        emit StorageNode(info.addr, info.url, info.name, info.stakedTokens);
    }

    function IsNodeBroadcast(address addr) external view returns (bool) {
        if (broadcastingNodes[addr].stakedTokens != 0) {
            return true;
        }
        return false;
    }

    function IsNodeStorage(address addr) external view returns (bool) {
        if (storageNodes[addr].stakedTokens != 0) {
            return true;
        }
        return false;
    }
}
