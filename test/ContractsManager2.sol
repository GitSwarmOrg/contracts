// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity ^0.8.0;

import "../prod/1.0.0/ContractsManager.sol";

contract ContractsManager2 is ContractsManager {

    function changeNextProjectId(uint _nextProjectId) public {
        nextProjectId = _nextProjectId;
    }

}
