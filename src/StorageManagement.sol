// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ISemver} from "src/universal/ISemver.sol";
import {DomiconNode} from "src/DomiconNode.sol";
import {Hashing} from "src/libraries/Hashing.sol";


struct DasKeySetInfo {
    uint requiredAmountOfSignatures;
    address[] addrs;
}

contract StorageManagement is Initializable, ISemver  {

    /// @notice Semantic version.
    /// @custom:semver 0.1.0
    string public constant version = "0.1.0";

    DomiconNode public domiconNode;

    mapping(bytes32 => DasKeySetInfo) public dasKeySetInfo;

    event DasKeySetInfoRegistered(address indexed user, bytes32 dasKey);

    /// @notice Constructs the StorageManagement contract.
    constructor() {}

    /// @notice Initializer
    function initialize(DomiconNode _domiconNode) public initializer {
        domiconNode = _domiconNode;
    }


    function SetValidKeyset(
        uint _requiredAmountOfSignatures,
        address[] calldata _addrs
    ) external returns (bytes32 ksHash) {
        require(
            _addrs.length >= _requiredAmountOfSignatures,
            "DomiconCommitment:tooManyRequiredSignatures"
        );
        for (uint256 i = 0; i < _addrs.length; i++) {
            require(
                domiconNode.IsNodeBroadcast(_addrs[i]),
                "DomiconCommitment:broadcast node address error"
            );
        }

        DasKeySetInfo memory info = DasKeySetInfo({
            requiredAmountOfSignatures: _requiredAmountOfSignatures,
            addrs: _addrs
        });
        ksHash = Hashing.hashAddresses(msg.sender, _addrs);

        dasKeySetInfo[ksHash] = info;
        emit DasKeySetInfoRegistered(msg.sender, ksHash);
    }

    function DASKEYSETINFO(
        bytes32 _key
    ) public view returns (DasKeySetInfo memory) {
        return dasKeySetInfo[_key];
    }
}
