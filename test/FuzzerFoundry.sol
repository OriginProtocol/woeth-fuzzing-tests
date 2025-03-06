// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// Foundry
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";

// Contracts
import {TargetFunctions} from "./TargetFunctions.sol";

/// @title FuzzerFoundry contract
/// @notice Foundry interface for the fuzzer.
contract FuzzerFoundry is StdInvariant, StdAssertions, TargetFunctions {
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
        bytes4[] memory selectors = new bytes4[](11);
        selectors[0] = this.handler_deposit.selector;
        selectors[1] = this.handler_mint.selector;
        selectors[2] = this.handler_redeem.selector;
        selectors[3] = this.handler_withdraw.selector;
        selectors[4] = this.handler_changeSupply.selector;
        selectors[5] = this.handler_donate.selector;
        selectors[6] = this.handler_mintOrBurnExtraOETH.selector;
        selectors[7] = this.handler_views.selector;
        selectors[8] = this.handler_pass_time.selector;
        selectors[9] = this.handler_transfer.selector;
        selectors[10] = this.handler_schedule_yield.selector;

        // Target selectors
        targetSelector(FuzzSelector({addr: address(this), selectors: selectors}));
    }

    function invariant_A() public {
        require(property_A(), "Invariant A failed");
    }

    function invariant_B() public {
        require(property_yield_emissions(), "Invariant B failed");
    }

    function invariant_C() public {
        require(property_no_yield_emissions(), "Invariant C failed");
    }

    function invariant_4626_views() public view {
        require(property_4626_views(), "Invariant 4626 views failed");
    }

    function invariant_4626_deposit_mint() public {
        require(property_4626_deposit_mint(), "Invariant 4626 deposit failed");
    }

    function invariant_4626_withdraw_redeem() public {
        require(property_4626_withdraw_redeem(), "Invariant 4626 withdraw deposit failed");
    }
}
