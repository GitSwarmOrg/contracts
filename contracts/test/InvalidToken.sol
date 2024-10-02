// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.27;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";


contract InvalidToken is Initializable {
    string public symbol;
    string public name;

    function initialize(
    ) public initializer {

    }

    function decimals() external pure returns (uint dec) {
        dec = 18;
    }

    function balanceOf(address) external pure returns (uint balance) {
        return 0;
    }

    function transfer(address, uint) external pure returns (bool success) {
        return false;
    }

    function approve(address, uint) external pure returns (bool success) {
        return true;
    }

    function allowance(address, address) external pure returns (uint remaining) {
        return 9;
    }

    function createTokens(uint) private pure returns (bool) {
        return true;
    }

}
