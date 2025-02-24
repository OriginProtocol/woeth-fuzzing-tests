// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// Contracts
import {Properties} from "./Properties.sol";

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
        if (_amountToMint == 0) return; // Todo: Log return reason

        // Mint OETH to the user.
        _mintOETHTo(user, _amountToMint);
        uint256 amountToMint = oeth.balanceOf(user);

        // Deposit OETH.
        hevm.prank(user);
        woeth.deposit(amountToMint, user);
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

        // Convert shares in OETH amount (to ensure mintable amount).
        uint256 amountToMint = woeth.previewMint(_sharesToMint);
        if (amountToMint >= _mintableAmount()) return; // Todo: Log return reason

        // Mint OETH to the user.
        uint256 mintedOETH = _mintOETHTo(user, amountToMint);
        // Convert back real user minted amount in shares.
        uint256 sharesToMint = woeth.convertToShares(mintedOETH);

        // Mint WOETH.
        hevm.prank(user);
        woeth.mint(sharesToMint, user);
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
        if (user == address(0)) return; // Todo: Log return reason

        // Bound amout to redeem.
        _amountToRedeem = uint96(clamp(uint256(_amountToRedeem), 0, balance, USE_LOGS));

        // Redeem WOETH.
        hevm.prank(user);
        woeth.redeem(_amountToRedeem, user, user);

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
        if (user == address(0)) return; // Todo: Log return reason

        // Bound amout to withdraw.
        _sharesToWithdraw = uint96(clamp(uint256(_sharesToWithdraw), 0, balance, USE_LOGS));
        uint256 amountToWithdraw = woeth.convertToAssets(_sharesToWithdraw);

        // Withdraw WOETH.
        hevm.prank(user);
        woeth.withdraw(amountToWithdraw, user, user);

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

        hevm.prank(vault);
        oeth.changeSupply(newTotalSupply);
    }

    /// @notice Handle donate in OETH.
    /// @param _amount Amount of OETH to donate.
    function handler_donate(uint88 _amount) public {
        // Bound amout to donate.
        _amount = uint88(clamp(uint256(_amount), 0, _mintableAmount(), USE_LOGS));
        if (_amount == 0) return; // Todo: Log return reason

        // Mint OETH to this.
        uint256 mintedOETH = _mintOETHTo(address(this), _amount);

        // Donate OETH
        hevm.prank(address(this));
        oeth.transfer(address(woeth), mintedOETH);
        oeth.rebaseState(address(woeth));
    }

    /// @notice Handle manage supplies in OETH.
    /// @param _amount Amount of OETH to manage.
    /// @param _increase Increase or decrease the supply.
    /// @param _nonRebasingSupply Use non-rebasing supply.
    function handler_manageSupplies(uint88 _amount, bool _increase, bool _nonRebasingSupply) public {
        // Dead is rebasing
        // Dead2 is non-rebasing
        _manageSupplies(_amount, _increase, _nonRebasingSupply ? dead : dead2);
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
            if (_amount == 0) return; // Todo: Log return reason

            hevm.prank(vault);
            oeth.mint(_address, _amount);
        } else {
            uint256 balance = oeth.balanceOf(_address);
            if (balance <= INITIAL_DEAD_OETH_BALANCE) return; // Todo: Log return reason

            _amount = clamp(_amount, 0, balance - INITIAL_DEAD_OETH_BALANCE, USE_LOGS);
            hevm.prank(vault);
            oeth.burn(_address, _amount);
        }
        require(oeth.balanceOf(dead) >= INITIAL_DEAD_OETH_BALANCE, "Setup: invalid rebasing dead balance");
        require(oeth.balanceOf(dead2) >= INITIAL_DEAD_OETH_BALANCE, "Setup: invalid rebasing dead balance");
    }
}
