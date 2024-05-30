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

contract StorageManager is Initializable, ISemver {
    /// @notice Semantic version.
    /// @custom:semver 0.1.0
    string public constant version = "0.1.0";

    NodeManager public nodeManager;

    mapping(bytes32 => NodeGroup) public nodeGroup;

    event NodeInfoStored(address indexed user, bytes32 indexed key, address[] addrs);

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

    function DASKEYSETINFO(bytes32 _key) public view returns (NodeGroup memory) {
        return nodeGroup[_key];
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
