// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity ^0.8.20;

import "./base/ERC20interface.sol";
import "./base/Common.sol";
//import "hardhat/console.sol";

contract Token is ERC20interface, Common {
    string public symbol;
    string public name;
    uint8 public constant _decimals = 18;
    uint internal  __totalSupply;
    mapping(address => uint) internal __balanceOf;
    mapping(address => mapping(address => uint)) internal __allowances;
    mapping(uint => CreateTokensProposal) public createTokensProposals;
    uint immutable public projectId;

    event ExecuteProposal(uint projectId, uint proposalId);

    struct CreateTokensProposal {
        uint amount;
    }

    constructor(
        string memory prjId,
        uint supply,
        uint creatorSupply,
        address contractsManagerAddress,
        address fundsManagerContractAddress,
        address proposalContractAddress,
        string memory tokenName,
        string memory tokenSymbol
    ) {
        require(creatorSupply != 0 && 0 == __totalSupply);
        name = tokenName;
        symbol = tokenSymbol;
        _init(address(0), fundsManagerContractAddress, address(0), proposalContractAddress, address(0), contractsManagerAddress);
        contractsManagerContract.createProject(prjId, address(this), false);
        projectId = contractsManagerContract.nextProjectId() - 1;
        __totalSupply = supply + creatorSupply;
        __balanceOf[msg.sender] = creatorSupply;
        __balanceOf[address(fundsManagerContract)] = supply;
        fundsManagerContract.updateBalance(projectId, address(this), supply);
    }

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

    function createTokens(uint value) internal returns (bool) {
        __totalSupply += value;
        __balanceOf[address(fundsManagerContract)] += value;
        fundsManagerContract.updateBalance(projectId, address(this), value);
        return true;
    }

    function proposeCreateTokens(uint amount) external {
        createTokensProposals[proposalContract.nextProposalId(projectId)].amount = amount;

        proposalContract.createProposal(projectId, CREATE_TOKENS, msg.sender);
    }

    function executeProposal(uint proposalId) external {
        (uint32 typeOfProposal, uint256 endTime, , bool willExecute,) = proposalContract.proposals(projectId, proposalId);
        uint expirationPeriod = proposalContract.parameters(0, keccak256("ExpirationPeriod"));
        require(proposalId < proposalContract.nextProposalId(projectId), "Proposal does not exist");
        require(endTime <= block.timestamp, "Can't execute proposal, buffer time did not end yet");
        require(endTime + expirationPeriod >= block.timestamp, "Can't execute proposal, execute period has expired");
        require(willExecute, "Can't execute, proposal was rejected or vote count was not locked");
        proposalContract.setWillExecute(projectId, proposalId, false);
        uint value = proposalContract.parameters(projectId, keccak256("RequiredVotingPowerPercentageToCreateTokens"));
        (,, bool checkVotes) = proposalContract.checkVoteCount(projectId, proposalId, value);
        if (typeOfProposal == CREATE_TOKENS && checkVotes) {
            uint amount = createTokensProposals[proposalId].amount;
            delete createTokensProposals[proposalId];
            proposalContract.deleteProposal(projectId, proposalId);
            createTokens(amount);
        } else {
            revert('Unexpected proposal type');
        }
        emit ExecuteProposal(projectId, proposalId);
    }
}
