// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ISemver} from "src/universal/ISemver.sol";
import {DomiconNode} from "src/DomiconNode.sol";
import {Hashing} from "src/libraries/Hashing.sol";

struct DasKeySetInfo {
    uint requiredAmountOfSignatures;
    address[] addrs;
}

struct DaDetails {
    address user;
    bytes commitment;
    uint timestamp;
    uint nonce;
    uint index;
    uint len;
    bytes32 root;
    bytes32 dasKey;
    bytes[] signatures;
}

contract DomiconCommitment is Initializable, ISemver {
    using SafeERC20 for IERC20;

    /// @notice Semantic version.
    /// @custom:semver 1.4.1
    string public constant version = "1.4.1";

    bytes32 public committeeHash;

    address public DOM;

    uint public nonce;

    DomiconNode public domiconNode;

    mapping(address => mapping(uint256 => bytes)) public userCommitments;
    mapping(address => uint256) public indices;
    mapping(uint => bytes) public commitments;
    mapping(bytes => DaDetails) public daDetails;

    mapping(bytes32 => DasKeySetInfo) public dasKeySetInfo;

    event DasKeySetInfoRegistered(address indexed user, bytes32 dasKey);
    event SendDACommitment(
        uint256 index,
        uint256 length,
        uint256 price,
        address indexed broadcaster,
        address indexed user,
        bytes sign,
        bytes commitment
    );

    modifier onlyEOA() {
        require(
            !Address.isContract(msg.sender),
            "DomiconCommitment: function can only be called from an EOA"
        );
        _;
    }

    modifier onlyBroadcastNode() {
        require(
            domiconNode.IsNodeBroadcast(msg.sender),
            "DomiconCommitment: broadcast node address error"
        );
        _;
    }

    /// @notice Constructs the L1StandardBridge contract.
    constructor() {}

    /// @notice Initializer
    function initialize(DomiconNode _domiconNode) public initializer {
        domiconNode = _domiconNode;
    }

    function SubmitCommitment(
        uint64 _index,
        uint64 _length,
        bytes32 _dasKey,
        bytes[] calldata _signatures,
        bytes calldata _commitment
    ) external {
        require(
            dasKeySetInfo[_dasKey].addrs.length > 0,
            "DomiconCommitment:key does not exist"
        );
        require(
            dasKeySetInfo[_dasKey].addrs.length == _signatures.length,
            "DomiconCommitment:mismatchedSignaturesCount"
        );
        require(indices[msg.sender] == _index, "DomiconCommitment:index error");

        address[] memory broadcastAddresses = dasKeySetInfo[_dasKey].addrs;
        for (uint256 i = 0; i < _signatures.length; i++) {
            require(
                domiconNode.IsNodeBroadcast(broadcastAddresses[i]),
                "DomiconCommitment:broadcast node address error"
            );
            require(
                checkSign(
                    broadcastAddresses[i],
                    msg.sender,
                    _index,
                    _length,
                    _signatures[i],
                    _commitment
                )
            );
        }

        IERC20(DOM).safeTransferFrom(msg.sender, address(this), 200);

        committeeHash = Hashing.hashCommitment(
            _commitment,
            msg.sender,
            committeeHash
        );

        daDetails[_commitment] = DaDetails({
            user: msg.sender,
            commitment: _commitment,
            timestamp: block.timestamp,
            nonce: nonce,
            index: _index,
            len: _length,
            root: committeeHash,
            dasKey: _dasKey,
            signatures: _signatures
        });
        commitments[nonce] = _commitment;
        userCommitments[msg.sender][_index] = _commitment;
        indices[msg.sender]++;
        nonce++;
    }

    function SetValidKeyset(
        uint _requiredAmountOfSignatures,
        address[] calldata _addrs
    ) external returns (bytes32 ksHash) {
        require(
            _addrs.length >= _requiredAmountOfSignatures,
            "DomiconCommitment:tooManyRequiredSignatures"
        );
        for (uint256 i = 0; i < _addrs.length; i++) {
            require(
                domiconNode.IsNodeBroadcast(_addrs[i]),
                "DomiconCommitment:broadcast node address error"
            );
        }

        DasKeySetInfo memory info = DasKeySetInfo({
            requiredAmountOfSignatures: _requiredAmountOfSignatures,
            addrs: _addrs
        });
        ksHash = Hashing.hashAddresses(msg.sender, _addrs);

        dasKeySetInfo[ksHash] = info;
        emit DasKeySetInfoRegistered(msg.sender, ksHash);
    }

    function DASKEYSETINFO(
        bytes32 _key
    ) public view returns (uint, address[] memory) {
        return (
            dasKeySetInfo[_key].requiredAmountOfSignatures,
            dasKeySetInfo[_key].addrs
        );
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
