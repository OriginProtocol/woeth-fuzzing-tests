// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// Contracts
import {Setup} from "./Setup.sol";

// Libraries
import {Log} from "./helpers/HelperLog.sol";

/// @title Properties contract
/// @notice Use to store all the properties (invariants) of the system.
abstract contract Properties is Setup {
    enum LastAction {
        NONE,
        DEPOSIT,
        MINT,
        REDEEM,
        WITHDRAW,
        CHANGE_SUPPLY,
        DONATE,
        MINT_OR_BURN_EXTRA_OETH,
        PASS_TIME,
        TRANSFER,
        SHEDULE_YIELD
    }

    LastAction public last_action = LastAction.NONE;

    // --- Data ---
    mapping(address => uint256) public __deposited;
    mapping(address => uint256) public __minted;
    mapping(address => uint256) public __redeemed;
    mapping(address => uint256) public __withdrawn;
    mapping(address => uint256) public __transferFrom;
    mapping(address => uint256) public __transferTo;
    uint256 public __totalAssetBefore;
    uint256 public __totalAssetAfter;
    uint256 public __sum_deposited;
    uint256 public __sum_minted;
    uint256 public __sum_redeemed;
    uint256 public __sum_withdrawn;
    uint256 public __sum_donated_credits;
    uint256 public __oeth_balanace_of_woeth;
    uint256 public __trackedAssets;
    uint128 public __yieldAssets;
    // yield end before is updated when: 
    //  - the pass time handler is called
    //  - the schedule yield handler is called
    uint128 public __yieldEndBefore;
    uint128 public __yieldEnd;
    uint256 public __lastTimePassAmount;
    uint256 public __user_woeth_balance_before;
    uint256 public __user_oeth_balance_before;
    uint256 public __user_woeth_balance_after;
    uint256 public __user_oeth_balance_after;
    bool public __convertToAssets_success = true;
    bool public __convertToShares_success = true;
    bool public __totalAssets_success = true;
    bool public __maxDeposit_success = true;
    bool public __maxMint_success = true;
    bool public __maxRedeem_success = true;
    bool public __maxWithdraw_success = true;

    // --- Tolerances ---
    uint256 public t_B = 20 wei;
    uint256 public t_C = 10 wei;
    // minimum yieldAssets required in order to check for yield
    // with this minimum amount each second yield should drip
    uint256 public t_G = 86400;
    // the tolerance for the amount of dripped yield. 1 WEI due to rounding
    uint256 public t_G_yield = 1;

    //////////////////////////////////////////////////////
    /// --- DEFINITIONS
    //////////////////////////////////////////////////////
    /// (t: stands for tolerance:)
    /// --- General
    /// - [property_A] If totalAsset is different than before the call, then last action shouldn't be:
    ///                 - [DONATE, MINT_OR_BURN_EXTRA_OETH] (t: 0)
    ///                 - [TRANSFER] (t: 0)
    ///                 - [SCHEDULE_YIELD] (t: 0)
    /// - [__cancelled_] At the end with an empty vault, all user should have more oeth than at the beginning (tolerance: 10 wei)
    ///                  NOTICE once we enabled transfers this invariant no longer applies. 
    ///                  This property has been CANCELLED
    /// - [__property_mint_redeem_amounts] The sum of all deposited and minted should be lower than or equal to the sum of all redeemed and withdrawn (tolerance: 10 wei)
    /// - [__property_mint_redeem_totalAssets] Amount minted/deposited minus the amount redeemed/withdrawn should always be smaller than total assets in WOETH
    /// - [__property_assets_and_balance] Tracked assets should always be smaller or equal to OETH balance
    /// - [__property_total_assets_and_balance] Total assets should always be smaller or equal to OETH balance
    /// - [__property_total_asset_interval] TotalAssets should be on an interval bound by:
    ///                  - start: tracked assets minus yield assets
    ///                  - end: tracked assets
    /// - [property_yield_emissions] If time passes and yield emission is active, totalAssets should increase
    /// - [property_no_yield_emissions] If yield is not active time pass should not increase total assets
    /// --- ERC4626
    /// - The views functions should never revert (t:0)
    /// - On deposit or mint:
    ///     - If user balance of WOETH is the same after the operation, oeth amount sent should be less than or equal to (totalAsset/totalSupply). (t:0)
    ///     - If user balance of WOETH is different after the operation, oeth amount sent should be scritly positif. (t:0)
    /// - On withdraw or redeem:
    ///     - If user balance of WOETH is the same after the operation, oeth amount received should be 0. (t:0) 
    ///     - If user balance of WOETH is different after the operation, oeth amount received should be strictly positive. (t:0)

    function property_A() public returns (bool) {
        if (__totalAssetBefore != __totalAssetAfter) {
            if (last_action == LastAction.DONATE || last_action == LastAction.MINT_OR_BURN_EXTRA_OETH || 
                   last_action == LastAction.TRANSFER ||
                   last_action == LastAction.SHEDULE_YIELD) {

                emit Log.log_named_bool("LastAction.DONATE", last_action == LastAction.DONATE);
                emit Log.log_named_bool("LastAction.MINT_OR_BURN_EXTRA_OETH", last_action == LastAction.MINT_OR_BURN_EXTRA_OETH);
                emit Log.log_named_bool("LastAction.TRANSFER", last_action == LastAction.TRANSFER);
                emit Log.log_named_bool("LastAction.SHEDULE_YIELD", last_action == LastAction.SHEDULE_YIELD);

                return false;
            }
        }

        return true;
    }

    /// @dev Tested in the "afterInvariant" function
    function __property_mint_redeem_amounts() internal returns (bool) {
        uint256 a = __sum_deposited + __sum_minted;
        uint256 b = __sum_redeemed + __sum_withdrawn;
        if (a > b + t_C) {
            emit Log.log_named_uint("sum_deposited + sum_minted", a);
            emit Log.log_named_uint("sum_redeemed + sum_withdrawn", b);
            emit Log.log_named_uint("delta", delta(a, b));
            return false;
        }
        return true;
    }

    /// @dev Tested in the "afterInvariant" function
    function __property_mint_redeem_totalAssets() internal returns (bool) {
        int256 amountAdded = int256(__sum_deposited + __sum_minted);
        int256 amountRemoved = int256(__sum_redeemed + __sum_withdrawn);

        if (amountRemoved > amountAdded) {
            return true;
        }

        if (uint256(amountAdded - amountRemoved) > __totalAssetAfter) {
            emit Log.log_named_int("amountAdded", amountAdded);
            emit Log.log_named_int("amountRemoved", amountRemoved);
            emit Log.log_named_uint("__totalAssetAfter", __totalAssetAfter);
            emit Log.log_named_uint("diff: ", delta(uint256(amountAdded - amountRemoved), __totalAssetAfter));
            return false;
        }
        return true;
    }


    function __property_assets_and_balance() public returns (bool) {
        if (__oeth_balanace_of_woeth < __trackedAssets) {
            emit Log.log_named_uint("oethBalance   ", __oeth_balanace_of_woeth);
            emit Log.log_named_uint("tracked assets   ", __trackedAssets);
            emit Log.log_named_uint("yieldAssets", __yieldAssets);
            emit Log.log_named_uint("diff: ", delta(__oeth_balanace_of_woeth, __trackedAssets));
            return false;
        }
        return true;
    }

    function __property_total_assets_and_balance() public returns (bool) {
        if (__oeth_balanace_of_woeth < __totalAssetAfter) {
            emit Log.log_named_uint("oethBalance   ", __oeth_balanace_of_woeth);
            emit Log.log_named_uint("total assets   ", __totalAssetAfter);
            emit Log.log_named_uint("diff: ", delta(__oeth_balanace_of_woeth, __totalAssetAfter));
            return false;
        }
        
        return true;
    }

    /// @dev Tested in the "afterInvariant" function
    function __property_total_asset_interval() public returns (bool) {
        uint256 assetsWithoutYield = 0;
        if (__trackedAssets > __yieldAssets) {
            assetsWithoutYield = __trackedAssets - __yieldAssets;
        }

        uint256 totalAssets = __totalAssetAfter;

        if (totalAssets < assetsWithoutYield || 
            totalAssets > __trackedAssets) {
            emit Log.log_named_uint("assetsWithoutYield   ", assetsWithoutYield);
            emit Log.log_named_uint("trackedAssets   ", __trackedAssets);
            emit Log.log_named_uint("__totalAssetAfter", __totalAssetAfter);
            return false;
        }
        return true;
    }

    function property_yield_emissions() public returns (bool) {
        if (last_action == LastAction.PASS_TIME &&  // if time has passed
            // and so much yield is distributed that each second will contribute to yield
            __yieldAssets >= t_G && 
            // before time pass has been executed, contract had active yield drip
            __yieldEndBefore > block.timestamp - __lastTimePassAmount
        ) {
            uint256 yieldEmittingDuration = __lastTimePassAmount;
            // part of pass time was yield emitting part wasn't
            if (__yieldEnd < block.timestamp) {
                // subtract the amount of time no yield has been emitted from the 
                // time passing duration
                yieldEmittingDuration -= block.timestamp - __yieldEnd;
            }
            
            // Amount of total assets should not decrease
            if (__totalAssetBefore >= __totalAssetAfter) {
                emit Log.log("yield assets decreased");
                emit Log.log_named_uint("__yieldAssets   ", __yieldAssets);
                emit Log.log_named_uint("__lastTimePassAmount   ", __lastTimePassAmount);
                emit Log.log_named_uint("__yieldEnd", __yieldEnd);
                emit Log.log_named_uint("__totalAssetBefore", __totalAssetBefore);
                emit Log.log_named_uint("__totalAssetAfter", __totalAssetAfter);
                return false;
            }

            uint256 yieldDripped = __totalAssetAfter - __totalAssetBefore;
            uint256 yieldDrippExpected = __yieldAssets * yieldEmittingDuration / YIELD_TIME;
            bool isExpected = approxEqAbs(yieldDripped, yieldDrippExpected, t_G_yield);
            if (!isExpected) {
                emit Log.log("unexpected yield amount");
                emit Log.log_named_uint("__yieldAssets   ", __yieldAssets);
                emit Log.log_named_uint("__lastTimePassAmount   ", __lastTimePassAmount);
                emit Log.log_named_uint("__yieldEnd", __yieldEnd);
                emit Log.log_named_uint("__totalAssetBefore", __totalAssetBefore);
                emit Log.log_named_uint("__totalAssetAfter", __totalAssetAfter);
            }
            return isExpected;
        }
        return true;
    }

    function property_no_yield_emissions() public returns (bool) {
        if (last_action == LastAction.PASS_TIME &&  // if time has passed
            // and so much yield is distributed that each second will contribute to yield
            __yieldAssets >= t_G && 
            // at pass time the yield on the contract wasn't active
            __yieldEndBefore < block.timestamp - __lastTimePassAmount
        ) {
            // no yield drip should happen
            return __totalAssetBefore == __totalAssetAfter;
        }
        return true;
    }

    function property_4626_views() public view returns (bool) {
        return __convertToAssets_success && __convertToShares_success && __totalAssets_success && __maxDeposit_success
            && __maxMint_success && __maxRedeem_success && __maxWithdraw_success;
    }

    function property_4626_deposit_mint() public returns (bool) {
        if (last_action == LastAction.DEPOSIT || last_action == LastAction.MINT) {
            // If the user woeth balance is the same after mint or deposit, 
            // oeth amount sent should be less than or equal to (totalAsset/totalSupply)
            if (__user_woeth_balance_after == __user_woeth_balance_before) {
                uint256 totalAssets = woeth.totalAssets();
                uint256 totalSupply = woeth.totalSupply();
                if (__user_oeth_balance_before > (totalAssets / totalSupply)) {
                    _logOETHAndWOETHBalances("B");
                    return false;
                }
            }
            // Else the user should have deposited more than 1wei of OETH and received 1wei or more of WOETH
            else {
                if (
                    __user_oeth_balance_before <= __user_oeth_balance_after
                        || (__user_woeth_balance_after) <= __user_woeth_balance_before
                ) {
                    _logOETHAndWOETHBalances("C");
                    return false;
                }
            }
        }
        return true;
    }

    function property_4626_withdraw_redeem() public returns (bool) {
        if (last_action == LastAction.WITHDRAW || last_action == LastAction.REDEEM) {
            // If a user have same woeth balance after redeem or withdraw, then he should have the same oeth balance
            if (__user_woeth_balance_after == __user_woeth_balance_before) {
                if (__user_oeth_balance_after != __user_oeth_balance_before) {
                    _logOETHAndWOETHBalances("B");
                    return false;
                }
            }
            // If a user have less woeth balance after redeem or withdraw, then he should have more oeth balance
            else if (__user_woeth_balance_before > __user_woeth_balance_after) {
                if (__user_oeth_balance_before >= __user_oeth_balance_after) {
                    _logOETHAndWOETHBalances("C");
                    return false;
                }
            }
        }
        return true;
    }

    function approxEqAbs(uint256 a, uint256 b, uint256 tolerance) internal pure returns (bool) {
        if (a > b) {
            return (a - b) <= tolerance;
        } else {
            return (b - a) <= tolerance;
        }
    }

    function _logOETHAndWOETHBalances() internal {
        emit Log.log_named_uint("user_oeth_balance_before", __user_oeth_balance_before);
        emit Log.log_named_uint("user_oeth_balance_after", __user_oeth_balance_after);
        emit Log.log_named_uint("user_woeth_balance_before", __user_woeth_balance_before);
        emit Log.log_named_uint("user_woeth_balance_after", __user_woeth_balance_after);
    }

    function _logOETHAndWOETHBalances(string memory message) internal {
        emit Log.log(message);
        _logOETHAndWOETHBalances();
    }
}
