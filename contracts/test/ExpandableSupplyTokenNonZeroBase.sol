// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;

import "../prod/1.1/base/ExpandableSupplyTokenBase.sol";

contract ExpandableSupplyTokenNonZeroBase is ExpandableSupplyTokenBase {
    constructor(
    ) {
        __totalSupply = 1;
        createInitialTokens(1, 2);
    }
}
