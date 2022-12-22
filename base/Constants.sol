pragma solidity ^0.8.0;

contract Constants {

    address constant BURN_ADDRESS = 0x1111111111111111111111111111111111111111;

    // Contracts
    uint32 constant public TOKEN = 0;
    uint32 constant public DELEGATES = 1;
    uint32 constant public FUNDS_MANAGER = 2;
    uint32 constant public TOKEN_SELL = 3;
    uint32 constant public PROPOSAL = 4;
    uint32 constant public GAS_STATION = 5;

    // Proposal types
    uint32 constant public TRANSACTION = 1;
    uint32 constant public RECURRING_TRANSACTION = 2;
    uint32 constant public CREATE_TOKENS = 3;
    uint32 constant public TOKEN_TRADE = 4;
    uint32 constant public CHANGE_PARAMETER = 5;
    uint32 constant public STOP_RECURRING_TRANSACTION = 6;
    uint32 constant public STOP_TOKEN_TRADE = 7;
    uint32 constant public AUCTION = 8;
    uint32 constant public CHANGE_CONTRACT_ADDRESS = 9;
    uint32 constant public TRANSFER_TO_GAS_ADDRESS = 10;
    uint32 constant public ADD_BURN_ADDRESS = 11;
}
