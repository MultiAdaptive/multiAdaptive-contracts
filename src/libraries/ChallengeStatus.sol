// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract ChallengeStatus {
    uint8 internal constant CHALLENGE_CREATED = 0;
    uint8 internal constant FIRST_COMMIT_SUBMITTED = 1;
    uint8 internal constant RECOMMIT_SUBMITTED = 2;
    uint8 internal constant COMMIT_NOT_AGREED = 3;
    uint8 internal constant TEMPORARY_AGREEMENT = 4;
    uint8 internal constant AGREEMENT_REACHED = 5;
    uint8 internal constant CHALLENGE_SUCCESSFUL = 6;
    uint8 internal constant CHALLENGE_FAILED = 7;
}
