package main

import (
	"github.com/consensys/gnark-crypto/ecc"
	"github.com/consensys/gnark-crypto/ecc/bn254/fr"
	"github.com/consensys/gnark-crypto/ecc/bn254/fr/kzg"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
)

const dChunkSize = 30

type DomiconSdk struct {
	srs *kzg.SRS
}

// FoldedCommits computes a folded commitment from a slice of commitments using a gamma element.
func FoldedCommits(
	Commits []kzg.Digest,
	gamma fr.Element,
	from uint,
	to uint,
) (kzg.Digest, error) {
	var AggreCommit kzg.Digest
	//Generate random hashes based on gamma, from, and to indices
	gammasBytes := GetRandomsHash(gamma, from, to)
	gammas := HashToFrElements(gammasBytes)
	_, err := AggreCommit.MultiExp(Commits[from:to], gammas[from:to], ecc.MultiExpConfig{})
	return AggreCommit, err
}

func HashToFrElements(gammasHash []common.Hash) []fr.Element {
	gammas := make([]fr.Element, len(gammasHash))
	for i, datum := range gammasHash {
		gammas[i] = *gammas[i].SetBytes(datum.Bytes())
	}
	return gammas
}

func chunkBytes(data []byte, chunkSize int) [][]byte {
	var chunks [][]byte
	for i := 0; i < len(data); i += chunkSize {
		end := i + chunkSize
		if end > len(data) {
			end = len(data)
		}
		chunks = append(chunks, data[i:end])
	}
	return chunks
}

// dataToPolynomial converts byte data into a slice of fr.Element representing a polynomial.
func dataToPolynomial(data []byte) []fr.Element {
	chunks := chunkBytes(data, dChunkSize)
	chunksLen := len(chunks)
	ps := make([]fr.Element, chunksLen)
	for i, chunk := range chunks {
		ps[i].SetBytes(chunk)
	}
	return ps
}

// FoldedPolynomials computes a folded polynomial from a slice of polynomials using a gamma element.
func FoldedPolynomials(
	polynomials [][]fr.Element,
	gamma fr.Element,
) []fr.Element {
	// Generate random hashes based on gamma and the number of polynomials
	gammasBytes := GetRandomsHash(gamma, 0, uint(len(polynomials)))
	gammas := HashToFrElements(gammasBytes)
	// compute ∑ᵢγⁱfᵢ
	// find the largest polynomial
	largestPoly := len(polynomials[0])
	for i := 1; i < len(polynomials); i++ {
		if len(polynomials[i]) > largestPoly {
			largestPoly = len(polynomials[i])
		}
	}
	FoldedPolynomial := make([]fr.Element, largestPoly)
	for i := 0; i < len(polynomials); i++ {
		var pj fr.Element
		for j := 0; j < len(polynomials[i]); j++ {
			pj.Mul(&polynomials[i][j], &gammas[i])
			FoldedPolynomial[j].Add(&FoldedPolynomial[j], &pj)
		}
	}
	return FoldedPolynomial
}

// Responce generates an opening proof of polynomials using the KZG commitment scheme.
//
//	polynomials: Coefficients of polynomials, represented as a 2D array of fr.Element.
//	openPoint: Point at which the polynomial is opened for verification.
//	gamma: Value used for folding the polynomial.
//	srs: Setup parameters for KZG.
func Responce(
	polynomials [][]fr.Element,
	openPoint fr.Element,
	gamma fr.Element,
	srs *kzg.SRS,
) kzg.OpeningProof {
	//Transform the array of polynomials into a single polynomial using gamma.
	FoldPoly := FoldedPolynomials(polynomials, gamma)
	//Compute the proof of the polynomial FoldPoly  at the opening point.
	proof, err := kzg.Open(FoldPoly, openPoint, srs.Pk)
	if err != nil {
		panic(err)
	}
	return proof
}

// Responce generates an opening proof of datas using the KZG commitment scheme.

// datas: represented as a 2D array of byte.
// openPoint: Point at which the polynomial is opened for verification.
// gamma: Value used for folding the polynomial.
// srs: Setup parameters for KZG.
func ResponceDatas(
	datas [][]byte,
	openPoint fr.Element,
	gamma fr.Element,
	srs *kzg.SRS,
) kzg.OpeningProof {
	polynomials := make([][]fr.Element, len(datas))
	//transform the datas to polynomials
	for i, data := range datas {
		polynomials[i] = dataToPolynomial(data)
	}
	//transform the polynomials to a fold polynomial
	FoldPoly := FoldedPolynomials(polynomials, gamma)
	//calculate the proof of fold polynomial
	proof, err := kzg.Open(FoldPoly, openPoint, srs.Pk)
	if err != nil {
		panic(err)
	}
	return proof
}

// PutUint256 encodes an unsigned 64-bit integer v into the last 8 bytes of byte slice b.
// It ensures that only the last 8 bytes are modified, filling the preceding bytes with zeros.
func PutUint256(b []byte, v uint64) {
	// Early bounds check to guarantee safety of writes below
	_ = b[31]
	b[24] = byte(v >> 56)
	b[25] = byte(v >> 48)
	b[26] = byte(v >> 40)
	b[27] = byte(v >> 32)
	b[28] = byte(v >> 24)
	b[29] = byte(v >> 16)
	b[30] = byte(v >> 8)
	b[31] = byte(v)
	// Fill the remaining bytes with zeros
	for i := 0; i < 24; i++ {
		b[i] = 0
	}
}

// Calculate r_i=hash(gamma,index)
func GetRandomHash(gamma fr.Element, index uint) common.Hash {
	// Marshal gamma to bytes
	gammaBytes := gamma.Marshal()
	//Prepare a 32-byte slice for FillBytes32
	FillBytes32 := make([]byte, 32)

	PutUint256(FillBytes32, uint64(index))
	data := append(gammaBytes, FillBytes32...)
	return crypto.Keccak256Hash(data)
}
func GetRandomsHash(gamma fr.Element, from uint, to uint) []common.Hash {
	gammas := make([]common.Hash, 0)
	var tempGamma common.Hash
	for i := from; i < to; i++ {
		tempGamma = GetRandomHash(gamma, i)
		gammas = append(gammas, tempGamma)
	}
	return gammas
}
