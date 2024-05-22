// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;

import "./ERC20Base.sol";

/**
 * @title Expandable Supply Token Base
 * @dev Extends ERC20Base to support expandable token supplies.
 * Allows proposals for creating additional tokens and disabling further creation.
 */
contract ExpandableSupplyTokenBase is ERC20Base {
    mapping(uint256 => CreateTokensProposal) public createTokensProposals;
    uint256 public projectId;
    bool public createMoreTokensDisabled = false;
    uint256[42] private __gap;

    /** @dev Emitted when a proposal is executed */
    event ExecuteProposal(uint256 projectId, uint256 proposalId);
    /** @dev Emitted when initial tokens are created */
    event InitialTokensCreated(uint256 creatorSupply);
    /** @dev Emitted when tokens are created */
    event TokensCreated(uint256 value);
    /** @dev Emitted when creating more tokens is disabled */
    event CreateMoreTokensDisabledEvent();

    /** @dev Struct to hold proposals for creating tokens. */
    struct CreateTokensProposal {
        uint256 amount;
    }

    /**
     * @dev Creates initial token supply. Only callable internally.
     * @param creatorSupply Amount of tokens for the contract creator.
     */
    function createInitialTokens(uint256 creatorSupply) internal {
        require(__totalSupply == 0);
        projectId = contractsManagerContract.nextProjectId() - 1;
        __totalSupply = creatorSupply;
        __balanceOf[msg.sender] = creatorSupply;
        emit InitialTokensCreated(creatorSupply);
    }

    /**
     * @dev Internal function to create tokens.
     * @param value The amount of tokens to create.
     * @return bool Returns true if tokens are successfully created.
     */
    function createTokens(uint256 value) internal returns (bool) {
        __totalSupply += value;
        __balanceOf[address(this)] = value;
        __allowances[address(this)][address(fundsManagerContract)] += value;
        fundsManagerContract.depositToken(projectId, address(this), value);
        emit TokensCreated(value);
        return true;
    }

    /**
     * @dev Proposes the creation of new tokens.
     * @param amount The amount of new tokens to create.
    */
    function proposeCreateTokens(uint256 amount) external {
        require(!createMoreTokensDisabled, "Increasing token supply is permanently disabled");
        createTokensProposals[proposalContract.nextProposalId(projectId)].amount = amount;

        proposalContract.createProposal(projectId, CREATE_TOKENS, msg.sender);
    }

    /**
     * @dev Proposes to disable creation of new tokens
    */
    function proposeDisableTokenCreation() external {
        proposalContract.createProposal(projectId, DISABLE_CREATE_MORE_TOKENS, msg.sender);
    }

    /**
     * @dev Executes a proposal based on its ID.
     * @param proposalId The ID of the proposal to execute.
     */
    function executeProposal(uint256 proposalId) external {
        (uint32 typeOfProposal, , bool willExecute,, uint256 endTime) = proposalContract.proposals(projectId, proposalId);
        uint256 expirationPeriod = parametersContract.parameters(projectId, keccak256("ExpirationPeriod"));
        require(proposalId < proposalContract.nextProposalId(projectId), "Proposal does not exist");
        require(endTime <= block.timestamp, "Can't execute proposal, buffer time did not end yet");
        require(endTime + expirationPeriod >= block.timestamp, "Can't execute proposal, execute period has expired");
        require(willExecute, "Can't execute, proposal was rejected or vote count was not locked");
        proposalContract.setWillExecute(projectId, proposalId, false);
        uint256 value = parametersContract.parameters(projectId, keccak256("RequiredVotingPowerPercentageToCreateTokens"));
        (,, bool checkVotes) = proposalContract.checkVoteCount(projectId, proposalId, value);
        if (typeOfProposal == CREATE_TOKENS) {
            require(checkVotes, "RequiredVotingPowerPercentageToCreateTokens not met");
            uint256 amount = createTokensProposals[proposalId].amount;
            delete createTokensProposals[proposalId];
            createTokens(amount);
        } else if (typeOfProposal == DISABLE_CREATE_MORE_TOKENS) {
            createMoreTokensDisabled = true;
            emit CreateMoreTokensDisabledEvent();
        } else {
            revert('Unexpected proposal type');
        }
        proposalContract.deleteProposal(projectId, proposalId);
        emit ExecuteProposal(projectId, proposalId);
    }
}
