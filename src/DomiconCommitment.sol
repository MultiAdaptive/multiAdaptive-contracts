// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ISemver} from "src/universal/ISemver.sol";
import {DomiconNode} from "src/DomiconNode.sol";
import {DomiconNode} from "src/DomiconNode.sol";
import {StorageManagement,DasKeySetInfo} from "src/StorageManagement.sol";
import {Hashing} from "src/libraries/Hashing.sol";
import {Pairing} from "src/kzg/Pairing.sol";


contract DomiconCommitment is Initializable, ISemver {

    struct DaDetails {
        uint timestamp;
        bytes32 hashSignatures;
    }

    using SafeERC20 for IERC20;

    /// @notice Semantic version.
    /// @custom:semver 0.1.0
    string public constant version = "0.1.0";

    bytes32 public committeeRoot;

    address public DOM;

    uint public nonce;

    DomiconNode public domiconNode;

    StorageManagement public storageManagement;

    mapping(address => mapping(uint256 => Pairing.G1Point)) public userCommitments;
    mapping(address => uint256) public indices;
    mapping(uint => Pairing.G1Point) public commitments;
    mapping(bytes32 => DaDetails) public daDetails;

    event SendDACommitment(
        address user,
        Pairing.G1Point commitment,
        uint timestamp,
        uint nonce,
        uint index,
        uint len,
        bytes32 root,
        bytes32 dasKey,
        bytes[] signatures
    );

    modifier onlyBroadcastNode() {
        require(
            domiconNode.IsNodeBroadcast(msg.sender),
            "DomiconCommitment: broadcast node address error"
        );
        _;
    }

    /// @notice Constructs the DomiconCommitment contract.
    constructor() {}

    /// @notice Initializer
    function initialize(DomiconNode _domiconNode,StorageManagement _storageManagement) public initializer {
        domiconNode = _domiconNode;
        storageManagement = _storageManagement;
    }

    function SubmitCommitment(
        uint64 _index,
        uint64 _length,
        bytes32 _dasKey,
        bytes[] calldata _signatures,
        Pairing.G1Point calldata _commitment
    ) external {

        DasKeySetInfo memory info = storageManagement.DASKEYSETINFO(_dasKey);
        require(
            info.addrs.length > 0,
            "DomiconCommitment:key does not exist"
        );
        require(
            info.addrs.length == _signatures.length,
            "DomiconCommitment:mismatchedSignaturesCount"
        );
        require(indices[tx.origin] == _index, "DomiconCommitment:index error");

        uint num;
        for (uint256 i = 0; i < _signatures.length; i++) {
            if (!domiconNode.IsNodeBroadcast(info.addrs[i])) {
                continue;
            }

            if (checkSign(info.addrs[i], tx.origin, _index, _length, _signatures[i], _commitment)) {
                num++;
            }
        }

        require(num >= info.requiredAmountOfSignatures, "DomiconCommitment:signature count mismatch");

        IERC20(DOM).safeTransferFrom(tx.origin, address(this), getGas(_length));

        committeeRoot = Hashing.hashCommitmentRoot(
            _commitment.X,
            _commitment.Y,
            tx.origin,
            committeeRoot
        );

        emit SendDACommitment(tx.origin,_commitment,block.timestamp,nonce,_index,_length,committeeRoot,_dasKey,_signatures);

        bytes32 hash = Hashing.hashCommitment(_commitment.X,_commitment.Y);

        daDetails[hash] = DaDetails({
            timestamp: block.timestamp,
            hashSignatures: Hashing.hashSignatures(_signatures)
        });

        userCommitments[tx.origin][_index] = _commitment;
        indices[tx.origin]++;
        nonce++;
    }

    function getUserCommitments(address _user,uint _index) public view returns(Pairing.G1Point memory){
        return userCommitments[_user][_index];
    }

    function COMMITMENTS(uint _nonce) public view returns (DaDetails memory) {
        bytes32 hash = Hashing.hashCommitment(commitments[_nonce].X,commitments[_nonce].Y);
        return daDetails[hash];
    }

    function COMMITMENTS(
        address _user,
        uint _index
    ) public view returns (DaDetails memory) {
        bytes32 hash = Hashing.hashCommitment(userCommitments[_user][_index].X,userCommitments[_user][_index].Y);

        return daDetails[hash];
    }

    function checkSign(
        address _user,
        address _target,
        uint64 _index,
        uint64 _length,
        bytes calldata _sign,
        Pairing.G1Point calldata _commitment
    ) internal view returns (bool) {
        bytes32 hash = Hashing.hashData(
            _target,
            _index,
            _length,
            _commitment.X,
            _commitment.Y
        );
        return Hashing.verifySignature(hash, _sign, _user);
    }

    function getGas(uint256 _length) internal pure returns (uint256) {
        return _length;
    }

    function SetDom(address _addr) external {
        DOM = _addr;
    }
}
