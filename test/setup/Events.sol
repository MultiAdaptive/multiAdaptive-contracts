// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Pairing } from "src/kzg/Pairing.sol";

/// @title Events
/// @dev Contains various events that are tested against. This contract needs to
///      exist until we either modularize the implementations or use a newer version of
///      solc that allows for referencing events from other contracts.
contract Events {
    /// @dev OpenZeppelin Ownable.sol transferOwnership event
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event TransactionDeposited(address indexed from, address indexed to, uint256 indexed version, bytes opaqueData);

    /// @dev NodeManager.sol
    event BroadcastNode(address indexed add, string url, string name, uint256 stakedTokens);
    event StorageNode(address indexed add, string url, string name, uint256 stakedTokens);

    /// @dev StorageManager.sol
    event NodeGroupRegistered(
        address indexed creator, bytes32 indexed key, uint256 requiredAmountOfSignatures, address[] nodeAddresses
    );
    event NameSpaceRegistered(address indexed creator, bytes32 indexed key, address[] nodeAddresses);

    /// @dev CommitmentManager.sol
    event SendDACommitment(
        Pairing.G1Point commitment,
        uint256 timestamp,
        uint256 nonce,
        uint256 index,
        uint256 timeout,
        bytes32 nodeGroupKey,
        bytes32 nameSpaceKey,
        bytes[] signatures
    );

    /// @dev ChallengeContract.sol
    event ChallengeCreated(
        uint256 nonce,
        address storageAddr,
        bytes32 nameSpaceKey,
        uint256 start,
        uint256 end,
        uint256 r,
        uint256 timeoutBlock
    );
    event AggregateCommitmentSubmit(uint256 nonce, Pairing.G1Point aggregateCommitment, uint256 timeoutBlock);
}
