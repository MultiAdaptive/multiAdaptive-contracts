// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VmSafe} from "forge-std/Vm.sol";
import {Script} from "forge-std/Script.sol";

import {console2 as console} from "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {Safe} from "safe-contracts/Safe.sol";
import {SafeProxyFactory} from "safe-contracts/proxies/SafeProxyFactory.sol";
import {Enum as SafeOps} from "safe-contracts/common/Enum.sol";

import {Deployer} from "script/Deployer.sol";

import {ProxyAdmin} from "src/universal/ProxyAdmin.sol";
import {AddressManager} from "src/legacy/AddressManager.sol";
import {Proxy} from "src/universal/Proxy.sol";
import {L1ChugSplashProxy} from "src/legacy/L1ChugSplashProxy.sol";
import {DomiconNode} from "src/DomiconNode.sol";
import {DomiconCommitment} from "src/DomiconCommitment.sol";
import {StorageSetter} from "src/universal/StorageSetter.sol";
import {Chains} from "script/Chains.sol";
import {Config} from "script/Config.sol";

import {LibStateDiff} from "script/libraries/LibStateDiff.sol";
import {EIP1967Helper} from "test/mocks/EIP1967Helper.sol";
import {ForgeArtifacts} from "script/ForgeArtifacts.sol";

/// @title Deploy
/// @notice Script used to deploy a bedrock system. The entire system is deployed within the `run` function.
///         To add a new contract to the system, add a public function that deploys that individual contract.
///         Then add a call to that function inside of `run`. Be sure to call the `save` function after each
///         deployment so that hardhat-deploy style artifacts can be generated using a call to `sync()`.
///         The `CONTRACT_ADDRESSES_PATH` environment variable can be set to a path that contains a JSON file full of
///         contract name to address pairs. That enables this script to be much more flexible in the way it is used.
///         This contract must not have constructor logic because it is set into state using `etch`.
contract Deploy is Deployer {
    using stdJson for string;

    ////////////////////////////////////////////////////////////////
    //                        Modifiers                           //
    ////////////////////////////////////////////////////////////////

    /// @notice Modifier that wraps a function in broadcasting.
    modifier broadcast() {
        vm.startBroadcast(msg.sender);
        _;
        vm.stopBroadcast();
    }

    /// @notice Modifier that will only allow a function to be called on devnet.
    modifier onlyDevnet() {
        uint256 chainid = block.chainid;
        if (chainid == Chains.GethDevnet) {
            _;
        }
    }

    /// @notice Modifier that will only allow a function to be called on a public
    ///         testnet or devnet.
    modifier onlyTestnetOrDevnet() {
        uint256 chainid = block.chainid;
        if (
            chainid == Chains.Goerli ||
            chainid == Chains.Sepolia ||
            chainid == Chains.GethDevnet
        ) {
            _;
        }
    }

    /// @notice Modifier that wraps a function with statediff recording.
    ///         The returned AccountAccess[] array is then written to
    ///         the `snapshots/state-diff/<name>.json` output file.
    modifier stateDiff() {
        vm.startStateDiffRecording();
        _;
        VmSafe.AccountAccess[] memory accesses = vm.stopAndReturnStateDiff();
        console.log(
            "Writing %d state diff account accesses to snapshots/state-diff/%s.json",
            accesses.length,
            name()
        );
        string memory json = LibStateDiff.encodeAccountAccesses(accesses);
        string memory statediffPath = string.concat(
            vm.projectRoot(),
            "/snapshots/state-diff/",
            name(),
            ".json"
        );
        vm.writeJson({json: json, path: statediffPath});
    }

    ////////////////////////////////////////////////////////////////
    //                        Accessors                           //
    ////////////////////////////////////////////////////////////////

    /// @inheritdoc Deployer
    function name() public pure override returns (string memory name_) {
        name_ = "Deploy";
    }

    /// @notice The create2 salt used for deployment of the contract implementations.
    ///         Using this helps to reduce config across networks as the implementation
    ///         addresses will be the same across networks when deployed with create2.
    function _implSalt() internal view returns (bytes32) {
        return keccak256(bytes(Config.implSalt()));
    }

    ////////////////////////////////////////////////////////////////
    //            State Changing Helper Functions                 //
    ////////////////////////////////////////////////////////////////

    /// @notice Gets the address of the SafeProxyFactory and Safe singleton for use in deploying a new GnosisSafe.
    function _getSafeFactory()
        internal
        returns (SafeProxyFactory safeProxyFactory_, Safe safeSingleton_)
    {
        // These are the standard create2 deployed contracts. First we'll check if they are deployed,
        // if not we'll deploy new ones, though not at these addresses.
        address safeProxyFactory = 0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2;
        address safeSingleton = 0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552;

        safeProxyFactory.code.length == 0
            ? safeProxyFactory_ = new SafeProxyFactory()
            : safeProxyFactory_ = SafeProxyFactory(safeProxyFactory);

        safeSingleton.code.length == 0
            ? safeSingleton_ = new Safe()
            : safeSingleton_ = Safe(payable(safeSingleton));

        save("SafeProxyFactory", address(safeProxyFactory_));
        save("SafeSingleton", address(safeSingleton_));
    }

    /// @notice Make a call from the Safe contract to an arbitrary address with arbitrary data
    function _callViaSafe(address _target, bytes memory _data) internal {
        Safe safe = Safe(mustGetAddress("SystemOwnerSafe"));

        // This is the signature format used the caller is also the signer.
        bytes memory signature = abi.encodePacked(
            uint256(uint160(msg.sender)),
            bytes32(0),
            uint8(1)
        );

        safe.execTransaction({
            to: _target,
            value: 0,
            data: _data,
            operation: SafeOps.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: payable(address(0)),
            signatures: signature
        });
    }

    /// @notice Call from the Safe contract to the Proxy Admin's upgrade and call method
    function _upgradeAndCallViaSafe(
        address _proxy,
        address _implementation,
        bytes memory _innerCallData
    ) internal {
        address proxyAdmin = mustGetAddress("ProxyAdmin");

        bytes memory data = abi.encodeCall(
            ProxyAdmin.upgradeAndCall,
            (payable(_proxy), _implementation, _innerCallData)
        );

        _callViaSafe({_target: proxyAdmin, _data: data});
    }

    /// @notice Transfer ownership of the ProxyAdmin contract to the final system owner
    function transferProxyAdminOwnership() public broadcast {
        ProxyAdmin proxyAdmin = ProxyAdmin(mustGetAddress("ProxyAdmin"));
        address owner = proxyAdmin.owner();
        address safe = mustGetAddress("SystemOwnerSafe");
        if (owner != safe) {
            proxyAdmin.transferOwnership(safe);
            console.log(
                "ProxyAdmin ownership transferred to Safe at: %s",
                safe
            );
        }
    }

    /// @notice Transfer ownership of a Proxy to the ProxyAdmin contract
    ///         This is expected to be used in conjusting with deployERC1967ProxyWithOwner after setup actions
    ///         have been performed on the proxy.s's
    /// @param _name The name of the proxy to transfer ownership of.
    function transferProxyToProxyAdmin(string memory _name) public broadcast {
        Proxy proxy = Proxy(mustGetAddress(_name));
        address proxyAdmin = mustGetAddress("ProxyAdmin");
        proxy.changeAdmin(proxyAdmin);
        console.log(
            "Proxy %s ownership transferred to ProxyAdmin at: %s",
            _name,
            proxyAdmin
        );
    }

    ////////////////////////////////////////////////////////////////
    //                    SetUp and Run                           //
    ////////////////////////////////////////////////////////////////

    /// @notice Deploy all of contracts.
    function run() public {
        _run();
    }

    function runWithStateDump() public {
        _run();

        vm.dumpState(Config.stateDumpPath(name()));
    }

    /// @notice Deploy all L1 contracts and write the state diff to a file.
    function runWithStateDiff() public stateDiff {
        _run();
    }

    /// @notice Internal function containing the deploy logic.
    function _run() internal {
        deploySafe();
        setupAdmin();
        setupContracts();
    }

    ////////////////////////////////////////////////////////////////
    //           High Level Deployment Functions                  //
    ////////////////////////////////////////////////////////////////

    /// @notice
    function setupAdmin() public {
        console.log("Setting up Admin");

        deployAddressManager();
        deployProxyAdmin();
        transferProxyAdminOwnership();
    }

    /// @notice Deploy contracts
    function setupContracts() public {
        console.log("Deploying Contracts");

        // Ensure that the requisite contracts are deployed
        mustGetAddress("SystemOwnerSafe");
        mustGetAddress("AddressManager");
        mustGetAddress("ProxyAdmin");

        deployProxies();
        deployImplementations();
        initializeImplementations();
    }

    /// @notice Deploy all of the proxies
    function deployProxies() public {
        console.log("Deploying proxies");

        deployERC1967Proxy("DomiconNodeProxy");
        deployERC1967Proxy("DomiconCommitmentProxy");

        //        transferAddressManagerOwnership(); // to the ProxyAdmin
    }

    /// @notice Deploy all of the implementations
    function deployImplementations() public {
        console.log("Deploying implementations");

        deployDomiconNode();
        deployDomiconCommitment();
    }

    /// @notice Initialize all of the implementations
    function initializeImplementations() public {
        console.log("Initializing implementations");

        initializeDomiconNode();
        initializeDomiconCommitment();
    }

    ////////////////////////////////////////////////////////////////
    //              Non-Proxied Deployment Functions              //
    ////////////////////////////////////////////////////////////////

    /// @notice Deploy the Safe
    function deploySafe() public broadcast returns (address addr_) {
        console.log("Deploying Safe");
        (
            SafeProxyFactory safeProxyFactory,
            Safe safeSingleton
        ) = _getSafeFactory();

        address[] memory signers = new address[](1);
        signers[0] = msg.sender;

        bytes memory initData = abi.encodeWithSelector(
        Safe.setup.selector,
        signers,
        1,
        address(0),
        hex"",
    address(0),
    address(0),
        0,
        address(0)
        );
        address safe = address(
            safeProxyFactory.createProxyWithNonce(
                address(safeSingleton),
                initData,
                block.timestamp
            )
        );

        save("SystemOwnerSafe", address(safe));
        console.log("New SystemOwnerSafe deployed at %s", address(safe));
        addr_ = safe;
    }

    /// @notice Deploy the AddressManager
    function deployAddressManager() public broadcast returns (address addr_) {
        console.log("Deploying AddressManager");
        AddressManager manager = new AddressManager();
        require(manager.owner() == msg.sender);

        save("AddressManager", address(manager));
        console.log("AddressManager deployed at %s", address(manager));
        addr_ = address(manager);
    }

    /// @notice Deploy the ProxyAdmin
    function deployProxyAdmin() public broadcast returns (address addr_) {
        console.log("Deploying ProxyAdmin");
        ProxyAdmin admin = new ProxyAdmin({_owner: msg.sender});
        require(admin.owner() == msg.sender);

        AddressManager addressManager = AddressManager(
            mustGetAddress("AddressManager")
        );
        if (admin.addressManager() != addressManager) {
            admin.setAddressManager(addressManager);
        }

        require(admin.addressManager() == addressManager);

        save("ProxyAdmin", address(admin));
        console.log("ProxyAdmin deployed at %s", address(admin));
        addr_ = address(admin);
    }

    /// @notice Deploy the StorageSetter contract, used for upgrades.
    function deployStorageSetter() public broadcast returns (address addr_) {
        console.log("Deploying StorageSetter");
        StorageSetter setter = new StorageSetter{salt: _implSalt()}();
        console.log("StorageSetter deployed at: %s", address(setter));
        string memory version = setter.version();
        console.log("StorageSetter version: %s", version);
        addr_ = address(setter);
    }

    ////////////////////////////////////////////////////////////////
    //                Proxy Deployment Functions                  //
    ////////////////////////////////////////////////////////////////

    /// @notice Deploys an ERC1967Proxy contract with the ProxyAdmin as the owner.
    /// @param _name The name of the proxy contract to be deployed.
    /// @return addr_ The address of the deployed proxy contract.
    function deployERC1967Proxy(
        string memory _name
    ) public returns (address addr_) {
        addr_ = deployERC1967ProxyWithOwner(
            _name,
            mustGetAddress("ProxyAdmin")
        );
    }

    /// @notice Deploys an ERC1967Proxy contract with a specified owner.
    /// @param _name The name of the proxy contract to be deployed.
    /// @param _proxyOwner The address of the owner of the proxy contract.
    /// @return addr_ The address of the deployed proxy contract.
    function deployERC1967ProxyWithOwner(
        string memory _name,
        address _proxyOwner
    ) public broadcast returns (address addr_) {
        console.log(string.concat("Deploying ERC1967 proxy for ", _name));
        Proxy proxy = new Proxy({_admin: _proxyOwner});

        require(EIP1967Helper.getAdmin(address(proxy)) == _proxyOwner);

        save(_name, address(proxy));
        addr_ = address(proxy);
    }

    ////////////////////////////////////////////////////////////////
    //             Implementation Deployment Functions            //
    ////////////////////////////////////////////////////////////////

    /// @notice Deploy the DomiconNode
    function deployDomiconNode() public broadcast returns (address addr_) {
        console.log("Deploying DomiconNode implementation");
        DomiconNode node = new DomiconNode{salt: _implSalt()}();

        save("DomiconNode", address(node));
        console.log("DomiconNode deployed at %s", address(node));

        addr_ = address(node);
    }

    /// @notice Deploy the DomiconNode
    function deployDomiconCommitment()
    public
    broadcast
    returns (address addr_)
    {
        console.log("Deploying DomiconCommitment implementation");
        DomiconCommitment comm = new DomiconCommitment{salt: _implSalt()}();

        save("DomiconCommitment", address(comm));
        console.log("DomiconNode deployed at %s", address(comm));

        addr_ = address(comm);
    }

    /// @notice Transfer ownership of the address manager to the ProxyAdmin
    function transferAddressManagerOwnership() public broadcast {
        console.log("Transferring AddressManager ownership to ProxyAdmin");
        AddressManager addressManager = AddressManager(
            mustGetAddress("AddressManager")
        );
        address owner = addressManager.owner();
        address proxyAdmin = mustGetAddress("ProxyAdmin");
        if (owner != proxyAdmin) {
            addressManager.transferOwnership(proxyAdmin);
            console.log(
                "AddressManager ownership transferred to %s",
                proxyAdmin
            );
        }

        require(addressManager.owner() == proxyAdmin);
    }

    ////////////////////////////////////////////////////////////////
    //                    Initialize Functions                    //
    ////////////////////////////////////////////////////////////////

    function initializeDomiconNode() public broadcast {
        console.log("Upgrading and initializing DomiconNode proxy");
        address domiconNodeProxy = mustGetAddress("DomiconNodeProxy");
        address domiconNode = mustGetAddress("DomiconNode");

        _upgradeAndCallViaSafe({
            _proxy: payable(domiconNodeProxy),
            _implementation: domiconNode,
            _innerCallData: abi.encodeCall(DomiconNode.initialize, ())
        });
    }

    function initializeDomiconCommitment() public broadcast {
        console.log("Upgrading and initializing DomiconCommitment proxy");
        address domiconCommitmentProxy = mustGetAddress(
            "DomiconCommitmentProxy"
        );
        address domiconCommitment = mustGetAddress("DomiconCommitment");
        address domiconNodeProxy = mustGetAddress("DomiconNodeProxy");

        _upgradeAndCallViaSafe({
            _proxy: payable(domiconCommitmentProxy),
            _implementation: domiconCommitment,
            _innerCallData: abi.encodeCall(
                DomiconCommitment.initialize,
                (DomiconNode(domiconNodeProxy))
            )
        });
    }
}
