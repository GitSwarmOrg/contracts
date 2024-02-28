// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../prod/1.1/Proposal.sol";

contract Proposal2 is Proposal {

    function changeVoteDuration(uint projectId) public {
        parameters[projectId][keccak256("VoteDuration")] = 5 days;
    }
}
