// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;

import "./base/Common.sol";

contract Parameters is Common, Initializable, IParameters {

    address public gitswarmAddress;
    mapping(uint => mapping(uint => ChangeParameterProposal)) public changeParameterProposals;

    mapping(uint => mapping(bytes32 => uint)) public parameters;
    mapping(bytes32 => uint) public parameterMinValues;
    mapping(bytes32 => uint) public parameterMaxValues;

    // Trusted addresses per project, may include other contracts or external addresses.
    // They can call any restricted methods and enables them to send funds without proposals:
    mapping(uint => address[]) public trustedAddresses;
    mapping(uint => mapping(uint => ChangeTrustedAddressProposal)) public changeTrustedAddressProposals;

    struct ChangeParameterProposal {
        bytes32 parameterName;
        uint value;
    }

    struct ChangeTrustedAddressProposal {
        uint32 contractIndex;
        address trustedAddress;
    }

    event ChangeTrustedAddress(uint projectId, uint proposalId, uint32 contractIndex, address trustedAddress);
    event ExecuteProposal(uint projectId, uint proposalId);
    event GitSwarmAddressRemoved(address who);
    event ContestedProposal(uint projectId, uint proposalId, uint yesVotes, uint noVotes);


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

    function proposeParameterChange(uint projectId, bytes32 parameterName, uint value) external {
        require(value >= parameterMinValues[parameterName] && value <= parameterMaxValues[parameterName], "Value out of range");
        changeParameterProposals[projectId][proposalContract.nextProposalId(projectId)] = ChangeParameterProposal({
            parameterName: parameterName,
            value: value
        });
        proposalContract.createProposal(projectId, CHANGE_PARAMETER, msg.sender);
    }

    function executeProposal(uint projectId, uint proposalId) external {
        (uint32 typeOfProposal, , bool willExecute,, uint256 endTime) = proposalContract.proposals(projectId, proposalId);
        require(proposalId < proposalContract.nextProposalId(projectId), "Proposal does not exist");
        require(endTime <= block.timestamp, "Buffer time did not end yet");
        require(endTime + parameters[0][keccak256("ExpirationPeriod")] >= block.timestamp, "Proposal has expired");
        require(willExecute, "Proposal was rejected or vote count was not locked");
        proposalContract.setWillExecute(projectId, proposalId, false);

        if (typeOfProposal == CHANGE_TRUSTED_ADDRESS) {
            ChangeTrustedAddressProposal memory p = changeTrustedAddressProposals[projectId][proposalId];
            address[] storage ta = trustedAddresses[projectId];
            if (p.trustedAddress != address(0)) {
                if (p.contractIndex == ta.length) {
                    ta.push(p.trustedAddress);
                } else {
                    ta[p.contractIndex] = p.trustedAddress;
                }
            } else {
                require(ta.length > 0, "No element in trustedAddress array.");
                ta[p.contractIndex] = ta[ta.length - 1];
                ta.pop();
            }

            emit ChangeTrustedAddress(projectId, proposalId, p.contractIndex, p.trustedAddress);
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

    function removeGitSwarmAddress() public {
        require(msg.sender == gitswarmAddress);
        gitswarmAddress = address(0);
        emit GitSwarmAddressRemoved(msg.sender);
    }

    function neededToContest(uint projectId) external view returns (uint) {
        return parameters[projectId][keccak256("VetoMinimumPercentage")] * contractsManagerContract.votingTokenCirculatingSupply(projectId) / 100;
    }

    function contestProposal(uint projectId, uint proposalId, bool doRecount) external returns (bool) {
        require(contractsManagerContract.hasMinBalance(projectId, msg.sender),
            "Not enough voting power.");
        ERC20interface votingTokenContract = contractsManagerContract.votingTokenContracts(projectId);
        (uint32 typeOfProposal, , bool willExecute,, uint256 endTime) = proposalContract.proposals(projectId, proposalId);
        require(willExecute, "Can not contest this proposal, it is not in the phase of contesting");
        proposalContract.internal_vote(projectId, proposalId, false);

        if (!doRecount) {
            return false;
        }

        bool isContested = processContest(projectId, proposalId, votingTokenContract);
        return isContested;
    }

    function processContest(uint projectId, uint proposalId, ERC20interface votingTokenContract) internal returns (bool) {
        (uint32 typeOfProposal, , bool willExecute,uint64 nrOfVoters, uint256 endTime) = proposalContract.proposals(projectId, proposalId);
        uint circulatingSupply = contractsManagerContract.votingTokenCirculatingSupply(projectId);

        (uint yesVotes, uint noVotes) = proposalContract.getVoteCount(projectId, proposalId);

        if (noVotes * 100 / circulatingSupply >= parameters[projectId][keccak256("VetoMinimumPercentage")]) {
            proposalContract.deleteProposal(projectId, proposalId);
            emit ContestedProposal(projectId, proposalId, yesVotes, noVotes);
            return true;
        }

        if (noVotes > yesVotes) {
            proposalContract.deleteProposal(projectId, proposalId);
            emit ContestedProposal(projectId, proposalId, yesVotes, noVotes);
            return true;
        }
        return false;
    }

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

    function proposeChangeTrustedAddress(uint projectId, uint32 contractIndex, address trustedAddress) external {
        require(contractIndex >= 0 && contractIndex <= trustedAddresses[projectId].length, "contractIndex out of bounds");
        changeTrustedAddressProposals[projectId][proposalContract.nextProposalId(projectId)] = ChangeTrustedAddressProposal({
            contractIndex: contractIndex,
            trustedAddress: trustedAddress});
        proposalContract.createProposal(projectId, CHANGE_TRUSTED_ADDRESS, msg.sender);
    }
}
