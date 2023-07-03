// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../prod/1.0.0/Proposal.sol";

contract Proposal2 is Proposal {

    function changeVoteDuration(uint projectId) public {
        parameters[projectId][keccak256("VoteDuration")].value = 5 days;
    }
}
