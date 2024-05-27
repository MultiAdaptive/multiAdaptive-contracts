package main

import (
	"github.com/consensys/gnark-crypto/ecc/bn254/fr"
	"github.com/consensys/gnark-crypto/ecc/bn254/fr/kzg"
)

const DemoPolynomialsNum = 3
const DemoBenchSize = 129

func main() {
	srs, err := SRSFromSol()
	if err != nil {
		panic(err)
	}
	ps := make([][]fr.Element, DemoPolynomialsNum)
	cs := make([]kzg.Digest, DemoPolynomialsNum)
	for i := 0; i < DemoPolynomialsNum; i++ {
		ps[i] = DemoRandomPolynomial(DemoBenchSize / 2)
		cs[i], _ = kzg.Commit(ps[i], srs.Pk)
	}
	var r fr.Element
	r.SetRandom()
	//crate random number open as open point
	var open fr.Element
	open.SetRandom()
	proof := Responce(ps, open, r, srs)
	var FoldedCommit kzg.Digest
	FoldedCommit, err = FoldedCommits(cs, r, 0, DemoPolynomialsNum)
	if err != nil {
		panic(err)
	}
	err = kzg.Verify(&FoldedCommit, &proof, open, srs.Vk)
	if err != nil {
		panic(err)
	}
	println("success")
}

func DemoRandomPolynomial(size int) []fr.Element {
	f := make([]fr.Element, size)
	for i := 0; i < size; i++ {
		f[i].SetRandom()
	}
	return f
}
