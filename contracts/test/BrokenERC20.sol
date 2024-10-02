// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

contract Broken_ERC20_Missing_totalSupply {
}

contract Broken_ERC20_Missing_balanceOf {
    string public totalSupply = 'totalSupply';
}

contract Broken_ERC20_Missing_allowance {
    string public totalSupply = 'totalSupply';

    function balanceOf(address) public pure returns (uint) {return 0;}
}
