// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

abstract contract HelperAssumption {
    /// @notice As WOETH contract will be used for OUSD as OS (Sonic), we need to ensure that
    ///         the maximum total supply is set realistically.
    ///         - WOETH: There is less than 3M WETH in circulation in mainnet.
    ///         - OUSD : The biggest stablecoin has a total supply of 67B (USDT on mainnet and Tron).
    ///         - OS   : The current total supply of S is 4B.
    ///@dev Type(uint96).max is just a bit less than 80B. This ensure use than we are not using
    ///     a value that is too high, but still high enough to be realistic.
    uint256 public constant MAX_OETH_TOTAL_SUPPLY = type(uint96).max;

    uint256 public constant BASE_PCT = 10_000;

    /// @notice Maximum percentage change allowed for the total supply.
    uint256 public constant MAX_PCT_CHANGE_TOTAL_SUPPLY = 1_000; // 10%

    /// @notice Initial amount of OETH send to dead addresses.
    uint256 public constant INITIAL_DEAD_OETH_BALANCE = 11e16;

    /// @notice Maximum amount of time a yield will drip without a contract interaction
    uint256 MAX_YIELD_TIME = 1 days;
}
