// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;

/**
 * @title ERC20 Token Standard Interface
 * @dev Defines the standard functions for an ERC20 token, enabling interoperability across different platforms and contracts.
 * This interface facilitates the implementation of a standard API for tokens within smart contracts.
 * This contract serves as a foundation for the ERC20Base contract.
 */
interface ERC20interface {
    function decimals() external view returns (uint dec);

    function totalSupply() external view returns (uint _totalSupply);

    function balanceOf(address _owner) external view returns (uint balance);

    function transfer(address _to, uint _value) external returns (bool success);

    function transferFrom(address _from, address _to, uint _value) external returns (bool success);

    function approve(address _spender, uint _value) external returns (bool success);

    function allowance(address _owner, address _spender) external view returns (uint remaining);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    event Transfer(address indexed _from, address indexed _to, uint _value);
    event TransferredFrom(address indexed _from, address indexed _to, uint _value);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
}
