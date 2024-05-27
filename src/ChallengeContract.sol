// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ISemver} from "src/universal/ISemver.sol";
import {DomiconNode} from "src/DomiconNode.sol";
import {DomiconCommitment} from "src/DomiconCommitment.sol";
import {Hashing} from "src/libraries/Hashing.sol";
import {Verifier} from "src/kzg/Verifier.sol";
import {Pairing} from "src/kzg/Pairing.sol";

struct Challenge {
    uint nonce;
    uint8 status;
    address challenger;
    address storageAddr;
    address user;
    uint start;
    uint end;
    uint r;
    Pairing.G1Point aggregateCommitment;
    uint point;
    uint timeoutBlock;
}

struct ChallengeDetatils {
    uint consensusIndex;
    uint noConsensusIndex;
    uint currentIndex;
    Pairing.G1Point consensusCommitment;
    Pairing.G1Point noConsensusCommitment;
    Pairing.G1Point currAggregateCommitment;
}

contract ChallengeContract is Initializable, ISemver  {

    /// @notice Semantic version.
    /// @custom:semver 0.1.0
    string public constant version = "0.1.0";

    DomiconNode public domiconNode;

    DomiconCommitment public domiconCommitment;

    Verifier public verifier;

    mapping(uint => Challenge) public challenges;

    mapping(uint => ChallengeDetatils) public challengeDetailsMap;

    uint public nonce;

    event ChallengeCreated(uint nonce,address storageAddr,address user,uint start,uint end,uint r,uint timeoutBlock);

    event AggregateCommitmentUploaded(uint nonce,Pairing.G1Point aggregateCommitment,uint timeoutBlock);

    /// @notice Constructs the DomiconCommitment contract.
    constructor() {}

    /// @notice Initializer
    function initialize(DomiconNode _domiconNode,DomiconCommitment _domiconCommitment) public initializer {
        domiconNode = _domiconNode;
        domiconCommitment = _domiconCommitment;
        _transferOwnership(tx.origin);
    }


    function createChallenge(uint _start,uint _end,address _storageAddr,address _user,uint _r,uint _point) public payable {
        require(msg.value > 0, "ChallengeContract: minimum entry fee required");

        Challenge storage challenge = challenges[nonce];

        challenge.nonce = nonce;
        challenge.status = 0;
        challenge.challenger = msg.sender;
        challenge.storageAddr = _storageAddr;
        challenge.user = _user;
        challenge.start = _start;
        challenge.end = _end;
        challenge.r = _r;
        challenge.point = _point;
        challenge.timeoutBlock = block.number + 600;


        emit ChallengeCreated(nonce,_storageAddr,_user,_start,_end,_r,challenge.timeoutBlock);

        nonce ++;

    }

    function uploadAggregateCommitment(uint _challengeId, Pairing.G1Point calldata _commitment) public {
        Challenge storage challenge = challenges[_challengeId];

        require(challenge.status == 0||challenge.status==3, "ChallengeContract: challenge is already complete");

        require(challenge.timeoutBlock >= block.number, "ChallengeContract: timed out");

        require(msg.sender == challenge.storageAddr,"ChallengeContract: only the storage node can upload commitment");

        if (challenge.status == 0) {
            challenge.aggregateCommitment = _commitment;
            challenge.status = 1;

        } else {
            ChallengeDetatils storage details = challengeDetailsMap[challenge.nonce];
            details.currAggregateCommitment = _commitment;
            challenge.status = 2;
        }

        emit AggregateCommitmentUploaded(_challengeId, _commitment,challenge.timeoutBlock);

        challenge.timeoutBlock = block.number + 600;

    }

    function uploadProof(uint _challengeId, Pairing.G1Point calldata _proof,uint256 _value) public {
        Challenge storage challenge = challenges[_challengeId];

        require(challenge.status == 5, "ChallengeContract: consensus on commitment not reached");

        require(challenge.timeoutBlock >= block.number, "ChallengeContract: timed out");

        require(msg.sender == challenge.storageAddr,"ChallengeContract: only the storage node can upload commitment");

        bool isValid = verifyAggregateCommitment(challenge.aggregateCommitment,_proof,challenge.point,_value);

        challenge.status = isValid ? 8 : 7;

    }

    function submitOpinion(uint _challengeId,bool _agreed) public {
        Challenge storage challenge = challenges[_challengeId];

        require(challenge.challenger==msg.sender,"ChallengeContract: only the challenger can submit an opinion");

        require(challenge.status == 1 ||challenge.status == 2, "ChallengeContract: unsubmitted aggregate commitment");

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
                details.consensusCommitment = aggregateCommitment(challenge.start,challenge.user,challenge.r);
            }
            bool isValid = verifyAggregateCommitment(details.consensusCommitment,details.noConsensusCommitment,details.noConsensusIndex,challenge.user,challenge.r);
            challenge.status = isValid ? 8 : 7 ;
        }

        details.currentIndex = (details.noConsensusIndex + details.consensusIndex) / 2;
    }

    function verifyAggregateCommitment(Pairing.G1Point memory _consensusCommitment,Pairing.G1Point memory _aggregateCommitment, uint _index,address _user,uint256 _r) public view returns(bool){

        bytes32 hash = Hashing.hashFold(_r,_index);
        Pairing.G1Point memory n0 = Pairing.mulScalar(commitment(_index,_user),uint256(hash));
        Pairing.G1Point memory n1 = Pairing.plus(_consensusCommitment,n0);
        return Pairing.equal(_aggregateCommitment,n1);
    }

    function verifyAggregateCommitment(Pairing.G1Point memory _commitment,
        Pairing.G1Point memory _proof,
        uint256 _index,
        uint256 _value) public view returns (bool) {
        return verifier.verify(_commitment,_proof,_index,_value);
    }

    function aggregateCommitment(uint _index,address _user,uint _r) public view returns(Pairing.G1Point memory){
        Pairing.G1Point memory n0 = commitment(_index,_user);
        bytes32 hash = Hashing.hashFold(_r,_index);
        return Pairing.mulScalar(n0,uint256(hash));
    }

    function commitment(uint _index,address _user) public view returns(Pairing.G1Point memory){
        return domiconCommitment.getUserCommitments(_user,_index);
    }

    function SetKZG(address _addr) external onlyOwner {
        verifier = Verifier(_addr);
    }

}