// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { ISemver } from "src/universal/ISemver.sol";
import { NodeManager } from "src/NodeManager.sol";
import { CommitmentManager } from "src/CommitmentManager.sol";
import { Hashing } from "src/libraries/Hashing.sol";
import { ChallengeStatus } from "src/libraries/ChallengeStatus.sol";
import { Verifier } from "src/kzg/Verifier.sol";
import { Pairing } from "src/kzg/Pairing.sol";

/// @title ChallengeContract
/// @notice This contract manages challenges related to storage commitments.
contract ChallengeContract is ChallengeStatus, Initializable, ISemver, Ownable {
    /// @notice Stores information about a challenge.
    struct Challenge {
        uint256 nonce;
        uint8 status;
        address challenger;
        address storageAddr;
        bytes32 nameSpaceKey;
        uint256 start;
        uint256 end;
        uint256 r;
        Pairing.G1Point aggregateCommitment;
        uint256 point;
        uint256 timeoutBlock;
    }

    /// @notice Stores detailed information about a challenge's status.
    struct ChallengeDetatils {
        uint256 consensusIndex;
        uint256 noConsensusIndex;
        uint256 currentIndex;
        Pairing.G1Point consensusCommitment;
        Pairing.G1Point noConsensusCommitment;
        Pairing.G1Point currAggregateCommitment;
    }

    /// @notice Semantic version.
    /// @custom:semver 0.1.0
    string public constant version = "0.1.0";

    /// @notice Instance of the NodeManager contract.
    NodeManager public nodeManager;

    /// @notice Instance of the CommitmentManager contract.
    CommitmentManager public commitmentManager;

    /// @notice Instance of the kzg verifier contract.
    Verifier public verifier;

    /// @notice Mapping to store challenges by their ID.
    mapping(uint256 => Challenge) public challenges;

    /// @notice Mapping to store detailed information about each challenge.
    mapping(uint256 => ChallengeDetatils) public challengeDetailsMap;

    /// @notice Counter for challenge IDs.
    uint256 public nonce;

    /// @notice Event emitted when a new challenge is created.
    event ChallengeCreated(
        uint256 nonce,
        address storageAddr,
        bytes32 nameSpaceKey,
        uint256 start,
        uint256 end,
        uint256 r,
        uint256 timeoutBlock
    );

    /// @notice Event emitted when an aggregate commitment is submit.
    event AggregateCommitmentSubmit(uint256 nonce, Pairing.G1Point aggregateCommitment, uint256 timeoutBlock);

    /// @notice Constructs the ChallengeContract contract.
    constructor() { }

    /// @notice Initializer function to set up the contract.
    /// @param _nodeManager Instance of the NodeManager contract.
    /// @param _commitmentManager Instance of the CommitmentManager contract.
    function initialize(NodeManager _nodeManager, CommitmentManager _commitmentManager) public initializer {
        nodeManager = _nodeManager;
        commitmentManager = _commitmentManager;
        _transferOwnership(tx.origin);
    }

    /// @notice Creates a new challenge.
    /// @param _start Start index for the challenge.
    /// @param _end End index for the challenge.
    /// @param _storageAddr Address of the storage node being challenged.
    /// @param _r Random value used in the challenge.
    /// @param _point Point for the challenge.
    /// @param _nameSpaceKey Namespace key associated with the challenge.
    function createChallenge(
        uint256 _start,
        uint256 _end,
        address _storageAddr,
        uint256 _r,
        uint256 _point,
        bytes32 _nameSpaceKey
    )
        external
        payable
    {
        // require(msg.value > 0, "ChallengeContract: minimum entry fee required");

        Challenge storage challenge = challenges[nonce];

        challenge.nonce = nonce;
        challenge.status = CHALLENGE_CREATED;
        challenge.challenger = msg.sender;
        challenge.storageAddr = _storageAddr;
        challenge.nameSpaceKey = _nameSpaceKey;
        challenge.start = _start;
        challenge.end = _end;
        challenge.r = _r;
        challenge.point = _point;
        challenge.timeoutBlock = block.number + 600;

        emit ChallengeCreated(nonce, _storageAddr, _nameSpaceKey, _start, _end, _r, challenge.timeoutBlock);

        nonce++;
    }

    /// @notice Submits an aggregate commitment for a challenge.
    /// @param _challengeId ID of the challenge.
    /// @param _commitment The aggregate commitment point.
    function submitAggregateCommitment(uint256 _challengeId, Pairing.G1Point calldata _commitment) external {
        Challenge storage challenge = challenges[_challengeId];

        require(
            challenge.status == CHALLENGE_CREATED || challenge.status == COMMIT_NOT_AGREED,
            "ChallengeContract: challenge is already complete"
        );

        require(challenge.timeoutBlock >= block.number, "ChallengeContract: timed out");

        require(msg.sender == challenge.storageAddr, "ChallengeContract: only the storage node can upload commitment");

        if (challenge.status == CHALLENGE_CREATED) {
            challenge.aggregateCommitment = _commitment;
            challenge.status = FIRST_COMMIT_SUBMITTED;
        } else {
            ChallengeDetatils storage details = challengeDetailsMap[challenge.nonce];
            details.currAggregateCommitment = _commitment;
            challenge.status = RECOMMIT_SUBMITTED;
        }

        emit AggregateCommitmentSubmit(_challengeId, _commitment, challenge.timeoutBlock);

        challenge.timeoutBlock = block.number + 600;
    }

    /// @notice Submits an opinion on the aggregate commitment.
    /// @param _challengeId ID of the challenge.
    /// @param _agreed Boolean indicating if the opinion agrees with the commitment.
    function submitOpinion(uint256 _challengeId, bool _agreed) external {
        Challenge storage challenge = challenges[_challengeId];

        require(challenge.challenger == msg.sender, "ChallengeContract: only the challenger can submit an opinion");

        require(
            challenge.status == FIRST_COMMIT_SUBMITTED || challenge.status == RECOMMIT_SUBMITTED,
            "ChallengeContract: unsubmitted aggregate commitment"
        );

        require(challenge.timeoutBlock >= block.number, "ChallengeContract: timed out");

        if (challenge.status == FIRST_COMMIT_SUBMITTED) {
            _handleInitialStatus(challenge, _agreed);
        } else {
            _handleOngoingStatus(challenge, _agreed);
        }
        challenge.timeoutBlock = block.number + 600;
    }

    /// @notice Submits a proof for a challenge.
    /// @param _challengeId ID of the challenge.
    /// @param _proof The proof point.
    /// @param _value The value to be proven.
    function uploadProof(uint256 _challengeId, Pairing.G1Point calldata _proof, uint256 _value) external {
        Challenge storage challenge = challenges[_challengeId];

        require(challenge.status == AGREEMENT_REACHED, "ChallengeContract: consensus on commitment not reached");

        require(challenge.timeoutBlock >= block.number, "ChallengeContract: timed out");

        require(msg.sender == challenge.storageAddr, "ChallengeContract: only the storage node can upload commitment");

        bool isValid = verifyAggregateCommitment(challenge.aggregateCommitment, _proof, challenge.point, _value);

        challenge.status = isValid ? CHALLENGE_SUCCESSFUL : CHALLENGE_FAILED;
    }

    /// @notice Withdraws the contract balance to the owner's address.
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "StorageManager: No balance to withdraw");
        payable(msg.sender).transfer(balance);
    }

    /// @notice Sets the address of the KZG verifier contract.
    /// @param _addr Address of the verifier contract.
    function setKZG(address _addr) external onlyOwner {
        verifier = Verifier(_addr);
    }

    /// @notice Handles the initial opinion submission.
    /// @param challenge The challenge being addressed.
    /// @param _agreed Boolean indicating if the opinion agrees with the commitment.
    function _handleInitialStatus(Challenge storage challenge, bool _agreed) internal {
        if (_agreed) {
            challenge.status = AGREEMENT_REACHED;
        } else {
            ChallengeDetatils storage details = challengeDetailsMap[challenge.nonce];
            details.consensusIndex = challenge.start;
            details.noConsensusIndex = challenge.end;
            details.noConsensusCommitment = challenge.aggregateCommitment;
            details.currentIndex = (challenge.start + challenge.end) / 2;
            challenge.status = COMMIT_NOT_AGREED;
        }
    }

    /// @notice Handles ongoing opinion submission.
    /// @param challenge The challenge being addressed.
    /// @param _agreed Boolean indicating if the opinion agrees with the commitment.
    function _handleOngoingStatus(Challenge storage challenge, bool _agreed) internal {
        ChallengeDetatils storage details = challengeDetailsMap[challenge.nonce];

        if (_agreed) {
            details.consensusIndex = details.currentIndex;
            details.consensusCommitment = details.currAggregateCommitment;
            challenge.status = TEMPORARY_AGREEMENT;
        } else {
            details.noConsensusIndex = details.currentIndex;
            details.noConsensusCommitment = details.currAggregateCommitment;
            challenge.status = COMMIT_NOT_AGREED;
        }

        if (details.consensusIndex == details.noConsensusIndex - 1) {
            if (details.consensusIndex == challenge.start) {
                details.consensusCommitment = aggregateCommitment(challenge.start, challenge.nameSpaceKey, challenge.r);
            }
            bool isValid = verifyAggregateCommitment(
                details.consensusCommitment,
                details.noConsensusCommitment,
                details.noConsensusIndex,
                challenge.nameSpaceKey,
                challenge.r
            );
            challenge.status = isValid ? CHALLENGE_SUCCESSFUL : CHALLENGE_FAILED;
        }

        details.currentIndex = (details.noConsensusIndex + details.consensusIndex) / 2;
    }

    /// @notice Verifies an aggregate commitment.
    /// @param _consensusCommitment Commitment point where consensus was reached.
    /// @param _aggregateCommitment Aggregate commitment point.
    /// @param _index Index being evaluated.
    /// @param _nameSpaceKey Namespace key associated with the challenge.
    /// @param _r Random value used in the challenge.
    /// @return Boolean indicating if the aggregate commitment is valid.
    function verifyAggregateCommitment(
        Pairing.G1Point memory _consensusCommitment,
        Pairing.G1Point memory _aggregateCommitment,
        uint256 _index,
        bytes32 _nameSpaceKey,
        uint256 _r
    )
        public
        view
        returns (bool)
    {
        bytes32 hash = Hashing.hashFold(_r, _index);
        Pairing.G1Point memory n0 = Pairing.mulScalar(commitment(_index, _nameSpaceKey), uint256(hash));
        Pairing.G1Point memory n1 = Pairing.plus(_consensusCommitment, n0);
        return Pairing.equal(_aggregateCommitment, n1);
    }

    /// @notice Verifies a commitment proof.
    /// @param _commitment Commitment point.
    /// @param _proof Proof point.
    /// @param _index Index of the commitment.
    /// @param _value Value to be proven.
    /// @return Boolean indicating if the proof is valid.
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

    /// @notice Computes the aggregate commitment for a given index, namespace key, and random value.
    /// @param _index Index being evaluated.
    /// @param _nameSpaceKey Namespace key associated with the challenge.
    /// @param _r Random value used in the challenge.
    /// @return Aggregate commitment point.
    function aggregateCommitment(
        uint256 _index,
        bytes32 _nameSpaceKey,
        uint256 _r
    )
        public
        view
        returns (Pairing.G1Point memory)
    {
        Pairing.G1Point memory n0 = commitment(_index, _nameSpaceKey);
        bytes32 hash = Hashing.hashFold(_r, _index);
        return Pairing.mulScalar(n0, uint256(hash));
    }

    /// @notice Gets the commitment for a given index and namespace key.
    /// @param _index Index being evaluated.
    /// @param _nameSpaceKey Namespace key associated with the challenge.
    /// @return Commitment point.
    function commitment(uint256 _index, bytes32 _nameSpaceKey) public view returns (Pairing.G1Point memory) {
        return commitmentManager.getNameSpaceCommitment(_nameSpaceKey, _index);
    }
}
