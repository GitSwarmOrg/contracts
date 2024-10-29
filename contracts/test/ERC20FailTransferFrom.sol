// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "../prod/1.1/base/ERC20Base.sol";

contract ERC20FailTransferFrom is ERC20Base {
    uint immutable public projectId;
    constructor(
        string memory prjId,
        uint creatorSupply,
        address contractsManagerAddress,
        address fundsManagerContractAddress,
        address proposalContractAddress,
        address parametersContractAddress,
        string memory tokenName,
        string memory tokenSymbol
    ) {
        require(creatorSupply != 0 && 0 == __totalSupply);
        name = tokenName;
        symbol = tokenSymbol;
        _init(address(0), fundsManagerContractAddress, parametersContractAddress, proposalContractAddress, address(0), contractsManagerAddress);
        contractsManagerContract.createProject(prjId, address(this), false);
        projectId = contractsManagerContract.nextProjectId() - 1;
        __totalSupply = creatorSupply;
        __balanceOf[msg.sender] = creatorSupply;
    }

    function transferFrom(address _from, address _to, uint _value) virtual override external returns (bool success) {
        require(__allowances[_from][msg.sender] >= _value, "Token: insufficient allowance");
        require(_to != address(0), "Token: sending to address(0) is forbidden");
        require(__balanceOf[_from] >= _value, "Token: insufficient balance");
        __balanceOf[_from] -= _value;
        __balanceOf[_to] += _value;
        __allowances[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return false;
    }
}
