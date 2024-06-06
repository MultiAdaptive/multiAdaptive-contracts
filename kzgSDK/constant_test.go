package main

import (
	"crypto/rand"
	"fmt"
	"github.com/consensys/gnark-crypto/ecc/bn254/fr"
	"github.com/consensys/gnark-crypto/ecc/bn254/fr/kzg"
	"github.com/status-im/keycard-go/hexutils"
	"github.com/stretchr/testify/assert"
	"math/big"
	"os"
	"testing"
	"time"
)

func TestSRSFromSol(t *testing.T) {

	ConsPolynomial := ConstPoly()
	//println(ConsPolynomial[0].String())
	srs, _ := SRSFromSol()
	Commit, err := kzg.Commit(ConsPolynomial, srs.Pk)
	if err != nil {
		t.Fatal(err)
	}
	var open fr.Element
	open.SetRandom()
	var proof kzg.OpeningProof
	proof, err = kzg.Open(ConsPolynomial, open, srs.Pk)
	err = kzg.Verify(&Commit, &proof, open, srs.Vk)
	if err != nil {
		panic(err)
	}

}
func TestConstPolys(t *testing.T) {
	ps := ConstPolys()
	srs, _ := SRSFromSol()
	cs := make([]kzg.Digest, len(ps))
	for i := 0; i < len(ps); i++ {
		cs[i], _ = kzg.Commit(ps[i], srs.Pk)
	}
	gammaR := string("8956114444546472096905889919082729794348506031815874064517970911421382129191")
	openString := string("14717431381412684312242958025344435075661116310517857129509110506817203556416")
	var gammaFr fr.Element
	gammaFr.SetString(gammaR)
	var openFr fr.Element
	openFr.SetString(openString)

	Commit012, _ := FoldedCommits(cs, gammaFr, 0, 3)
	Commit01, _ := FoldedCommits(cs, gammaFr, 0, 2)

	gammaHash := GetRandomHash(gammaFr, uint(2))
	var gammaBigInt big.Int
	gammaBigInt.SetBytes(gammaHash.Bytes())
	var Commit2Index kzg.Digest
	Commit2Index.ScalarMultiplication(&cs[2], &gammaBigInt)

	gammaHash0 := GetRandomHash(gammaFr, uint(0))

	var gammaBigInt0 big.Int
	gammaBigInt0.SetBytes(gammaHash0.Bytes())

	var Commit0Index kzg.Digest
	Commit0Index.ScalarMultiplication(&cs[0], &gammaBigInt)
	println("gammaHash0", gammaBigInt.String())
	println("commit0:", cs[0].String())
	println("	commit0index", Commit0Index.String())

	var NewCommitO12 kzg.Digest
	NewCommitO12.Add(&Commit2Index, &Commit01)
	assert.Equal(t, Commit012, NewCommitO12)
	assert.Equal(t, Commit012, NewCommitO12)

	foldPoly := FoldedPolynomials(ps, gammaFr)
	proof, err := kzg.Open(foldPoly, openFr, srs.Pk)
	if err != nil {
		panic(err)
	}
	err = kzg.Verify(&Commit012, &proof, openFr, srs.Vk)
	if err != nil {
		panic(err)
	}
	for i := 0; i < numPolynomials; i++ {
		println("承诺", i, cs[i].String())
	}
	println("聚合承诺{0,1,2}:", Commit012.String())
	FoldCommit01, _ := FoldedCommits(cs, gammaFr, 0, 2)
	println("聚合承诺{0,1}:", FoldCommit01.String())
	println("打开点", openFr.String())
	println("随机数", gammaFr.String())
	println("证明", proof.H.String())
	println("打开值", proof.ClaimedValue.String())

	println("hash", hexutils.BytesToHex(gammaHash.Bytes()))
	println("mulScalar", Commit2Index.String())
	println("puls", NewCommitO12.String())

	X := string("4609433240464190393630369188019246732157453029070459264096117840426817898433")
	Y := string("13127155654090834813926862403470794676157269288827208827646200804414516262849")
	var Testcommit kzg.Digest
	Testcommit.X.SetString(X)
	Testcommit.Y.SetString(Y)

	poly := make([]fr.Element, 2)
	poly[0].SetBytes(hexutils.HexToBytes("5CD05D95d897e4380a0909044D309f04A13B4DeB"))
	poly[1].SetBytes(hexutils.HexToBytes("0000000000000000000000000000000000000008"))

	polyCommit, _ := kzg.Commit(poly, srs.Pk)

	commits := make([]kzg.Digest, 3)
	Polys := make([][]fr.Element, len(commits))
	for i := range Polys {
		Polys[i] = make([]fr.Element, 2)
	}
	for i := 0; i < 3; i++ {
		commits[i] = polyCommit
		Polys[i] = poly
	}

	TestGamma := string("88888")
	var Gamma fr.Element
	Gamma.SetString(TestGamma)
	FoldPoly := FoldedPolynomials(Polys, Gamma)

	TestgammaHash := GetRandomHash(Gamma, uint(2))
	var TestgammaBigInt big.Int
	TestgammaBigInt.SetBytes(TestgammaHash.Bytes())

	Foldcommits3, _ := FoldedCommits(commits, Gamma, 0, 3)
	Foldcommits2, _ := FoldedCommits(commits, Gamma, 0, 2)

	assert.Equal(t, Testcommit, polyCommit)

	proofTest, _ := kzg.Open(FoldPoly, openFr, srs.Pk)
	err = kzg.Verify(&Foldcommits3, &proofTest, openFr, srs.Vk)
	if err != nil {
		panic(err)
	}
	println("三个承诺的聚合：", Foldcommits3.String())
	println("挑战点", openFr.String())
	println("打开值", proofTest.ClaimedValue.String())
	println("前两个聚合承诺：", Foldcommits2.String())

	var TestCommit2Index2 kzg.Digest
	TestCommit2Index2.ScalarMultiplication(&commits[2], &TestgammaBigInt)
	var TestNewCommitO12 kzg.Digest
	TestNewCommitO12.Add(&Foldcommits2, &TestCommit2Index2)
	assert.Equal(t, TestNewCommitO12, Foldcommits3)

}

func TestGenerateSRSFile(t *testing.T) {
	err := GenerateSRSFile()
	if err != nil {
		t.Fatal(err)
	}

}

func TestSRSPerformance(t *testing.T) {
	srsSize := new(big.Int).Exp(big.NewInt(2), big.NewInt(20), nil).Uint64()
	srs, _ := kzg.NewSRS(srsSize, big.NewInt(42))

	const dataSize = 10 * 1024 * 1024 // 5 MB
	data := make([]byte, dataSize)
	_, err := rand.Read(data)
	if err != nil {
		fmt.Println("Error generating random data:", err)
		return
	}
	time0 := time.Now()

	gamma := dataToPolynomial(data)
	time1 := time.Now()
	// compute ∑ᵢγⁱfᵢ
	commit, _ := kzg.Commit(gamma, srs.Pk)
	time2 := time.Now()

	openString := string("14717431381412684312242958025344435075661116310517857129509110506817203556416")
	var openFr fr.Element
	openFr.SetString(openString)

	proof, err := kzg.Open(gamma, openFr, srs.Pk)
	if err != nil {
		panic(err)
	}
	time3 := time.Now()

	for i := 0; i < 1000; i++ {
		err = kzg.Verify(&commit, &proof, openFr, srs.Vk)
		if err != nil {
			panic(err)
		}
	}

	time4 := time.Now()
	fmt.Printf("转换时间: %.2f\n", time1.Sub(time0).Seconds())
	fmt.Printf("承诺时间: %.2f\n", time2.Sub(time1).Seconds())
	fmt.Printf("Proof时间: %.2f\n", time3.Sub(time2).Seconds())
	fmt.Printf("Verify时间: %.2f\n", time4.Sub(time3).Seconds())
	file, err := os.Create("./srs")
	if err != nil {
		fmt.Println("create file failed, ", err)
	}
	defer file.Close()
	srs.WriteTo(file)
	if err != nil {
		fmt.Println("write file failed, ", err)
	}
	//fmt.Printf(commit.String(), proof.H.String())
}

func TestSRSPerformanceTwo(t *testing.T) {
	srsSize := new(big.Int).Exp(big.NewInt(2), big.NewInt(20), nil).Uint64()
	srs, _ := kzg.NewSRS(srsSize, big.NewInt(42))

	//num := 8192
	num := 81920
	polynomials := make([][]fr.Element, num)
	commits := make([]kzg.Digest, num)
	const dataSize = 128 * 1024

	time0 := time.Now()
	for i := 0; i < num; i++ {
		data := make([]byte, dataSize)
		_, err := rand.Read(data)
		if err != nil {
			fmt.Println("Error generating random data:", err)
			return
		}
		polynomial := dataToPolynomial(data)
		commit, _ := kzg.Commit(polynomial, srs.Pk)
		polynomials[i] = polynomial
		commits[i] = commit

	}
	// compute ∑ᵢγⁱfᵢ
	time1 := time.Now()
	openString := string("14717431381412684312242958025344435075661116310517857129509110506817203556416")
	var openFr fr.Element
	openFr.SetString(openString)
	var r fr.Element
	r.SetRandom()

	proof := Responce(polynomials, openFr, r, srs)
	time2 := time.Now()

	aggreCommit, err := FoldedCommits(commits, r, 0, uint(num))
	if err != nil {
		panic(err)
	}
	time3 := time.Now()
	err = kzg.Verify(&aggreCommit, &proof, openFr, srs.Vk)
	if err != nil {
		panic(err)
	}
	time4 := time.Now()

	fmt.Printf("准备数据时间: %.2f\n", time1.Sub(time0).Seconds())
	fmt.Printf("生成proof时间: %.2f\n", time2.Sub(time1).Seconds())
	fmt.Printf("聚合承诺时间: %.2f\n", time3.Sub(time2).Seconds())
	fmt.Printf("验证时间: %.6f\n", time4.Sub(time3).Seconds())

}
