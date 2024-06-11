pragma solidity ^0.8.0;

import "./Pairing.sol";

/*
 * The values in this file come from challenge file #46 of the Perpetual Powers
 * of Tau ceremony. The Blake2b hash of challenge file is:
 *
 * 939038cd 2dc5a1c0 20f368d2 bfad8686 
 * 950fdf7e c2d2e192 a7d59509 3068816b
 * becd914b a293dd8a cb6d18c7 b5116b66 
 * ea54d915 d47a89cc fbe2d5a3 444dfbed
 *
 * The challenge file can be retrieved at:
 * https://ppot.blob.core.windows.net/public/challenge_0046
 *
 * The ceremony transcript can be retrieved at:
 * https://github.com/weijiekoh/perpetualpowersoftau
 *
 * Anyone can verify the transcript to ensure that the values in the challenge
 * file have not been tampered with. Moreover, as long as one participant in
 * the ceremony has discarded their toxic waste, the whole ceremony is secure.
 * Please read the following for more information:
*
https://medium.com/coinmonks/announcing-the-perpetual-powers-of-tau-ceremony-to-benefit-all-zk-snark-projects-c3da86af8377
 */

contract Constants {
    using Pairing for *;

    uint256 constant PRIME_Q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
    uint256 constant BABYJUB_P = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

    uint256[] SRS_G1_X = [uint256(0x0000000000000000000000000000000000000000000000000000000000000001)];

    uint256[] SRS_G1_Y = [uint256(0x0000000000000000000000000000000000000000000000000000000000000002)];

    uint256[] SRS_G2_X_0 = [
        uint256(0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2),
        uint256(0x12740934ba9615b77b6a49b06fcce83ce90d67b1d0e2a530069e3a7306569a91)
    ];

    uint256[] SRS_G2_X_1 = [
        uint256(0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6ed),
        uint256(0x116da8c89a0d090f3d8644ada33a5f1c8013ba7204aeca62d66d931b99afe6e7)
    ];

    uint256[] SRS_G2_Y_0 = [
        uint256(0x090689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975b),
        uint256(0x25222d9816e5f86b4a7dedd00d04acc5c979c18bd22b834ea8c6d07c0ba441db)
    ];

    uint256[] SRS_G2_Y_1 = [
        uint256(0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daa),
        uint256(0x076441042e77b6309644b56251f059cf14befc72ac8a6157d30924e58dc4c172)
    ];
}
