// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;

import "./base/Common.sol";

/**
 * @title Parameters
 * @notice This contract manages the parameters and trusted addresses for projects.
 * It allows for proposing and executing changes to parameters and trusted addresses.
 */
contract Parameters is Common, Initializable, IParameters {

    /**
     * @notice Has privilege of creating proposals on any project and tie breaking for proposals
     */
    address public gitswarmAddress;

    /**
     * @notice Stores change parameter proposals for each project
     * @dev Nested mapping of project ID to proposal ID to ChangeParameterProposal
     */
    mapping(uint256 => mapping(uint256 => ChangeParameterProposal)) public changeParameterProposals;

    /**
     * @notice New mapping to store just the value of parameters
     * @dev Mapping of project ID to parameter name (hashed) to its value
     */
    mapping(uint256 => mapping(bytes32 => uint256)) public parameters;

    /**
     * @notice Stores the min values for parameters globally
     * @dev Mapping of parameter name (hashed) to its minimum value
     */
    mapping(bytes32 => uint256) public parameterMinValues;

    /**
     * @notice Stores the max values for parameters globally
     * @dev Mapping of parameter name (hashed) to its maximum value
     */
    mapping(bytes32 => uint256) public parameterMaxValues;

    /**
     * @notice Trusted addresses per project, may include other contracts or external addresses.
     * They can call any restricted methods, this enables them to send funds without proposals
     */
    mapping(uint256 => mapping(address => bool)) public trustedAddresses;

    /**
     * @notice Stores proposals for changing trusted addresses
     */
    mapping(uint256 => mapping(uint256 => ChangeTrustedAddressProposal)) public changeTrustedAddressProposals;

    /**
     * @notice Struct for holding change parameter proposal data
     * @dev Contains the parameter name and the proposed value
     */
    struct ChangeParameterProposal {
        bytes32 parameterName;
        uint256 value;
    }

    /**
     * @notice A proposal structure for changing a trusted address.
     */
    struct ChangeTrustedAddressProposal {
        address trustedAddress;
        bool value;
    }

    /**
     * @dev Emitted when a trusted address is changed for a project.
     * @param projectId The ID of the project related to the change.
     * @param proposalId The ID of the proposal that initiated the change.
     * @param trustedAddress The new trusted address.
     * @param value Whether the address should be trusted.
     */
    event ChangeTrustedAddress(uint256 projectId, uint256 proposalId, address trustedAddress, bool value);

    /**
     * @notice Emitted when a proposal is executed.
     * @param projectId The ID of the project for which the proposal is made.
     * @param proposalId The ID of the proposal being executed.
     */
    event ExecuteProposal(uint256 projectId, uint256 proposalId);

    /**
     * @notice Emitted when the GitSwarm address is removed from the system.
     * @param who The address of the GitSwarm being removed.
     */
    event GitSwarmAddressRemoved(address who);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

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
        // Proposal voting duration
        parameterMinValues[keccak256("VoteDuration")] = 1 days;
        parameterMaxValues[keccak256("VoteDuration")] = 30 days;

        // For how long a proposal can be contested after the voting stage
        parameterMinValues[keccak256("BufferBetweenEndOfVotingAndExecuteProposal")] = 1 days;
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
        parameterMinValues[keccak256("ExpirationPeriod")] = 1 days;
        parameterMaxValues[keccak256("ExpirationPeriod")] = 30 days;
    }

    /**
     * @notice Initializes parameters for a project
     * @dev Sets initial values for parameters for a given project
     */
    function initializeParameters(uint256 projectId) external restricted(projectId) {
        internalInitializeParameters(projectId);
    }

    function internalInitializeParameters(uint projectId) internal virtual {
        parameters[projectId][keccak256("VoteDuration")] = 3 days;

        // MaxNrOfVoters set to 1000 means that a minimum percentage of 0.1% of the circulating supply of tokens
        // is needed to vote on/create a proposal. This helps mitigate the risk of counting votes costing more gas than
        // the block limit
        parameters[projectId][keccak256("MaxNrOfVoters")] = 1000;
        parameters[projectId][keccak256("BufferBetweenEndOfVotingAndExecuteProposal")] = 3 days;
        parameters[projectId][keccak256("RequiredVotingPowerPercentageToCreateTokens")] = 80;
        parameters[projectId][keccak256("VetoMinimumPercentage")] = 30;
        parameters[projectId][keccak256("ExpirationPeriod")] = 7 days;
    }

    /**
     * @notice Proposes a change to a parameter's value
     */
    function proposeParameterChange(uint256 projectId, bytes32 parameterName, uint256 value) external {
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
    function executeProposal(uint256 projectId, uint256 proposalId) external {
        (uint32 typeOfProposal, , bool willExecute,, uint256 endTime) = proposalContract.proposals(projectId, proposalId);
        require(proposalId < proposalContract.nextProposalId(projectId), "Proposal does not exist");
        require(endTime <= block.timestamp, "Buffer time did not end yet");
        require(endTime + parameters[projectId][keccak256("ExpirationPeriod")] >= block.timestamp, "Proposal has expired");
        require(willExecute, "Proposal was rejected or vote count was not locked");
        proposalContract.setWillExecute(projectId, proposalId, false);

        if (typeOfProposal == CHANGE_TRUSTED_ADDRESS) {
            ChangeTrustedAddressProposal memory p = changeTrustedAddressProposals[projectId][proposalId];
            mapping(address => bool) storage ta = trustedAddresses[projectId];
            ta[p.trustedAddress] = p.value;

            emit ChangeTrustedAddress(projectId, proposalId, p.trustedAddress, p.value);
            delete changeTrustedAddressProposals[projectId][proposalId];
        } else if (typeOfProposal == CHANGE_PARAMETER) {
            bytes32 paramName = changeParameterProposals[projectId][proposalId].parameterName;
            if (paramName == keccak256("RequiredVotingPowerPercentageToCreateTokens")){
                (,, bool checkVotes) = proposalContract.checkVoteCount(projectId, proposalId, parameters[projectId][paramName]);
                require(checkVotes, "RequiredVotingPowerPercentageToCreateTokens not met");
            }
            parameters[projectId][paramName] = changeParameterProposals[projectId][proposalId].value;
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
    function neededToContest(uint256 projectId) external view returns (uint256) {
        return parameters[projectId][keccak256("VetoMinimumPercentage")] * contractsManagerContract.votingTokenCirculatingSupply(projectId) / 100;
    }

    /**
     * @notice Checks if an address is a trusted address for a given project.
     * @param projectId The ID of the project.
     * @param trustedAddress The address to check.
     * @return True if the address is trusted, false otherwise.
     */
    function isTrustedAddress(uint256 projectId, address trustedAddress) view public returns (bool) {
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
        return trustedAddresses[projectId][trustedAddress];
    }

    /**
     * @notice Proposes a change to a trusted address for a given project.
     * @dev Records the proposal for a change in trusted addresses.
     * @param projectId The ID of the project for which the change is proposed.
     * @param trustedAddress The newly proposed trusted address.
     * @param value Whether the address should be trusted.
     */
    function proposeChangeTrustedAddress(uint256 projectId, address trustedAddress, bool value) external {
        changeTrustedAddressProposals[projectId][proposalContract.nextProposalId(projectId)] = ChangeTrustedAddressProposal({
            trustedAddress: trustedAddress,
            value: value
        });
        proposalContract.createProposal(projectId, CHANGE_TRUSTED_ADDRESS, msg.sender);
    }
}
