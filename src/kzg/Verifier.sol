pragma solidity ^0.8.0;

import "./Pairing.sol";
import { Constants } from "./Constants.sol";

// Declaration that the technical structure of this contract is based on code from:
// https://github.com/weijiekoh/libkzg.git

contract Verifier is Constants {
    using Pairing for *;

    // The G1 generator
    Pairing.G1Point SRS_G1_0 = Pairing.G1Point({ X: Constants.SRS_G1_X[0], Y: Constants.SRS_G1_Y[0] });

    // The G2 generator
    Pairing.G2Point g2Generator = Pairing.G2Point({
        X: [Constants.SRS_G2_X_0[0], Constants.SRS_G2_X_1[0]],
        Y: [Constants.SRS_G2_Y_0[0], Constants.SRS_G2_Y_1[0]]
    });

    Pairing.G2Point SRS_G2_1 = Pairing.G2Point({
        X: [Constants.SRS_G2_X_0[1], Constants.SRS_G2_X_1[1]],
        Y: [Constants.SRS_G2_Y_0[1], Constants.SRS_G2_Y_1[1]]
    });

    /*
     * Verifies a single-point evaluation of a polynominal using the KZG
     * commitment scheme.
     *    - p(X) is a polynominal
     *    - _value = p(_index)
     *    - commitment = commit(p)
     *    - proof = genProof(p, _index, _value)
     * Returns true if and only if the following holds, and returns false
     * otherwise:
     *     e(commitment - commit([_value]), G2.g) == e(proof, commit([0, 1]) - zCommit)
     * @param _commitment The KZG polynominal commitment.
     * @param _proof The proof.
     * @param _index The x-value at which to evaluate the polynominal.
     * @param _value The result of the polynominal evaluation.
     */
    function verify(
        Pairing.G1Point memory _commitment,
        Pairing.G1Point memory _proof,
        uint256 _index,
        uint256 _value
    )
        public
        view
        returns (bool)
    {
        // Make sure each parameter is less than the prime q
        require(_commitment.X < BABYJUB_P, "Verifier.verifyKZG: _commitment.X is out of range");
        require(_commitment.Y < BABYJUB_P, "Verifier.verifyKZG: _commitment.Y is out of range");
        require(_proof.X < BABYJUB_P, "Verifier.verifyKZG: _proof.X is out of range");
        require(_proof.Y < BABYJUB_P, "Verifier.verifyKZG: _proof.Y is out of range");
        require(_index < BABYJUB_P, "Verifier.verifyKZG: _index is out of range");
        require(_value < BABYJUB_P, "Verifier.verifyKZG: _value is out of range");

        // Check that
        //     e(commitment - aCommit, G2.g) == e(proof, xCommit - zCommit)
        //     e(commitment - aCommit, G2.g) / e(proof, xCommit - zCommit) == 1
        //     e(commitment - aCommit, G2.g) * e(proof, xCommit - zCommit) ^ -1 == 1
        //     e(commitment - aCommit, G2.g) * e(-proof, xCommit - zCommit) == 1
        // where:
        //     aCommit = commit([_value]) = SRS_G1_0 * _value
        //     xCommit = commit([0, 1]) = SRS_G2_1
        //     zCommit = commit([_index]) = SRS_G2_1 * _index

        // To avoid having to perform an expensive operation in G2 to compute
        // xCommit - zCommit, we instead check the equivalent equation:
        //     e(commitment - aCommit, G2.g) * e(-proof, xCommit) * e(-proof, -zCommit) == 1
        //     e(commitment - aCommit, G2.g) * e(-proof, xCommit) * e(proof, zCommit) == 1
        //     e(commitment - aCommit, G2.g) * e(-proof, xCommit) * e(index * proof, G2.g) == 1
        //     e((index * proof) + (commitment - aCommit), G2.g) * e(-proof, xCommit) == 1

        // Compute commitment - aCommitment
        Pairing.G1Point memory commitmentMinusA =
            Pairing.plus(_commitment, Pairing.negate(Pairing.mulScalar(SRS_G1_0, _value)));

        // Negate the proof
        Pairing.G1Point memory negProof = Pairing.negate(_proof);

        // Compute index * proof
        Pairing.G1Point memory indexMulProof = Pairing.mulScalar(_proof, _index);

        // Returns true if and only if
        // e((index * proof) + (commitment - aCommitment), G2.g) * e(-proof, xCommit) == 1
        return Pairing.pairing(Pairing.plus(indexMulProof, commitmentMinusA), g2Generator, negProof, SRS_G2_1);
    }

    /*
     * @return The polynominal evaluation of a polynominal with the specified
     *         coefficients at the given index.
     */
    function evalPolyAt(uint256[] memory _coefficients, uint256 _index) public pure returns (uint256) {
        uint256 m = Constants.BABYJUB_P;
        uint256 result = 0;
        uint256 powerOfX = 1;

        for (uint256 i = 0; i < _coefficients.length; i++) {
            uint256 coeff = _coefficients[i];
            assembly {
                result := addmod(result, mulmod(powerOfX, coeff, m), m)
                powerOfX := mulmod(powerOfX, _index, m)
            }
        }
        return result;
    }
}
