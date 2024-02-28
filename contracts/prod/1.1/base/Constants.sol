pragma solidity ^0.8.20;

contract Constants {

    address constant public BURN_ADDRESS = 0x1111111111111111111111111111111111111111;

    // Proposal types
    uint32 constant public TRANSACTION = 1;
    uint32 constant public RECURRING_TRANSACTION = 2;
    uint32 constant public CREATE_TOKENS = 3;
    uint32 constant public TOKEN_TRADE = 4;
    uint32 constant public CHANGE_PARAMETER = 5;
    uint32 constant public STOP_RECURRING_TRANSACTION = 6;
    uint32 constant public STOP_TOKEN_TRADE = 7;
    uint32 constant public AUCTION = 8;
    uint32 constant public CHANGE_TRUSTED_ADDRESS = 9;
    uint32 constant public TRANSFER_TO_GAS_ADDRESS = 10;
    uint32 constant public ADD_BURN_ADDRESS = 11;
    uint32 constant public UPGRADE_CONTRACTS = 12;
    uint32 constant public CHANGE_VOTING_TOKEN_ADDRESS = 13;
}
