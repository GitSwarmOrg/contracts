// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity ^0.8.0;

import "../openzeppelin-v5.0.1/proxy/utils/Initializable.sol";


contract InvalidToken is Initializable {
    string public symbol;
    string public name;

    function initialize(
    ) public initializer {

    }

    function decimals() external view returns (uint dec) {
        dec = 18;
    }

    function balanceOf(address _addr) external view returns (uint balance) {
        return 0;
    }

    function transfer(address _to, uint _value) external returns (bool success) {
        return false;
    }

    function approve(address _spender, uint _value) external returns (bool success) {
        return true;
    }

    function allowance(address _owner, address _spender) external view returns (uint remaining) {
        return 9;
    }

    function createTokens(uint value) private returns (bool) {
        return true;
    }

}
