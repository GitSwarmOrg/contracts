// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;

import "./ERC20interface.sol";
import "./ERC20Base.sol";

contract ExpandableSupplyTokenBase is ERC20Base {
    mapping(uint => CreateTokensProposal) public createTokensProposals;
    uint public projectId;
    bool public createMoreTokensDisabled = false;

    event ExecuteProposal(uint projectId, uint proposalId);
    event InitialTokensCreated(uint supply, uint creatorSupply);
    event TokensCreated(uint value);
    event CreateMoreTokensDisabledEvent();

    struct CreateTokensProposal {
        uint amount;
    }

    function createInitialTokens(uint supply, uint creatorSupply) internal {
        require(__totalSupply == 0);
        projectId = contractsManagerContract.nextProjectId() - 1;
        __totalSupply = supply + creatorSupply;
        __balanceOf[msg.sender] = creatorSupply;
        __balanceOf[address(fundsManagerContract)] = supply;
        fundsManagerContract.updateBalance(projectId, address(this), supply);
        emit InitialTokensCreated(supply, creatorSupply);
    }

    function createTokens(uint value) internal returns (bool) {
        __totalSupply += value;
        __balanceOf[address(fundsManagerContract)] += value;
        fundsManagerContract.updateBalance(projectId, address(this), value);
        emit TokensCreated(value);
        return true;
    }

    function proposeCreateTokens(uint amount) external {
        require(!createMoreTokensDisabled, "Increasing token supply is permanently disabled");
        createTokensProposals[proposalContract.nextProposalId(projectId)].amount = amount;

        proposalContract.createProposal(projectId, CREATE_TOKENS, msg.sender);
    }

    function executeProposal(uint proposalId) external {
        (uint32 typeOfProposal, , bool willExecute,, uint256 endTime) = proposalContract.proposals(projectId, proposalId);
        uint expirationPeriod = parametersContract.parameters(0, keccak256("ExpirationPeriod"));
        require(proposalId < proposalContract.nextProposalId(projectId), "Proposal does not exist");
        require(endTime <= block.timestamp, "Can't execute proposal, buffer time did not end yet");
        require(endTime + expirationPeriod >= block.timestamp, "Can't execute proposal, execute period has expired");
        require(willExecute, "Can't execute, proposal was rejected or vote count was not locked");
        proposalContract.setWillExecute(projectId, proposalId, false);
        uint value = parametersContract.parameters(projectId, keccak256("RequiredVotingPowerPercentageToCreateTokens"));
        (,, bool checkVotes) = proposalContract.checkVoteCount(projectId, proposalId, value);
        if (typeOfProposal == CREATE_TOKENS) {
            require(checkVotes, "Not enough votes");
            uint amount = createTokensProposals[proposalId].amount;
            delete createTokensProposals[proposalId];
            proposalContract.deleteProposal(projectId, proposalId);
            createTokens(amount);
        } else if (typeOfProposal == DISABLE_CREATE_MORE_TOKENS) {
            createMoreTokensDisabled = true;
            emit CreateMoreTokensDisabledEvent();
        } else {
            revert('Unexpected proposal type');
        }
        emit ExecuteProposal(projectId, proposalId);
    }
}
