// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

contract Broken_ERC20_Missing_name {
    constructor () {}
}
contract Broken_ERC20_Missing_symbol {
    string public name = 'name';
    constructor () {}
}
contract Broken_ERC20_Missing_decimals {
    string public name = 'name';
    string public symbol = 'symbol';
    constructor () {}
}
contract Broken_ERC20_Missing_totalSupply {
    string public name = 'name';
    string public symbol = 'symbol';
    string public decimals = 'decimals';
}
contract Broken_ERC20_Missing_balanceOf {
    string public name = 'name';
    string public symbol = 'symbol';
    string public decimals = 'decimals';
    string public totalSupply = 'totalSupply';
}
contract Broken_ERC20_Missing_allowance {
    string public name = 'name';
    string public symbol = 'symbol';
    string public decimals = 'decimals';
    string public totalSupply = 'totalSupply';
    function balanceOf(address) public pure returns (uint) { return 0;}
}
