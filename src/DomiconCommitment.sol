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


struct DaDetails {
    uint timestamp;
    bytes32 hashSignatures;
}

contract DomiconCommitment is Initializable, ISemver {
    using SafeERC20 for IERC20;

    /// @notice Semantic version.
    /// @custom:semver 0.1.0
    string public constant version = "0.1.0";

    bytes32 public committeeRoot;

    address public DOM;

    uint public nonce;

    DomiconNode public domiconNode;

    StorageManagement public storageManagement;

    mapping(address => mapping(uint256 => bytes)) public userCommitments;
    mapping(address => uint256) public indices;
    mapping(uint => bytes) public commitments;
    mapping(bytes => DaDetails) public daDetails;

    event SendDACommitment(
        address user,
        bytes commitment,
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
        bytes calldata _commitment
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

        committeeRoot = Hashing.hashCommitment(
            _commitment,
            tx.origin,
            committeeRoot
        );

        emit SendDACommitment(tx.origin,_commitment,block.timestamp,nonce,_index,_length,committeeRoot,_dasKey,_signatures);

        daDetails[_commitment] = DaDetails({
            timestamp: block.timestamp,
            hashSignatures: Hashing.hashSignatures(_signatures)
        });

        userCommitments[tx.origin][_index] = _commitment;
        indices[tx.origin]++;
        nonce++;
    }

    function getUserCommitments(address _user,uint _index) public view returns(bytes memory){
        return userCommitments[_user][_index];
    }

    function COMMITMENTS(uint _nonce) public view returns (DaDetails memory) {
        return daDetails[commitments[_nonce]];
    }

    function COMMITMENTS(
        address _user,
        uint _index
    ) public view returns (DaDetails memory) {
        return daDetails[userCommitments[_user][_index]];
    }

    function checkSign(
        address _user,
        address _target,
        uint64 _index,
        uint64 _length,
        bytes calldata _sign,
        bytes calldata _commitment
    ) internal view returns (bool) {
        bytes32 hash = Hashing.hashData(
            _user,
            _target,
            _index,
            _length,
            _commitment
        );
        return Hashing.verifySignature(hash, _sign, _user);
    }

    function getGas(uint256 length) internal pure returns (uint256) {
        return length;
    }

    function SetDom(address addr) external {
        DOM = addr;
    }
}
