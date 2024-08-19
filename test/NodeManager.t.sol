// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { NodeInfo } from "src/NodeManager.sol";
import { Proxy } from "src/universal/Proxy.sol";
import { CommonTest } from "test/setup/CommonTest.sol";

contract NodeManagerTest is CommonTest {
    function setUp() public virtual override {
        super.setUp();
    }

    function testRegisterBroadcastNode() public {
        vm.startPrank(alice);
        assertEq(false, nodeManager.isNodeBroadcast(address(alice)));
        NodeInfo memory nodeInfo = NodeInfo({
            url: "url",
            name: "name",
            stakedTokens: 100,
            location: "cn",
            maxStorageSpace: 1000,
            addr: address(alice)
        });
        nodeManager.registerBroadcastNode(nodeInfo);
        assertEq(true, nodeManager.isNodeBroadcast(address(alice)));
        vm.stopPrank();
    }

    function testRegisterStorageNode() public {
        vm.startPrank(alice);
        assertEq(false, nodeManager.isNodeStorage(address(alice)));
        NodeInfo memory nodeInfo = NodeInfo({
            url: "url",
            name: "name",
            stakedTokens: 100,
            location: "cn",
            maxStorageSpace: 1000,
            addr: address(alice)
        });
        nodeManager.registerStorageNode(nodeInfo);
        assertEq(true, nodeManager.isNodeStorage(address(alice)));
        vm.stopPrank();
    }
}
