// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

library Log {
    event log(string message);

    event log_named_uint(string name, uint256 number);
    event log_named_int(string name, int256 number);
    event log_named_address(string name, address addr);
    event log_named_bool(string name, bool boolean);
    event log_named_bytes32(string name, bytes32 data);
    event log_named_bytes(string name, bytes data);
}
