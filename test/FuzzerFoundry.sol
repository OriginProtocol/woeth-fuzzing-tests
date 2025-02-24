// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// Foundry
import {StdInvariant} from "forge-std/StdInvariant.sol";

// Contracts
import {TargetFunctions} from "./TargetFunctions.sol";

/// @title FuzzerFoundry contract
/// @notice Foundry interface for the fuzzer.
contract FuzzerFoundry is StdInvariant, TargetFunctions {
    //////////////////////////////////////////////////////
    /// --- SETUP
    //////////////////////////////////////////////////////
    /// @notice Setup the contract
    function setUp() public {
        setup();

        // Foundry doesn't use config files but does the setup programmatically here

        // target the fuzzer on this contract as it will contain the handler functions
        targetContract(address(this));

        // Add selectors
        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = this.handler_deposit.selector;
        selectors[1] = this.handler_mint.selector;
        selectors[2] = this.handler_redeem.selector;
        selectors[3] = this.handler_withdraw.selector;
        selectors[4] = this.handler_changeSupply.selector;
        selectors[5] = this.handler_donate.selector;
        selectors[6] = this.handler_manageSupplies.selector;

        // Target selectors
        targetSelector(FuzzSelector({addr: address(this), selectors: selectors}));
    }

    function invariant_A() public {}
}
