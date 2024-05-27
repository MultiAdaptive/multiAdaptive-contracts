package main

import (
	"github.com/consensys/gnark-crypto/ecc"
	bn254 "github.com/consensys/gnark-crypto/ecc/bn254"
	"github.com/consensys/gnark-crypto/ecc/bn254/fr"
	"github.com/consensys/gnark-crypto/ecc/bn254/fr/kzg"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/holiman/uint256"
)

const dChunkSize = 30

type DomiconSdk struct {
	srs *kzg.SRS
}
type ProofSol struct {
	proof     bn254.G1Affine
	openValue uint256.Int
}

func FoldedCommits(
	Commits []kzg.Digest,
	gamma fr.Element,
	from uint,
	to uint,
) (kzg.Digest, error) {
	var AggreCommit kzg.Digest
	gammasBytes := GetRandomsHash(gamma, from, to)
	gammas := HashToFrElements(gammasBytes)
	_, err := AggreCommit.MultiExp(Commits[from:to], gammas[from:to], ecc.MultiExpConfig{})
	return AggreCommit, err
}
func FoldedCommitsUnit(
	Commits []kzg.Digest,
	gamma uint256.Int,
	from uint,
	to uint,
) (kzg.Digest, error) {
	var AggreCommit kzg.Digest
	gammasBytes := GetRandomsHashUnit256(gamma, from, to)
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

func dataToPolynomial(data []byte) []fr.Element {
	chunks := chunkBytes(data, dChunkSize)
	chunksLen := len(chunks)

	ps := make([]fr.Element, chunksLen)
	for i, chunk := range chunks {
		ps[i].SetBytes(chunk)
	}
	return ps
}
func dataToPolynomialUnit(data []byte) []uint256.Int {
	chunks := chunkBytes(data, dChunkSize)
	chunksLen := len(chunks)
	ps := make([]uint256.Int, chunksLen)
	for i, chunk := range chunks {
		ps[i].SetBytes(chunk)
	}
	return ps
}
func PolynomialChangeToFr(poly []uint256.Int) []fr.Element {
	PolynomialFr := make([]fr.Element, len(poly))
	for i, temppoly := range poly {
		polybytes := temppoly.Bytes()
		PolynomialFr[i].SetBytes(polybytes)
	}
	return PolynomialFr
}

func FoldedPolynomialsUnit(
	polynomialsUnit [][]uint256.Int,
	gamma uint256.Int,
) []fr.Element {
	polynomials := make([][]fr.Element, len(polynomialsUnit))
	//var TempPolynomials []fr.Element
	for i, cuPoly := range polynomialsUnit {
		polynomials[i] = PolynomialChangeToFr(cuPoly)
	}
	gammasBytes := GetRandomsHashUnit256(gamma, 0, uint(len(polynomials)))
	gammas := HashToFrElements(gammasBytes)
	//gammas := GetRandomsHash(gamma, len(polynomials))
	// compute ∑ᵢγⁱfᵢ
	// find the largest polynomial
	largestPoly := len(polynomials[0])
	for i := 1; i < len(polynomials); i++ {
		if len(polynomials[i]) > largestPoly {
			largestPoly = len(polynomials[i])
		}
	}
	FoldedPolynomial := make([]fr.Element, largestPoly)
	//FoldedPolynomialUnit := make([]uint256.Int, largestPoly)
	for i := 0; i < len(polynomials); i++ {
		var pj fr.Element
		for j := 0; j < len(polynomials[i]); j++ {
			pj.Mul(&polynomials[i][j], &gammas[i])
			FoldedPolynomial[j].Add(&FoldedPolynomial[j], &pj)
		}
		//FoldedPolynomialUnit[i] = FoldedPolynomial[i].Bits()
	}
	return FoldedPolynomial
}

func FoldedPolynomials(
	polynomials [][]fr.Element,
	gamma fr.Element,
) []fr.Element {
	gammasBytes := GetRandomsHash(gamma, 0, uint(len(polynomials)))
	gammas := HashToFrElements(gammasBytes)
	//gammas := GetRandomsHash(gamma, len(polynomials))
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
func Responce(
	polynomials [][]fr.Element,
	openPoint fr.Element,
	gamma fr.Element,
	srs *kzg.SRS,
) kzg.OpeningProof {
	FoldPoly := FoldedPolynomials(polynomials, gamma)
	proof, err := kzg.Open(FoldPoly, openPoint, srs.Pk)
	if err != nil {
		println("failed to open FoldPoly")
		panic(err)
	}
	return proof
}
func ResponceUnit(
	polynomials [][]uint256.Int,
	openPoint uint256.Int,
	gamma uint256.Int,
	srs *kzg.SRS,
) kzg.OpeningProof {
	FoldPoly := FoldedPolynomialsUnit(polynomials, gamma)
	var openPointFr fr.Element
	openPointFr.SetBytes(openPoint.Bytes())
	proof, err := kzg.Open(FoldPoly, openPointFr, srs.Pk)
	if err != nil {
		println("failed to open FoldPoly")
		panic(err)
	}
	return proof
}
func ResponceDatas(
	datas [][]byte,
	openPoint fr.Element,
	gamma fr.Element,
	srs *kzg.SRS,
) kzg.OpeningProof {
	polynomials := make([][]fr.Element, len(datas))
	for i, data := range datas {
		polynomials[i] = dataToPolynomial(data)
	}
	FoldPoly := FoldedPolynomials(polynomials, gamma)
	proof, err := kzg.Open(FoldPoly, openPoint, srs.Pk)
	if err != nil {
		panic(err)
	}
	return proof
}
func ResponceUnitSol(
	polynomials [][]uint256.Int,
	openPoint uint256.Int,
	gamma uint256.Int,
	srs *kzg.SRS,
) ProofSol {
	FoldPoly := FoldedPolynomialsUnit(polynomials, gamma)
	var openPointFr fr.Element
	openPointFr.SetBytes(openPoint.Bytes())
	proof, err := kzg.Open(FoldPoly, openPointFr, srs.Pk)
	if err != nil {
		println("failed to open FoldPoly")
		panic(err)
	}
	return ProofSol{
		proof:     proof.H,
		openValue: proof.ClaimedValue.Bits(),
	}
}
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

func GetRandomHash(gamma fr.Element, index uint) common.Hash {
	gammaBytes := gamma.Marshal()
	FillBytes32 := make([]byte, 32)
	PutUint256(FillBytes32, uint64(index))
	data := append(gammaBytes, FillBytes32...)
	return crypto.Keccak256Hash(data)
}
func GetRandomsHash(gamma fr.Element, from uint, to uint) []common.Hash {
	gammas := make([]common.Hash, 0)
	var tempGamma common.Hash
	//gammas := make([]common.Hash, num)
	for i := from; i < to; i++ {
		tempGamma = GetRandomHash(gamma, i)
		gammas = append(gammas, tempGamma)
	}
	return gammas
}

func GetRandomHashUnit256(gamma uint256.Int, index uint) common.Hash {
	gammaU := gamma.Bytes()
	FillBytes32 := make([]byte, 32)

	PutUint256(FillBytes32, uint64(index))

	data := append(gammaU, FillBytes32...)
	return crypto.Keccak256Hash(data)
}
func GetRandomsHashUnit256(gamma uint256.Int, from uint, to uint) []common.Hash {
	//num := to - from
	gammas := make([]common.Hash, 0)
	var tempGamma common.Hash
	//gammas := make([]common.Hash, num)
	for i := from; i < to; i++ {
		tempGamma = GetRandomHashUnit256(gamma, i)
		gammas = append(gammas, tempGamma)
	}
	return gammas
}
