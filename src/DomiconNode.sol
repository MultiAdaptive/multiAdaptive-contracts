// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { ISemver } from "src/universal/ISemver.sol";

contract DomiconNode is Initializable, ISemver {

    using SafeERC20 for IERC20;

    /// @notice Semantic version.
    /// @custom:semver 1.4.1
    string public constant version = "1.4.1";

    address public DOM;

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
    mapping(address => NodeInfo)  public storageNodes;
    address[] public storageNodeList;

    event BroadcastNode(address indexed add,string url,string name,uint256 stakedTokens);

    event StorageNode(address indexed add,string url,string name,uint256 stakedTokens);


    /// @notice Constructs the DomiconNode contract.
    constructor() {

    }

    /// @notice Initializer
    function initialize() public initializer {

    }

    function RegisterBroadcastNode(NodeInfo calldata info) external {
        IERC20(DOM).safeTransferFrom(msg.sender, address(this), info.stakedTokens);

        broadcastNodeList.push(info.addr);
        broadcastingNodes[info.addr] = info;
        emit BroadcastNode(info.addr,info.url,info.name,info.stakedTokens);
    }

    function RegisterStorageNodeList(NodeInfo calldata info) external {
        IERC20(DOM).safeTransferFrom(msg.sender, address(this), info.stakedTokens);

        storageNodeList.push(info.addr);
        storageNodes[info.addr] = info;
        emit BroadcastNode(info.addr,info.url,info.name,info.stakedTokens);
    }

    function IsNodeBroadcast(address addr) external view returns (bool){
        if (broadcastingNodes[addr].stakedTokens!=0){
            return true;
        }
        return false;
    }

    function SetDom(address addr)external {
        DOM = addr;
    }
}
