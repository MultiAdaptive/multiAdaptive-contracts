// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { ISemver } from "src/universal/ISemver.sol";
import { NodeManager } from "src/NodeManager.sol";
import { CommitmentManager } from "src/CommitmentManager.sol";
import { Hashing } from "src/libraries/Hashing.sol";
import { Verifier } from "src/kzg/Verifier.sol";
import { Pairing } from "src/kzg/Pairing.sol";

struct Challenge {
    uint256 nonce;
    uint8 status;
    address challenger;
    address storageAddr;
    uint256 nameSpaceId;
    uint256 start;
    uint256 end;
    uint256 r;
    Pairing.G1Point aggregateCommitment;
    uint256 point;
    uint256 timeoutBlock;
}

struct ChallengeDetatils {
    uint256 consensusIndex;
    uint256 noConsensusIndex;
    uint256 currentIndex;
    Pairing.G1Point consensusCommitment;
    Pairing.G1Point noConsensusCommitment;
    Pairing.G1Point currAggregateCommitment;
}

contract ChallengeContract is Initializable, ISemver, Ownable {
    /// @notice Semantic version.
    /// @custom:semver 0.1.0
    string public constant version = "0.1.0";

    NodeManager public nodeManager;

    CommitmentManager public commitmentManager;

    Verifier public verifier;

    mapping(uint256 => Challenge) public challenges;

    mapping(uint256 => ChallengeDetatils) public challengeDetailsMap;

    uint256 public nonce;

    event ChallengeCreated(
        uint256 nonce,
        address storageAddr,
        uint256 nameSpaceId,
        uint256 start,
        uint256 end,
        uint256 r,
        uint256 timeoutBlock
    );

    event AggregateCommitmentUploaded(uint256 nonce, Pairing.G1Point aggregateCommitment, uint256 timeoutBlock);

    /// @notice Constructs the ChallengeContract contract.
    constructor() { }

    /// @notice Initializer
    function initialize(NodeManager _nodeManager, CommitmentManager _commitmentManager) public initializer {
        nodeManager = _nodeManager;
        commitmentManager = _commitmentManager;
        _transferOwnership(tx.origin);
    }

    function createChallenge(
        uint256 _start,
        uint256 _end,
        address _storageAddr,
        uint256 _nameSpaceId,
        uint256 _r,
        uint256 _point
    )
        public
        payable
    {
        require(msg.value > 0, "ChallengeContract: minimum entry fee required");

        Challenge storage challenge = challenges[nonce];

        challenge.nonce = nonce;
        challenge.status = 0;
        challenge.challenger = msg.sender;
        challenge.storageAddr = _storageAddr;
        challenge.nameSpaceId = _nameSpaceId;
        challenge.start = _start;
        challenge.end = _end;
        challenge.r = _r;
        challenge.point = _point;
        challenge.timeoutBlock = block.number + 600;

        emit ChallengeCreated(nonce, _storageAddr, _nameSpaceId, _start, _end, _r, challenge.timeoutBlock);

        nonce++;
    }

    function uploadAggregateCommitment(uint256 _challengeId, Pairing.G1Point calldata _commitment) public {
        Challenge storage challenge = challenges[_challengeId];

        require(challenge.status == 0 || challenge.status == 3, "ChallengeContract: challenge is already complete");

        require(challenge.timeoutBlock >= block.number, "ChallengeContract: timed out");

        require(msg.sender == challenge.storageAddr, "ChallengeContract: only the storage node can upload commitment");

        if (challenge.status == 0) {
            challenge.aggregateCommitment = _commitment;
            challenge.status = 1;
        } else {
            ChallengeDetatils storage details = challengeDetailsMap[challenge.nonce];
            details.currAggregateCommitment = _commitment;
            challenge.status = 2;
        }

        emit AggregateCommitmentUploaded(_challengeId, _commitment, challenge.timeoutBlock);

        challenge.timeoutBlock = block.number + 600;
    }

    function uploadProof(uint256 _challengeId, Pairing.G1Point calldata _proof, uint256 _value) public {
        Challenge storage challenge = challenges[_challengeId];

        require(challenge.status == 5, "ChallengeContract: consensus on commitment not reached");

        require(challenge.timeoutBlock >= block.number, "ChallengeContract: timed out");

        require(msg.sender == challenge.storageAddr, "ChallengeContract: only the storage node can upload commitment");

        bool isValid = verifyAggregateCommitment(challenge.aggregateCommitment, _proof, challenge.point, _value);

        challenge.status = isValid ? 8 : 7;
    }

    function submitOpinion(uint256 _challengeId, bool _agreed) public {
        Challenge storage challenge = challenges[_challengeId];

        require(challenge.challenger == msg.sender, "ChallengeContract: only the challenger can submit an opinion");

        require(challenge.status == 1 || challenge.status == 2, "ChallengeContract: unsubmitted aggregate commitment");

        require(challenge.timeoutBlock >= block.number, "ChallengeContract: timed out");

        if (challenge.status == 1) {
            handleInitialStatus(challenge, _agreed);
        } else {
            handleOngoingStatus(challenge, _agreed);
        }
        challenge.timeoutBlock = block.number + 600;
    }

    function handleInitialStatus(Challenge storage challenge, bool _agreed) internal {
        if (_agreed) {
            challenge.status = 5;
        } else {
            ChallengeDetatils storage details = challengeDetailsMap[challenge.nonce];
            details.consensusIndex = challenge.start;
            details.noConsensusIndex = challenge.end;
            details.noConsensusCommitment = challenge.aggregateCommitment;
            details.currentIndex = (challenge.start + challenge.end) / 2;
            challenge.status = 3;
        }
    }

    function handleOngoingStatus(Challenge storage challenge, bool _agreed) internal {
        ChallengeDetatils storage details = challengeDetailsMap[challenge.nonce];

        if (_agreed) {
            details.consensusIndex = details.currentIndex;
            details.consensusCommitment = details.currAggregateCommitment;
            challenge.status = 4;
        } else {
            details.noConsensusIndex = details.currentIndex;
            details.noConsensusCommitment = details.currAggregateCommitment;
            challenge.status = 3;
        }

        if (details.consensusIndex == details.noConsensusIndex - 1) {
            if (details.consensusIndex == challenge.start) {
                details.consensusCommitment = aggregateCommitment(challenge.start, challenge.nameSpaceId, challenge.r);
            }
            bool isValid = verifyAggregateCommitment(
                details.consensusCommitment,
                details.noConsensusCommitment,
                details.noConsensusIndex,
                challenge.nameSpaceId,
                challenge.r
            );
            challenge.status = isValid ? 8 : 7;
        }

        details.currentIndex = (details.noConsensusIndex + details.consensusIndex) / 2;
    }

    function verifyAggregateCommitment(
        Pairing.G1Point memory _consensusCommitment,
        Pairing.G1Point memory _aggregateCommitment,
        uint256 _index,
        uint256 _nameSpaceId,
        uint256 _r
    )
        public
        view
        returns (bool)
    {
        bytes32 hash = Hashing.hashFold(_r, _index);
        Pairing.G1Point memory n0 = Pairing.mulScalar(commitment(_index, _nameSpaceId), uint256(hash));
        Pairing.G1Point memory n1 = Pairing.plus(_consensusCommitment, n0);
        return Pairing.equal(_aggregateCommitment, n1);
    }

    function verifyAggregateCommitment(
        Pairing.G1Point memory _commitment,
        Pairing.G1Point memory _proof,
        uint256 _index,
        uint256 _value
    )
        public
        view
        returns (bool)
    {
        return verifier.verify(_commitment, _proof, _index, _value);
    }

    function aggregateCommitment(
        uint256 _index,
        uint256 _nameSpaceId,
        uint256 _r
    )
        public
        view
        returns (Pairing.G1Point memory)
    {
        Pairing.G1Point memory n0 = commitment(_index, _nameSpaceId);
        bytes32 hash = Hashing.hashFold(_r, _index);
        return Pairing.mulScalar(n0, uint256(hash));
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "StorageManager: No balance to withdraw");
        payable(msg.sender).transfer(balance);
    }

    function commitment(uint256 _index, uint256 _nameSpaceId) public view returns (Pairing.G1Point memory) {
        return commitmentManager.getNameSpaceCommitment(_nameSpaceId, _index);
    }

    function SetKZG(address _addr) external onlyOwner {
        verifier = Verifier(_addr);
    }
}
