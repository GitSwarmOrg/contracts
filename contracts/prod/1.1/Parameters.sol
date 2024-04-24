// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;

import "./base/Common.sol";

contract Parameters is Common, Initializable, IParameters {

    /**
     * @notice Has privilege of creating proposals on any project and tie breaking for proposals
     */
    address public gitswarmAddress;

    /**
     * @notice Stores change parameter proposals for each project
     * @dev Nested mapping of project ID to proposal ID to ChangeParameterProposal
     */
    mapping(uint => mapping(uint => ChangeParameterProposal)) public changeParameterProposals;

    /**
     * @notice New mapping to store just the value of parameters
     * @dev Mapping of project ID to parameter name (hashed) to its value
     */
    mapping(uint => mapping(bytes32 => uint)) public parameters;

    /**
     * @notice Stores the min values for parameters globally
     * @dev Mapping of parameter name (hashed) to its minimum value
     */
    mapping(bytes32 => uint) public parameterMinValues;

    /**
     * @notice Stores the max values for parameters globally
     * @dev Mapping of parameter name (hashed) to its maximum value
     */
    mapping(bytes32 => uint) public parameterMaxValues;

    /**
     * @notice Trusted addresses per project, may include other contracts or external addresses.
     * They can call any restricted methods, this enables them to send funds without proposals
     */
    mapping(uint => address[]) public trustedAddresses;

    /**
     * @notice Stores proposals for changing trusted addresses
     */
    mapping(uint => mapping(uint => ChangeTrustedAddressProposal)) public changeTrustedAddressProposals;

    /**
     * @notice Struct for holding change parameter proposal data
     * @dev Contains the parameter name and the proposed value
     */
    struct ChangeParameterProposal {
        bytes32 parameterName;
        uint value;
    }

    /**
     * @notice A proposal structure for changing a trusted address.
     * @dev Stores the index of the address in the `trustedAddresses` array and the new trusted address.
     */
    struct ChangeTrustedAddressProposal {
        uint32 index;
        address trustedAddress;
    }

    /**
     * @dev Emitted when a trusted address is changed for a project.
     * @param projectId The ID of the project related to the change.
     * @param proposalId The ID of the proposal that initiated the change.
     * @param index The index of the trusted address.
     * @param trustedAddress The new trusted address.
     */
    event ChangeTrustedAddress(uint projectId, uint proposalId, uint32 index, address trustedAddress);

    /**
     * @notice Emitted when a proposal is executed.
     * @param projectId The ID of the project for which the proposal is made.
     * @param proposalId The ID of the proposal being executed.
     */
    event ExecuteProposal(uint projectId, uint proposalId);

    /**
     * @notice Emitted when the GitSwarm address is removed from the system.
     * @param who The address of the GitSwarm being removed.
     */
    event GitSwarmAddressRemoved(address who);

    /**
     * @notice Emitted when a proposal is successfully contested, which happens when:
     * - there are more no votes than yes votes or
     * - the VetoMinimumPercentage (percentage of circulating supply) has been met
     * @param projectId The ID of the project for which the proposal is made.
     * @param proposalId The ID of the contested proposal.
     * @param yesVotes The total number of yes votes the proposal received before being contested.
     * @param noVotes The total number of no votes the proposal received before being contested.
     */
    event ContestedProposal(uint projectId, uint proposalId, uint yesVotes, uint noVotes);

    /**
     * @notice Initializes the contract with necessary addresses and setups
     * @dev Sets up various components of the proposal system including parameters
     */
    function initialize(
        address _gitswarmAddress,
        address _delegates,
        address _fundsManager,
        address _parameters,
        address _proposal,
        address _gasStation,
        address _contractsManager
    ) public initializer {
        _init(_delegates, _fundsManager, _parameters, _proposal, _gasStation, _contractsManager);
        gitswarmAddress = _gitswarmAddress;
        initializeParameterMinMax();
        internalInitializeParameters(0);
    }

    function initializeParameterMinMax() internal {
        // 60 second values are for testing only. TODO: Change to 1 day for mainnet.

        // Proposal voting duration
        parameterMinValues[keccak256("VoteDuration")] = 60 seconds;
        parameterMaxValues[keccak256("VoteDuration")] = 30 days;

        // For how long a proposal can be contested after the voting stage
        parameterMinValues[keccak256("BufferBetweenEndOfVotingAndExecuteProposal")] = 60 seconds;
        parameterMaxValues[keccak256("BufferBetweenEndOfVotingAndExecuteProposal")] = 30 days;

        // Minimum percentage of the project's token required to make a new proposal is 100/MaxNrOfVoters
        parameterMinValues[keccak256("MaxNrOfVoters")] = 10;
        parameterMaxValues[keccak256("MaxNrOfVoters")] = 10000;

        // Percentage of yes votes required for a create-more-tokens proposal to pass
        parameterMinValues[keccak256("RequiredVotingPowerPercentageToCreateTokens")] = 50;
        parameterMaxValues[keccak256("RequiredVotingPowerPercentageToCreateTokens")] = 100;

        // Percentage of the project's token amount necessary to veto any proposal
        parameterMinValues[keccak256("VetoMinimumPercentage")] = 25;
        parameterMaxValues[keccak256("VetoMinimumPercentage")] = 50;

        // Maximum period in which a proposal can be executed
        parameterMinValues[keccak256("ExpirationPeriod")] = 60 seconds;
        parameterMaxValues[keccak256("ExpirationPeriod")] = 30 days;
    }

    /**
     * @notice Initializes parameters for a project
     * @dev Sets initial values for parameters for a given project
     */
    function initializeParameters(uint projectId) external restricted(projectId) {
        internalInitializeParameters(projectId);
    }

    function internalInitializeParameters(uint projectId) internal virtual {
        // 60 second values are for testing only. TODO: Change to 3 days for mainnet.
        // 5 minute ExpirationPeriod is for testing only. TODO: Change to 7 days for mainnet.

        parameters[projectId][keccak256("VoteDuration")] = 60 seconds;

        // MaxNrOfVoters set to 1000 means that a minimum percentage of 0.1% of the circulating supply of tokens
        // is needed to vote on/create a proposal. This helps mitigate the risk of counting votes costing more gas than
        // the block limit
        parameters[projectId][keccak256("MaxNrOfVoters")] = 1000;
        parameters[projectId][keccak256("BufferBetweenEndOfVotingAndExecuteProposal")] = 60 seconds;
        parameters[projectId][keccak256("RequiredVotingPowerPercentageToCreateTokens")] = 80;
        parameters[projectId][keccak256("VetoMinimumPercentage")] = 30;
        parameters[projectId][keccak256("ExpirationPeriod")] = 5 minutes;
    }

    /**
     * @notice Proposes a change to a parameter's value
     */
    function proposeParameterChange(uint projectId, bytes32 parameterName, uint value) external {
        require(value >= parameterMinValues[parameterName] && value <= parameterMaxValues[parameterName], "Value out of range");
        changeParameterProposals[projectId][proposalContract.nextProposalId(projectId)] = ChangeParameterProposal({
            parameterName: parameterName,
            value: value
        });
        proposalContract.createProposal(projectId, CHANGE_PARAMETER, msg.sender);
    }

    /**
     * @notice Executes a proposal if it has passed all required stages and checks.
     * @dev Once a proposal is executed it is deleted from the state to prevent re-execution.
     * @param projectId The ID of the project for which the proposal is executed.
     * @param proposalId The ID of the proposal to execute.
     * This ID must correspond to an existing, valid, and approved proposal.
     */
    function executeProposal(uint projectId, uint proposalId) external {
        (uint32 typeOfProposal, , bool willExecute,, uint256 endTime) = proposalContract.proposals(projectId, proposalId);
        require(proposalId < proposalContract.nextProposalId(projectId), "Proposal does not exist");
        require(endTime <= block.timestamp, "Buffer time did not end yet");
        require(endTime + parameters[projectId][keccak256("ExpirationPeriod")] >= block.timestamp, "Proposal has expired");
        require(willExecute, "Proposal was rejected or vote count was not locked");
        proposalContract.setWillExecute(projectId, proposalId, false);

        if (typeOfProposal == CHANGE_TRUSTED_ADDRESS) {
            ChangeTrustedAddressProposal memory p = changeTrustedAddressProposals[projectId][proposalId];
            address[] storage ta = trustedAddresses[projectId];
            if (p.trustedAddress != address(0)) {
                if (p.index == ta.length) {
                    ta.push(p.trustedAddress);
                } else {
                    ta[p.index] = p.trustedAddress;
                }
            } else {
                require(ta.length > 0, "No element in trustedAddress array.");
                ta[p.index] = ta[ta.length - 1];
                ta.pop();
            }

            emit ChangeTrustedAddress(projectId, proposalId, p.index, p.trustedAddress);
            proposalContract.deleteProposal(projectId, proposalId);
            delete changeTrustedAddressProposals[projectId][proposalId];
        } else if (typeOfProposal == CHANGE_PARAMETER) {
            parameters[projectId][changeParameterProposals[projectId][proposalId].parameterName] = changeParameterProposals[projectId][proposalId].value;
            delete changeParameterProposals[projectId][proposalId];
        } else {
            revert('Unexpected proposal type');
        }
        proposalContract.deleteProposal(projectId, proposalId);
        emit ExecuteProposal(projectId, proposalId);
    }

    /**
     * @notice We can call this method if our private key gets compromised
     * to remove its privilege of creating proposals on any project and tie breaking for proposals
     */
    function removeGitSwarmAddress() public {
        require(msg.sender == gitswarmAddress);
        gitswarmAddress = address(0);
        emit GitSwarmAddressRemoved(msg.sender);
    }

    /**
     * @notice Returns the amount needed to contest a proposal
     * @dev Utility function to get the veto power requirement for contesting proposals
     */
    function neededToContest(uint projectId) external view returns (uint) {
        return parameters[projectId][keccak256("VetoMinimumPercentage")] * contractsManagerContract.votingTokenCirculatingSupply(projectId) / 100;
    }

    /**
     * @notice Checks if an address is a trusted address for a given project.
     * @param projectId The ID of the project.
     * @param trustedAddress The address to check.
     * @return True if the address is trusted, false otherwise.
     */
    function isTrustedAddress(uint projectId, address trustedAddress) view public returns (bool) {
        if (
            trustedAddress == address(delegatesContract) ||
            trustedAddress == address(fundsManagerContract) ||
            trustedAddress == address(parametersContract) ||
            trustedAddress == address(proposalContract) ||
            trustedAddress == address(gasStationContract) ||
            trustedAddress == address(contractsManagerContract) ||
            trustedAddress == address(contractsManagerContract.votingTokenContracts(projectId))
        ) {
            return true;
        }
        for (uint i = 0; i < trustedAddresses[projectId].length; i++) {
            if (trustedAddresses[projectId][i] == trustedAddress) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Proposes a change to a trusted address for a given project.
     * @dev Validates the contract index and records the proposal for a change in trusted addresses.
     * @param projectId The ID of the project for which the change is proposed.
     * @param index The index of the trusted address to be changed.
     * @param trustedAddress The newly proposed trusted address.
     */
    function proposeChangeTrustedAddress(uint projectId, uint32 index, address trustedAddress) external {
        require(index >= 0 && index <= trustedAddresses[projectId].length, "index out of bounds");
        changeTrustedAddressProposals[projectId][proposalContract.nextProposalId(projectId)] = ChangeTrustedAddressProposal({
            index: index,
            trustedAddress: trustedAddress});
        proposalContract.createProposal(projectId, CHANGE_TRUSTED_ADDRESS, msg.sender);
    }
}
