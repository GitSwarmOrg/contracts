// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;

import "../prod/1.1/ContractsManager.sol";

contract ContractsManager2 is ContractsManager {

    function changeNextProjectId(uint _nextProjectId) public {
        nextProjectId = _nextProjectId;
    }

}
