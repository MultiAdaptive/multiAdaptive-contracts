// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @custom:upgradeable
/// @title ResourceMetering
/// @notice ResourceMetering implements an EIP-1559 style resource metering system where pricing
///         updates automatically based on current demand.
abstract contract ResourceMetering is Initializable {
    /// @notice Represents the various parameters that control the way in which resources are
    ///         metered. Corresponds to the EIP-1559 resource metering system.
    /// @custom:field prevBaseFee   Base fee from the previous block(s).
    /// @custom:field prevBoughtGas Amount of gas bought so far in the current block.
    /// @custom:field prevBlockNum  Last block number that the base fee was updated.
    struct ResourceParams {
        uint128 prevBaseFee;
        uint64 prevBoughtGas;
        uint64 prevBlockNum;
    }

    /// @notice Represents the configuration for the EIP-1559 based curve for the deposit gas
    ///         market. These values should be set with care as it is possible to set them in
    ///         a way that breaks the deposit gas market. The target resource limit is defined as
    ///         maxResourceLimit / elasticityMultiplier. This struct was designed to fit within a
    ///         single word. There is additional space for additions in the future.
    /// @custom:field maxResourceLimit             Represents the maximum amount of deposit gas that
    ///                                            can be purchased per block.
    /// @custom:field elasticityMultiplier         Determines the target resource limit along with
    ///                                            the resource limit.
    /// @custom:field baseFeeMaxChangeDenominator  Determines max change on fee per block.
    /// @custom:field minimumBaseFee               The min deposit base fee, it is clamped to this
    ///                                            value.
    /// @custom:field systemTxMaxGas               The amount of gas supplied to the system
    ///                                            transaction. This should be set to the same
    ///                                            number that the op-node sets as the gas limit
    ///                                            for the system transaction.
    /// @custom:field maximumBaseFee               The max deposit base fee, it is clamped to this
    ///                                            value.
    struct ResourceConfig {
        uint32 maxResourceLimit;
        uint8 elasticityMultiplier;
        uint8 baseFeeMaxChangeDenominator;
        uint32 minimumBaseFee;
        uint32 systemTxMaxGas;
        uint128 maximumBaseFee;
    }

    /// @notice EIP-1559 style gas parameters.
    ResourceParams public params;

    /// @notice Reserve extra slots (to a total of 50) in the storage layout for future upgrades.
    uint256[48] private __gap;

    /// @notice Virtual function that returns the resource config.
    ///         Contracts that inherit this contract must implement this function.
    /// @return ResourceConfig
    function _resourceConfig() internal virtual returns (ResourceConfig memory);

    /// @notice Sets initial resource parameter values.
    ///         This function must either be called by the initializer function of an upgradeable
    ///         child contract.
    function __ResourceMetering_init() internal onlyInitializing {
        if (params.prevBlockNum == 0) {
            params = ResourceParams({
                prevBaseFee: 1 gwei,
                prevBoughtGas: 0,
                prevBlockNum: uint64(block.number)
            });
        }
    }
}
