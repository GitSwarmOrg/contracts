// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;

import "./ERC20interface.sol";
import "./Common.sol";

contract ERC20Base is ERC20interface, Common {
    string public symbol;
    string public name;
    uint8 public constant _decimals = 18;
    uint internal  __totalSupply;
    mapping(address => uint) internal __balanceOf;
    mapping(address => mapping(address => uint)) internal __allowances;


    function decimals() override external pure returns (uint dec) {
        dec = _decimals;
    }

    function totalSupply() override external view returns (uint _totalSupply) {
        _totalSupply = __totalSupply;
    }

    function balanceOf(address _addr) override external view returns (uint balance) {
        return __balanceOf[_addr];
    }

    function transfer(address _to, uint _value) override external returns (bool success) {
        require(_to != address(0), "Token: sending to null is forbidden");
        require(_value <= __balanceOf[msg.sender], "Token: insufficient balance");
        __balanceOf[msg.sender] -= _value;
        __balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint _value) override external returns (bool success) {
        require(__allowances[_from][msg.sender] >= _value, "Token: insufficient allowance");
        require(_to != address(0), "Token: sending to null is forbidden");
        require(__balanceOf[_from] >= _value, "Token: insufficient balance");
        __balanceOf[_from] -= _value;
        __balanceOf[_to] += _value;
        __allowances[_from][msg.sender] -= _value;
        emit TransferredFrom(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint _value) override external returns (bool success) {
        __allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) override external view returns (uint remaining) {
        return __allowances[_owner][_spender];
    }


}
