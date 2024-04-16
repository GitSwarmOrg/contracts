// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Parameters} from "../prod/1.1/Parameters.sol";

contract Parameters2 is Parameters {

    function changeVoteDuration(uint projectId) public {
        parameters[projectId][keccak256("VoteDuration")] = 5 days;
    }
}
