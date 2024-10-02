// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.27;

import "./Common.sol";

/**
 * @title ERC20 Basic Token
 * @dev Implementation of the interface of the ERC20 standard.
 * @notice Inherits functionality from Common and implements IERC20.
 */
contract ERC20Base is IERC20, Common {
    string public symbol;
    string public name;
    uint8 internal constant DECIMALS = 18;
    uint256 internal __totalSupply;
    mapping(address => uint256) internal __balanceOf;
    mapping(address => mapping(address => uint256)) internal __allowances;

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * @return dec Number of decimals.
     */
    function decimals() external pure returns (uint256 dec) {
        dec = DECIMALS;
    }

    /**
     * @dev Returns the amount of tokens in existence.
     * @return _totalSupply Total supply of tokens.
     */
    function totalSupply() override external view returns (uint256 _totalSupply) {
        _totalSupply = __totalSupply;
    }

    /**
     * @dev Returns the amount of tokens owned by `_addr`.
     * @param _addr Address of the token owner.
     * @return balance Token balance of the owner.
     */
    function balanceOf(address _addr) override external view returns (uint256 balance) {
        return __balanceOf[_addr];
    }

    /**
     * @dev Moves `_value` tokens from the caller's account to account `_to`.
     * @notice Emit a Transfer event on successful transfer.
     * @param _to Recipient address.
     * @param _value Amount of tokens to transfer.
     * @return success Boolean value indicating operation success.
     */
    function transfer(address _to, uint256 _value) virtual override external returns (bool success) {
        require(_to != address(0), "Token: sending to address(0) is forbidden");
        require(_value <= __balanceOf[msg.sender], "Token: insufficient balance");
        __balanceOf[msg.sender] -= _value;
        __balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /**
     * @dev Moves `_value` tokens from address `_from` to address `_to` using the allowance mechanism.
     * @notice Emit a TransferredFrom event on successful transfer.
     * @param _from Source address.
     * @param _to Recipient address.
     * @param _value Amount of tokens to transfer.
     * @return success Boolean value indicating operation success.
     */
    function transferFrom(address _from, address _to, uint256 _value) virtual override external returns (bool success) {
        require(__allowances[_from][msg.sender] >= _value, "Token: insufficient allowance");
        require(_to != address(0), "Token: sending to address(0) is forbidden");
        require(__balanceOf[_from] >= _value, "Token: insufficient balance");
        __balanceOf[_from] -= _value;
        __balanceOf[_to] += _value;
        __allowances[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    /**
     * @dev Sets `_value` as the allowance of `_spender` over the caller's tokens.
     * @notice Emit an Approval event on successful approval.
     * @param _spender Address authorized to spend on the caller's behalf.
     * @param _value Amount of tokens approved for spending.
     * @return success Boolean value indicating operation success.
     */
    function approve(address _spender, uint256 _value) override external returns (bool success) {
        __allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
     * @dev Returns the remaining number of tokens that `_spender` is allowed to spend on behalf of `_owner`.
     * @param _owner Address owning the tokens.
     * @param _spender Address authorized to spend the tokens.
     * @return remaining Number of remaining tokens allowed to spend.
     */
    function allowance(address _owner, address _spender) override external view returns (uint256 remaining) {
        return __allowances[_owner][_spender];
    }
}
