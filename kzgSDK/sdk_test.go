package main

import (
	"fmt"
	"github.com/ethereum/go-ethereum/common"
	"github.com/status-im/keycard-go/hexutils"
	"math/big"
	"testing"

	"github.com/consensys/gnark-crypto/ecc"
	"github.com/consensys/gnark-crypto/ecc/bn254/fr"
	"github.com/consensys/gnark-crypto/ecc/bn254/fr/kzg"
	"github.com/stretchr/testify/assert"
)

// const benchSize = 1 << 5
const benchSize = 129
const numPolynomials = 3
const PolynomialLen = 10

func TestFoldedPolynomials(t *testing.T) {
	srs, err := kzg.NewSRS(ecc.NextPowerOfTwo(benchSize), new(big.Int).SetInt64(42))
	assert.NoError(t, err)
	// Create a DomiconSdk instance
	sdk := &DomiconSdk{}
	sdk.srs = srs
	// Create random polynomials
	ps := make([][]fr.Element, numPolynomials)
	for i := 0; i < numPolynomials; i++ {
		ps[i] = randomPolynomial(benchSize / 2)
	}
	//crate random number to fold
	var gamma fr.Element
	gamma.SetRandom()

	// compute ∑ᵢγⁱfᵢ
	foldpoly := FoldedPolynomials(ps, gamma)

	//sdk.AggrePoy = foldpoly
	//compute the commitment of FoldedPolynomial
	foldpolyCommit, err := kzg.Commit(foldpoly, sdk.srs.Pk)
	// commitments
	cs := make([]kzg.Digest, numPolynomials)
	for i := 0; i < numPolynomials; i++ {
		cs[i], _ = kzg.Commit(ps[i], srs.Pk)
	}
	AggreCommit, err := FoldedCommits(cs, gamma, 0, numPolynomials)
	equalCommit := foldpolyCommit.Equal(&AggreCommit)
	if !equalCommit {
		println("AggreCommit is not equal to foldpolyCommit")
	} else {
		println("AggreCommit is equal to foldpolyCommit")
	}
	//crate random number as the open point
	var open fr.Element
	open.SetRandom()
	openProof, err := kzg.Open(foldpoly, open, sdk.srs.Pk)
	//verify e(foldpolyCommit-openProof.ClaimValue,1)?=e(openproof.H, x-open)
	err = kzg.Verify(&AggreCommit, &openProof, open, sdk.srs.Vk)
	if err != nil {
		println("AggreCommit vs openProof  failed ")
	} else {
		println("AggreCommit vs openProof succeed")
	}
	assert.NoError(t, err)
}
func TestResponce(t *testing.T) {
	srs, err := kzg.NewSRS(ecc.NextPowerOfTwo(benchSize), new(big.Int).SetInt64(42))
	assert.NoError(t, err)
	srs.Vk.G1 = srs.Pk.G1[0]
	// Create a DomiconSdk instance
	sdk := &DomiconSdk{}
	sdk.srs = srs
	// Create random polynomials
	ps := make([][]fr.Element, numPolynomials)
	cs := make([]kzg.Digest, numPolynomials)
	for i := 0; i < numPolynomials; i++ {
		ps[i] = randomPolynomial(benchSize / 2)
		cs[i], _ = kzg.Commit(ps[i], sdk.srs.Pk)
	}
	//crate random number to fold
	var r fr.Element
	r.SetRandom()
	gammas := make([]fr.Element, numPolynomials)
	gammas[0] = r
	var open fr.Element
	open.SetRandom()
	//calculate the proof and openValue of polynomials ps
	proof := Responce(ps, open, gammas[0], srs)
	//calculate commits using foldfactor r
	FoldCommit, _ := FoldedCommits(cs, gammas[0], 0, numPolynomials)
	//Verify the correctness of the response
	err = kzg.Verify(&FoldCommit, &proof, open, sdk.srs.Vk)
	assert.NoError(t, err)
}
func randomPolynomial(size int) []fr.Element {
	f := make([]fr.Element, size)
	for i := 0; i < size; i++ {
		f[i].SetRandom()
	}
	return f
}

func TestGetRandomHash(t *testing.T) {

	r := string("8956114444546472096905889919082729794348506031815874064517970911421382129191")

	var gamma fr.Element
	gamma.SetString(r)

	index := uint(2778)

	HashResult := GetRandomHash(gamma, index)

	hashResult := hexutils.BytesToHex(HashResult.Bytes())
	println("hashResult:", hashResult)
}

func TestGetRandomsHash(t *testing.T) {
	var gamma fr.Element
	var from, to uint
	from = 2
	to = 5
	num := int(to - from)
	gamma.SetRandom()
	result := GetRandomsHash(gamma, from, to)
	assert.Equal(t, num, len(result), "Lengths should match")
	for i, val := range result {
		assert.NotEqual(t, common.Hash{}, val, fmt.Sprintf("Hash at index %d should not be empty", i))
	}
}

func TestResponceDatas(t *testing.T) {

	srs, err := SRSFromSol()
	if err != nil {
		panic(err)
	}
	datas := make([][]byte, 3)
	datas[0] = []byte("The sampling party generates n+1 distinct points")
	datas[1] = []byte("Broadcast nodes calculate the values of sampling points and Providing corresponding values and proof.")
	datas[2] = []byte("The sampling party verifies the correctness of the values of sampling points")

	polys := make([][]fr.Element, 3)
	cs := make([]kzg.Digest, 3)
	for i, data := range datas {
		polys[i] = dataToPolynomial(data)
		cs[i], err = kzg.Commit(polys[i], srs.Pk)
	}
	gammaR := string("8956114444546472096905889919082729794348506031815874064517970911421382129191")
	var gammaFr fr.Element
	gammaFr.SetString(gammaR)

	foldCm, err := FoldedCommits(cs, gammaFr, 0, 3)
	if err != nil {
		panic(err)
	}
	openString := string("14717431381412684312242958025344435075661116310517857129509110506817203556416")
	var openFr fr.Element
	openFr.SetString(openString)

	proof := ResponceDatas(datas, openFr, gammaFr, srs)

	err = kzg.Verify(&foldCm, &proof, openFr, srs.Vk)
	if err != nil {
		panic(err)
	}

}
