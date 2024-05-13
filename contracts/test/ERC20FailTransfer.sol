// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "../prod/1.1/base/ERC20Base.sol";

contract ERC20FailTransfer is ERC20Base {
    uint immutable public projectId;
    constructor(
        string memory prjId,
        uint supply,
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
        __totalSupply = supply + creatorSupply;
        __balanceOf[msg.sender] = creatorSupply;
        __balanceOf[address(fundsManagerContract)] = supply;
        fundsManagerContract.updateBalance(projectId, address(this), supply);
    }


    function transfer(address _to, uint _value) virtual override external returns (bool success) {
        require(_to != address(0), "Token: sending to address(0) is forbidden");
        require(_value <= __balanceOf[msg.sender], "Token: insufficient balance");
        __balanceOf[msg.sender] -= _value;
        __balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return false;
    }

}
