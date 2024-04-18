// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Executables} from "script/Executables.sol";
import {Chains} from "script/Chains.sol";

// Global constant for the `useFaultProofs` slot in the DeployConfig contract, which can be overridden in the testing
// environment.
bytes32 constant USE_FAULT_PROOFS_SLOT = bytes32(uint256(63));

/// @title DeployConfig
/// @notice Represents the configuration required to deploy the system. It is expected
///         to read the file from JSON. A future improvement would be to have fallback
///         values if they are not defined in the JSON themselves.
contract DeployConfig is Script {
    string internal _json;

    uint256 public l1ChainID;

    function read(string memory _path) public {
        console.log("DeployConfig: reading file %s", _path);
        try vm.readFile(_path) returns (string memory data) {
            _json = data;
        } catch {
            require(
                false,
                string.concat("Cannot find deploy config file at ", _path)
            );
        }


        l1ChainID = stdJson.readUint(_json, "$.l1ChainID");
    }
}
