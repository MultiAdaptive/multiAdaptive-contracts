// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Test } from "forge-std/Test.sol";
import { Setup } from "test/setup/Setup.sol";
import { Events } from "test/setup/Events.sol";
import { Constants } from "src/libraries/Constants.sol";
import "script/DeployConfig.s.sol";

/// @title CommonTest
/// @dev An extenstion to `Test` that sets up the optimism smart contracts.
contract CommonTest is Test, Setup, Events {
    address alice;
    address bob;

    bytes32 constant nonZeroHash = keccak256(abi.encode("NON_ZERO"));

    bool usePlasmaOverride;
    bool useFaultProofs;
    address customGasToken;
    bool useInteropOverride;

    function setUp() public virtual override {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        vm.deal(alice, 10000 ether);
        vm.deal(bob, 10000 ether);

        Setup.setUp();

        // Exclude contracts for the invariant tests
        excludeContract(address(deploy));
        excludeContract(address(deploy.cfg()));

        // Make sure the base fee is non zero
        vm.fee(1 gwei);

        // Deploy L1
        Setup.L1();
    }
}
