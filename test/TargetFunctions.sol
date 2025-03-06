// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// Contracts
import {Properties} from "./Properties.sol";
import {Log} from "./helpers/HelperLog.sol";

/// @title TargetFunctions contract
/// @notice Use to handle all calls to the tested contract.
abstract contract TargetFunctions is Properties {
    //////////////////////////////////////////////////////
    /// --- HANDLERS
    //////////////////////////////////////////////////////
    /// @notice Handle deposit in WOETH.
    /// @param _userId User id to deposit WOETH.
    /// @param _amountToMint Maximum amount of OETH that can be minted in a single transaction will be limited
    ///        to type(uint88).max. This is a bit less than 310M. In comparison with biggest holders:
    ///        - OUSD: approx 1.2M
    ///        - OETH: approx 18k
    ///        - OS  : negligible
    /// _amountToMint = type(uint88).max;
    function handler_deposit(uint8 _userId, uint88 _amountToMint) public {
        // Find a random user amongst the users.
        address user = users[_userId % users.length];

        // Bound amout to mint.
        _amountToMint = uint88(clamp(uint256(_amountToMint), 0, _mintableAmount(), USE_LOGS));
        if (_amountToMint == 0) {
            if (USE_ASSUME) hevm.assume(false);
            else return;
        }

        // Mint OETH to the user.
        uint256 balanceOETH = _mintOETHTo(user, _amountToMint);
        if (balanceOETH == 0) {
            if (USE_ASSUME) hevm.assume(false);
            else return;
        }

        // --- Ghost data before ---
        __totalAssetBefore = woeth.totalAssets();
        __deposited[user] += balanceOETH;
        __sum_deposited += balanceOETH;
        __user_oeth_balance_before = oeth.balanceOf(user);
        __user_woeth_balance_before = woeth.balanceOf(user);

        // Deposit OETH.
        hevm.prank(user);
        woeth.deposit(balanceOETH, user);

        // --- Ghost data after ---
        last_action = LastAction.DEPOSIT;
        __totalAssetAfter = woeth.totalAssets();
        __oeth_balanace_of_woeth = oeth.balanceOf(address(woeth));
        __trackedAssets = woeth.trackedAssets();
        __yieldAssets = woeth.yieldAssets();
        __yieldEnd = woeth.yieldEnd();
        __user_oeth_balance_after = oeth.balanceOf(user);
        __user_woeth_balance_after = woeth.balanceOf(user);
    }

    /// @notice Handle mint in WOETH.
    /// @param _userId User id to mint WOETH.
    /// @param _sharesToMint Amount of WOETH shares to mint.
    ///        Maximum will be limited to type(uint88).max. This is a bit less than 310M.
    ///        This is for the same reasons as the deposit function + because shares price will be always <= 1OETH.
    /// _sharesToMint = type(uint88).max;
    function handler_mint(uint8 _userId, uint88 _sharesToMint) public {
        // Find a random user amongst the users.
        address user = users[_userId % users.length];

        // Prevent minting 0 shares as it will revert
        _sharesToMint = uint88(clamp(uint256(_sharesToMint), 1, type(uint88).max, USE_LOGS));

        // Convert shares in OETH amount (to ensure mintable amount).
        uint256 amountToMint = woeth.previewMint(_sharesToMint);
        if (amountToMint >= _mintableAmount()) {
            if (USE_ASSUME) hevm.assume(false);
            else return;
        }

        // Mint OETH to the user.
        uint256 mintedOETH = _mintOETHTo(user, amountToMint);
        // Convert back real user minted amount in shares.
        uint256 sharesToMint = woeth.convertToShares(mintedOETH);
        if (sharesToMint == 0) {
            if (USE_ASSUME) hevm.assume(false);
            else return;
        }

        // --- Ghost data before ---
        __totalAssetBefore = woeth.totalAssets();
        __sum_minted += mintedOETH;
        __minted[user] += mintedOETH;
        __user_oeth_balance_before = oeth.balanceOf(user);
        __user_woeth_balance_before = woeth.balanceOf(user);

        // Mint WOETH.
        hevm.prank(user);
        woeth.mint(sharesToMint, user);

        // --- Ghost data after ---
        last_action = LastAction.MINT;
        __totalAssetAfter = woeth.totalAssets();
        __oeth_balanace_of_woeth = oeth.balanceOf(address(woeth));
        __trackedAssets = woeth.trackedAssets();
        __yieldAssets = woeth.yieldAssets();
        __yieldEnd = woeth.yieldEnd();
        __user_oeth_balance_after = oeth.balanceOf(user);
        __user_woeth_balance_after = woeth.balanceOf(user);
    }

    /// @notice Handle redeem in WOETH.
    /// @param _userId User id to redeem WOETH.
    /// @param _amountToRedeem Amount of WOETH to redeem.
    ///        Maximum will be limited to type(uint96).max. This is a bit less than 80B.
    ///        As the max OETH total supply is set to type(uint96).max, even with 100% of the OETH supply is
    ///        deposited in the vault, the max amount of WOETH that can be redeemed is type(uint96).max as the
    ///        price cannot be go below 1.
    /// _amountToMint = type(uint96).max;
    function handler_redeem(uint8 _userId, uint96 _amountToRedeem) public {
        // Find an user with WOETH shares.
        address user;
        uint256 balance;
        uint256 len = users.length;
        for (uint256 i = _userId; i < len + _userId; i++) {
            uint256 woethBalance = woeth.balanceOf(users[i % len]);
            if (woethBalance > 0) {
                user = users[i % len];
                balance = woethBalance;
                break;
            }
        }
        if (user == address(0) || balance == 0) {
            if (USE_ASSUME) hevm.assume(false);
            else return;
        }

        // Bound amout to redeem.
        _amountToRedeem = uint96(clamp(uint256(_amountToRedeem), 1, balance, USE_LOGS));

        // --- Ghost data before ---
        __totalAssetBefore = woeth.totalAssets();
        __user_oeth_balance_before = oeth.balanceOf(user);
        __user_woeth_balance_before = woeth.balanceOf(user);

        // Redeem WOETH.
        hevm.prank(user);
        uint256 oethPreviewAmount = woeth.previewRedeem(_amountToRedeem);

        // Redeem WOETH.
        hevm.prank(user);
        uint256 oethAmount = woeth.redeem(_amountToRedeem, user, user);

        require(oethPreviewAmount == oethAmount, "Preview redeem doesn't match redeemed amount");

        // --- Ghost data after ---
        last_action = LastAction.REDEEM;
        __totalAssetAfter = woeth.totalAssets();
        __oeth_balanace_of_woeth = oeth.balanceOf(address(woeth));
        __trackedAssets = woeth.trackedAssets();
        __yieldAssets = woeth.yieldAssets();
        __yieldEnd = woeth.yieldEnd();
        __redeemed[user] += oethAmount;
        __sum_redeemed += oethAmount;
        __user_oeth_balance_after = oeth.balanceOf(user);
        __user_woeth_balance_after = woeth.balanceOf(user);

        // Burn OETH from user.
        _burnOETHFrom(user, oeth.balanceOf(user));
    }

    /// @notice Handle withdraw in WOETH.
    /// @param _userId User id to withdraw WOETH.
    /// @param _sharesToWithdraw Amount of WOETH shares to withdraw.
    ///        Maximum will be limited to type(uint96).max. This is a bit less than 80B.
    ///        As the max OETH total supply is set to type(uint96).max, even with 100% of the OETH supply is
    ///        deposited in the vault, the max amount of WOETH that can be withdrawn is type(uint96).max as the
    ///        price cannot be go below 1.
    /// _sharesToWithdraw = type(uint96).max;
    function handler_withdraw(uint8 _userId, uint96 _sharesToWithdraw) public {
        // Find an user with WOETH shares.
        address user;
        uint256 balance;
        uint256 len = users.length;
        for (uint256 i = _userId; i < len + _userId; i++) {
            uint256 woethBalance = woeth.balanceOf(users[i % len]);
            if (woethBalance > 0) {
                user = users[i % len];
                balance = woethBalance;
                break;
            }
        }
        if (user == address(0) || balance == 0) {
            if (USE_ASSUME) hevm.assume(false);
            else return;
        }

        // Bound amout to withdraw.
        _sharesToWithdraw = uint96(clamp(uint256(_sharesToWithdraw), 1, balance, USE_LOGS));
        uint256 amountToWithdraw = woeth.convertToAssets(_sharesToWithdraw);

        // --- Ghost data before ---
        __totalAssetBefore = woeth.totalAssets();
        __user_oeth_balance_before = oeth.balanceOf(user);
        __user_woeth_balance_before = woeth.balanceOf(user);

        // Withdraw WOETH.
        hevm.prank(user);
        woeth.withdraw(amountToWithdraw, user, user);

        // --- Ghost data after ---
        last_action = LastAction.WITHDRAW;
        __totalAssetAfter = woeth.totalAssets();
        __oeth_balanace_of_woeth = oeth.balanceOf(address(woeth));
        __trackedAssets = woeth.trackedAssets();
        __yieldAssets = woeth.yieldAssets();
        __yieldEnd = woeth.yieldEnd();
        __withdrawn[user] += amountToWithdraw;
        __sum_withdrawn += amountToWithdraw;
        __user_oeth_balance_after = oeth.balanceOf(user);
        __user_woeth_balance_after = woeth.balanceOf(user);

        // Burn OETH from user.
        _burnOETHFrom(user, oeth.balanceOf(user));
    }

    /// @notice Handle change supply in OETH.
    /// @param _pctIncrease Percentage increase of the total supply.
    ///        Maximum should be 10%, is base 10_000, so 10% is 1_000. uint8 is not enough. So we use uint16.
    ///        Min is 1 -> 0.01%.
    function handler_changeSupply(uint16 _pctIncrease) public {
        uint256 oethTotalSupply = oeth.totalSupply();

        // Bound pct increase.
        _pctIncrease = uint16(clamp(uint256(_pctIncrease), 1, MAX_PCT_CHANGE_TOTAL_SUPPLY, USE_LOGS));

        // Calculate new total supply
        uint256 newTotalSupply = oethTotalSupply + (oethTotalSupply * _pctIncrease) / BASE_PCT;

        // --- Ghost data before ---
        __totalAssetBefore = woeth.totalAssets();

        // Change supply
        hevm.prank(vault);
        oeth.changeSupply(newTotalSupply);

        // --- Ghost data after ---
        last_action = LastAction.CHANGE_SUPPLY;
        __totalAssetAfter = woeth.totalAssets();
        __oeth_balanace_of_woeth = oeth.balanceOf(address(woeth));
        __trackedAssets = woeth.trackedAssets();
        __yieldAssets = woeth.yieldAssets();
        __yieldEnd = woeth.yieldEnd();
    }

    /// @notice Handle donate in OETH.
    /// @param _amount Amount of OETH to donate.
    function handler_donate(uint88 _amount) public {
        // Bound amount to donate.
        _amount = uint88(clamp(uint256(_amount), 0, _mintableAmount(), USE_LOGS));
        if (_amount == 0) {
            if (USE_ASSUME) hevm.assume(false);
            else return;
        }

        // Mint OETH to this.
        uint256 mintedOETH = _mintOETHTo(address(this), _amount);

        // --- Ghost data before ---
        __totalAssetBefore = woeth.totalAssets();
        (uint256 creditBefore,,) = oeth.creditsBalanceOfHighres(address(woeth));

        // Donate OETH
        hevm.prank(address(this));
        oeth.transfer(address(woeth), mintedOETH);

        // Sum donation.
        (uint256 creditAfter,,) = oeth.creditsBalanceOfHighres(address(woeth));
        __sum_donated_credits += (creditAfter - creditBefore);

        // --- Ghost data after ---
        last_action = LastAction.DONATE;
        __totalAssetAfter = woeth.totalAssets();
        __oeth_balanace_of_woeth = oeth.balanceOf(address(woeth));
        __trackedAssets = woeth.trackedAssets();
        __yieldAssets = woeth.yieldAssets();
        __yieldEnd = woeth.yieldEnd();
    }

    /// @notice Handle pass time on chain which can result in yield drip
    /// @param _duration Amount of time to pass. 1 Day is maximum, since that is also the 
    ///        maximum yield time 
    function handler_pass_time(uint24 _duration) public {
        // Bound amount of time to pass
        _duration = uint24(clamp(uint256(_duration), 1, MAX_YIELD_TIME, USE_LOGS));
        __yieldEndBefore = woeth.yieldEnd();

        __totalAssetBefore = woeth.totalAssets();
        hevm.warp(block.timestamp + _duration); // Timestamp

        last_action = LastAction.PASS_TIME;
        __lastTimePassAmount = _duration;
        __totalAssetAfter = woeth.totalAssets();
        __oeth_balanace_of_woeth = oeth.balanceOf(address(woeth));
        __trackedAssets = woeth.trackedAssets();
        __yieldAssets = woeth.yieldAssets();
        __yieldEnd = woeth.yieldEnd();
    }

    /// @notice Transfer the whole user balance to another account
    /// @param _userIdFrom User id WOETH is transferred from
    /// @param _userIdTo User id WOETH is transferred to
    function handler_transfer(uint8 _userIdFrom, uint8 _userIdTo) public {
        uint256 len = users.length;
        address userReceiver = users[_userIdTo % len];

        address userSender;
        uint256 balance;
        for (uint256 i = _userIdFrom; i < len + _userIdFrom; i++) {
            uint256 woethBalance = woeth.balanceOf(users[i % len]);
            if (woethBalance > 0) {
                userSender = users[i % len];
                balance = woethBalance;
                break;
            }
        }
        if (userSender == address(0) || balance == 0) {
            if (USE_ASSUME) hevm.assume(false);
            else return;
        }

        __totalAssetBefore = woeth.totalAssets();

        hevm.prank(userSender);
        woeth.transfer(users[_userIdTo % len], balance);

        last_action = LastAction.TRANSFER;
        __transferFrom[userSender] = balance;
        __transferTo[userReceiver] = balance;
        __totalAssetAfter = woeth.totalAssets();
        __oeth_balanace_of_woeth = oeth.balanceOf(address(woeth));
        __trackedAssets = woeth.trackedAssets();
        __yieldAssets = woeth.yieldAssets();
        __yieldEnd = woeth.yieldEnd();
    }

    /// @notice Handle calling schedule yield
    function handler_schedule_yield() public {
        __yieldEndBefore = woeth.yieldEnd();
        __totalAssetBefore = woeth.totalAssets();

        woeth.scheduleYield();

        last_action = LastAction.SHEDULE_YIELD;
        __totalAssetAfter = woeth.totalAssets();
        __oeth_balanace_of_woeth = oeth.balanceOf(address(woeth));
        __trackedAssets = woeth.trackedAssets();
        __yieldAssets = woeth.yieldAssets();
        __yieldEnd = woeth.yieldEnd();
    }

    /// @notice Handle manage supplies in OETH.
    /// @param _amount Amount of OETH to manage.
    /// @param _increase Increase or decrease the supply.
    /// @param _nonRebasingSupply Use non-rebasing supply.
    function handler_mintOrBurnExtraOETH(uint80 _amount, bool _increase, bool _nonRebasingSupply) public {
        // --- Ghost data before ---
        __totalAssetBefore = woeth.totalAssets();

        _manageSupplies(_amount, _increase, _nonRebasingSupply ? rebasingAddr1 : nonRebasingAddr1);

        // --- Ghost data after ---
        last_action = LastAction.MINT_OR_BURN_EXTRA_OETH;
        __totalAssetAfter = woeth.totalAssets();
        __oeth_balanace_of_woeth = oeth.balanceOf(address(woeth));
        __trackedAssets = woeth.trackedAssets();
        __yieldAssets = woeth.yieldAssets();
        __yieldEnd = woeth.yieldEnd();
    }

    /// @notice Handle views function
    function handler_views(uint8 _userId, uint256 _value) public {
        // Convert to assets
        uint256 shares = clamp(_value, 0, type(uint96).max, USE_LOGS);
        (__convertToAssets_success,) =
            address(woeth).call(abi.encodeWithSelector(woeth.convertToAssets.selector, shares));

        // Convert to shares
        uint256 assets = clamp(_value, 0, type(uint96).max, USE_LOGS);
        (__convertToShares_success,) =
            address(woeth).call(abi.encodeWithSelector(woeth.convertToShares.selector, assets));

        // Total assets
        (__totalAssets_success,) = address(woeth).call(abi.encodeWithSelector(woeth.totalAssets.selector));

        // Max deposit
        (__maxDeposit_success,) =
            address(woeth).call(abi.encodeWithSelector(woeth.maxDeposit.selector, users[_userId % users.length]));

        // Max mint
        (__maxMint_success,) =
            address(woeth).call(abi.encodeWithSelector(woeth.maxMint.selector, users[_userId % users.length]));

        // Max withdraw
        (__maxWithdraw_success,) =
            address(woeth).call(abi.encodeWithSelector(woeth.maxWithdraw.selector, users[_userId % users.length]));

        // Max redeem
        (__maxRedeem_success,) =
            address(woeth).call(abi.encodeWithSelector(woeth.maxRedeem.selector, users[_userId % users.length]));
        // No need to update LastAction and totalAssetBefore/After as views are read-only.
    }

    function afterInvariant() public {
        for (uint256 i = 0; i < users.length; i++) {
            address _user = users[i];
            uint256 balance = woeth.balanceOf(_user);
            if (balance > 0) {
                hevm.prank(_user);
                uint256 oethAmount = woeth.redeem(balance, _user, _user);

                // --- Ghost data after ---
                __redeemed[_user] += oethAmount;
                __sum_redeemed += oethAmount;

                _burnOETHFrom(_user, oeth.balanceOf(_user));
            }
        }
        // Burn rebasingAddr1 and nonRebasingAddr1 OETH balances
        _burnOETHFrom(rebasingAddr1, oeth.balanceOf(rebasingAddr1));
        _burnOETHFrom(nonRebasingAddr1, oeth.balanceOf(nonRebasingAddr1));


        // --- Assertions ---
        require(__property_mint_redeem_amounts(), "Invariant mint_redeem_amounts failed");
        require(__property_mint_redeem_totalAssets(), "Invariant mint_redeem_amounts failed");
        require(__property_total_asset_interval(), "Invariant total_asset_interval failed");

    }

    //////////////////////////////////////////////////////
    /// --- INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////
    /// @notice Helper function to mint OETH to a user.
    /// @param _user User to mint OETH to.
    /// @param _amountToMint Amount of OETH to mint.
    /// @return Amount of OETH effectively minted.
    function _mintOETHTo(address _user, uint256 _amountToMint) internal returns (uint256) {
        uint256 balance = oeth.balanceOf(_user);
        hevm.prank(vault);
        oeth.mint(_user, _amountToMint);
        // This should never happen, but just in case.
        require(oeth.totalSupply() <= MAX_OETH_TOTAL_SUPPLY, "OETH: total supply exceeds max");
        return (oeth.balanceOf(_user) - balance);
    }

    /// @notice Helper function to burn OETH from a user.
    /// @param _user User to burn OETH from.
    /// @param _amountToBurn Amount of OETH to burn.
    function _burnOETHFrom(address _user, uint256 _amountToBurn) internal {
        hevm.prank(vault);
        oeth.burn(_user, _amountToBurn);
    }

    /// @notice Helper that return max amount mintable, based on the total supply of OETH.
    /// @return Amount of OETH that can be minted.
    function _mintableAmount() internal view returns (uint256) {
        uint256 oethTotalSupply = oeth.totalSupply();
        return (oethTotalSupply >= MAX_OETH_TOTAL_SUPPLY) ? 0 : (MAX_OETH_TOTAL_SUPPLY - oethTotalSupply);
    }

    /// @notice Helper function to manage supplies in OETH.
    /// @param _amount Amount of OETH to manage.
    /// @param _increase Increase or decrease the supply.
    /// @param _address Address to manage supplies.
    function _manageSupplies(uint256 _amount, bool _increase, address _address) internal {
        if (_increase) {
            _amount = clamp(_amount, 0, _mintableAmount(), USE_LOGS);
            if (_amount == 0) {
                if (USE_ASSUME) hevm.assume(false);
                else return;
            }

            hevm.prank(vault);
            oeth.mint(_address, _amount);
        } else {
            uint256 balance = oeth.balanceOf(_address);
            if (balance <= INITIAL_DEAD_OETH_BALANCE) {
                if (USE_ASSUME) hevm.assume(false);
                else return;
            }

            _amount = clamp(_amount, 0, balance - INITIAL_DEAD_OETH_BALANCE, USE_LOGS);
            _burnOETHFrom(_address, _amount);
        }
        require(oeth.balanceOf(dead) >= INITIAL_DEAD_OETH_BALANCE, "Setup: invalid rebasing dead balance");
        require(oeth.balanceOf(dead2) >= INITIAL_DEAD_OETH_BALANCE, "Setup: invalid rebasing dead balance");
    }
}
