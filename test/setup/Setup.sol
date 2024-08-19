// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { console2 as console } from "forge-std/console2.sol";
import { Deploy } from "script/Deploy.s.sol";
import { AddressManager } from "src/legacy/AddressManager.sol";
import { NodeManager } from "src/NodeManager.sol";
import { StorageManager } from "src/StorageManager.sol";
import { CommitmentManager } from "src/CommitmentManager.sol";
import { ChallengeContract } from "src/ChallengeContract.sol";
import { Vm } from "forge-std/Vm.sol";

/// @title Setup
contract Setup {
    /// @notice The address of the foundry Vm contract.
    Vm private constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    /// @notice The address of the Deploy contract. Set into state with `etch` to avoid
    ///         mutating any nonces. MUST not have constructor logic.
    Deploy internal constant deploy = Deploy(address(uint160(uint256(keccak256(abi.encode("multi adaptive.deploy"))))));

    // @notice Allows users of Setup to override what L2 genesis is being created.
    NodeManager public nodeManager;
    StorageManager public storageManager;
    CommitmentManager public commitmentManager;
    ChallengeContract public challengeContract;

    AddressManager public addressManager;

    /// @dev Deploys the Deploy contract without including its bytecode in the bytecode
    ///      of this contract by fetching the bytecode dynamically using `vm.getCode()`.
    ///      If the Deploy bytecode is included in this contract, then it will double
    ///      the compile time and bloat all of the test contract artifacts since they
    ///      will also need to include the bytecode for the Deploy contract.
    ///      This is a hack as we are pushing solidity to the edge.
    function setUp() public virtual {
        console.log("contracts setup start!");
        vm.etch(address(deploy), vm.getDeployedCode("Deploy.s.sol:Deploy"));
        vm.allowCheatcodes(address(deploy));
        deploy.setUp();
        console.log("contracts setup done!");
    }

    /// @dev Sets up the contracts.
    function L1() public {
        console.log("Setup: creating deployments");
        // Set the deterministic deployer in state to ensure that it is there
        vm.etch(
            0x4e59b44847b379578588920cA78FbF26c0B4956C,
            hex"7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3"
        );

        deploy.run();
        console.log("Setup: completed deployment, registering addresses now");

        nodeManager = NodeManager(deploy.mustGetAddress("NodeManagerProxy"));
        storageManager = StorageManager(deploy.mustGetAddress("StorageManagerProxy"));
        commitmentManager = CommitmentManager(deploy.mustGetAddress("CommitmentManagerProxy"));
        challengeContract = ChallengeContract(deploy.mustGetAddress("ChallengeContractProxy"));

        vm.label(address(nodeManager), "NodeManager");
        vm.label(deploy.mustGetAddress("NodeManagerProxy"), "NodeManagerProxy");

        vm.label(address(storageManager), "StorageManager");
        vm.label(deploy.mustGetAddress("StorageManagerProxy"), "StorageManagerProxy");

        vm.label(address(commitmentManager), "CommitmentManager");
        vm.label(deploy.mustGetAddress("CommitmentManagerProxy"), "CommitmentManagerProxy");

        vm.label(address(challengeContract), "ChallengeContract");
        vm.label(deploy.mustGetAddress("ChallengeContractProxy"), "ChallengeContractProxy");

        console.log("Setup: registered deployments");
    }
}
