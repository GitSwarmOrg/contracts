// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;

import "./base/ERC20interface.sol";
import "./base/Common.sol";

contract Proposal is Common, Initializable, IProposal {

    address public gitswarmAddress;

    mapping(uint => mapping(uint => ProposalData)) public proposals;
    mapping(uint => mapping(uint => ChangeParameterProposal)) public changeParameterProposals;
    mapping(uint => uint) public nextProposalId;

    struct Vote {
        bool hasVoted;
        bool votedYes;
    }

    // New mapping to store just the value of parameters
    mapping(uint => mapping(bytes32 => uint)) public parameters;
    // Additional mappings to store the min and max values for parameters
    mapping(bytes32 => uint) public parameterMinValues;
    mapping(bytes32 => uint) public parameterMaxValues;

    struct ProposalData {
        uint32 typeOfProposal;
        bool votingAllowed;
        bool willExecute;
        uint64 nrOfVoters;
        uint endTime;
        mapping(uint64 => address) voters;
        mapping(address => Vote) votes;
    }

    struct ChangeParameterProposal {
        bytes32 parameterName;
        uint value;
    }

    event NewProposal(uint projectId, uint proposalId, uint32 proposalType);
    event LockVoteCount(uint projectId, uint proposalId, bool willExecute, uint yesVotes, uint noVotes);
    event ExecuteProposal(uint projectId, uint proposalId);
    event VoteOnProposal(uint projectId, uint proposalId, address userAddress, bool vote);
    event ContestedProposal(uint projectId, uint proposalId, uint yesVotes, uint noVotes);
    event ProposalSetActive(uint projectId, uint proposalId, bool value);
    event ProposalSetWillExecute(uint projectId, uint proposalId, bool value);
    event ProposalDeleted(uint projectId, uint proposalId);
    event RemovedSpamVoters(uint projectId, uint proposalId, uint[] indexes);
    event GitSwarmAddressRemoved(address who);

    function initialize(
        address _gitswarmAddress,
        address _delegates,
        address _fundsManager,
        address _tokenSell,
        address _proposal,
        address _gasStation,
        address _contractsManager
    ) public initializer {
        _init(_delegates, _fundsManager, _tokenSell, _proposal, _gasStation, _contractsManager);
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

        // Minimum percentage of the project's token required to make a new proposal is 100/MaxNrOfDelegators
        parameterMinValues[keccak256("MaxNrOfDelegators")] = 10;
        parameterMaxValues[keccak256("MaxNrOfDelegators")] = 10000;

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

        // MaxNrOfDelegators set to 1000 means that a minimum percentage of 0.1% of the circulating supply of tokens
        // is needed to vote on/create a proposal. This helps mitigate the risk of counting votes costing more gas than
        // the block limit
        parameters[projectId][keccak256("MaxNrOfDelegators")] = 1000;
        parameters[projectId][keccak256("BufferBetweenEndOfVotingAndExecuteProposal")] = 60 seconds;
        parameters[projectId][keccak256("RequiredVotingPowerPercentageToCreateTokens")] = 80;
        parameters[projectId][keccak256("VetoMinimumPercentage")] = 30;
        parameters[projectId][keccak256("ExpirationPeriod")] = 5 minutes;
    }

    modifier activeProposal(uint projectId, uint proposalId) {
        require(proposalId < nextProposalId[projectId] &&
        proposals[projectId][proposalId].votingAllowed &&
        block.timestamp < proposals[projectId][proposalId].endTime,
            "Proposal does not exist or is inactive");
        _;
    }

    function setActive(uint projectId, uint proposalId, bool value) external restricted(projectId) {
        proposals[projectId][proposalId].votingAllowed = value;
        emit ProposalSetActive(projectId, proposalId, value);
    }

    function setWillExecute(uint projectId, uint proposalId, bool value) external restricted(projectId) {
        proposals[projectId][proposalId].willExecute = value;
        emit ProposalSetWillExecute(projectId, proposalId, value);
    }

    function hasVotedAlready(uint projectId, uint proposalId, address addr) public view returns (bool) {
        return proposals[projectId][proposalId].votes[addr].hasVoted;
    }

    modifier hasMinBalance (uint projectId, address addr) {
        require(contractsManagerContract.hasMinBalance(projectId, addr),
            "Not enough voting power.");
        _;
    }

    function vote(uint projectId, uint proposalId, bool vote) public activeProposal(projectId, proposalId) hasMinBalance(projectId, msg.sender) {
        internal_vote(projectId, proposalId, vote);
    }

    function internal_vote(uint projectId, uint proposalId, bool vote) internal {
        ProposalData storage p = proposals[projectId][proposalId];
        if (!hasVotedAlready(projectId, proposalId, msg.sender)) {
            p.voters[p.nrOfVoters++] = msg.sender;
        }
        p.votes[msg.sender] = Vote({hasVoted: true, votedYes: vote});
        emit VoteOnProposal(projectId, proposalId, msg.sender, vote);
    }

    function deleteProposal(uint projectId, uint proposalId) external restricted(projectId) {
        delete proposals[projectId][proposalId];
        emit ProposalDeleted(projectId, proposalId);
    }

    function contestProposal(uint projectId, uint proposalId, bool doRecount) external hasMinBalance(projectId, msg.sender) returns (bool) {
        ERC20interface votingTokenContract = contractsManagerContract.votingTokenContracts(projectId);
        ProposalData storage proposal = proposals[projectId][proposalId];
        require(proposal.willExecute, "Can not contest this proposal, it is not in the phase of contesting");
        internal_vote(projectId, proposalId, false);
        uint noVotes;
        uint yesVotes;

        if (!doRecount) {
            return false;
        }

        uint circulatingSupply = contractsManagerContract.votingTokenCirculatingSupply(projectId);
        for (uint64 i = 0; i < proposal.nrOfVoters; i++) {
            address voter = proposal.voters[i];
            Vote storage vote = proposal.votes[voter];
            uint vp = calculateTotalVotingPower(projectId, voter, proposalId, votingTokenContract);
            if (!vote.votedYes) {
                noVotes += vp;
            } else {
                yesVotes += vp;
            }
            if (noVotes * 100 / circulatingSupply >= parameters[projectId][keccak256("VetoMinimumPercentage")]) {
                delete proposals[projectId][proposalId];
                emit ContestedProposal(projectId, proposalId, yesVotes, noVotes);
                return true;
            }
        }
        if (noVotes > yesVotes) {
            delete proposals[projectId][proposalId];
            emit ContestedProposal(projectId, proposalId, yesVotes, noVotes);
            return true;
        }
        return false;
    }

    function neededToContest(uint projectId) external view returns (uint) {
        return parameters[projectId][keccak256("VetoMinimumPercentage")] * contractsManagerContract.votingTokenCirculatingSupply(projectId) / 100;
    }

    function getSpamVoters(uint projectId, uint proposalId) external view returns (uint[] memory) {
        uint[] memory indexes = new uint[](200);
        uint index = 0;
        uint circulatingSupply = contractsManagerContract.votingTokenCirculatingSupply(projectId);
        for (uint64 i = 0; i < proposals[projectId][proposalId].nrOfVoters; i++) {
            if (!delegatesContract.checkVotingPower(projectId, proposals[projectId][proposalId].voters[i],
                circulatingSupply / parameters[projectId][keccak256("MaxNrOfDelegators")])) {
                indexes[index] = i;
                index++;
                if (index == 200) {
                    return indexes;
                }
            }
        }
        return indexes;
    }

    // Removes votes that no longer meet the minimum voting power requirement. This might be necessary for projects with a high MaxNrOfDelegators.
    function removeSpamVoters(uint projectId, uint proposalId, uint[] memory indexes) external {
        uint minimum_amount = contractsManagerContract.votingTokenCirculatingSupply(projectId) / parameters[projectId][keccak256("MaxNrOfDelegators")];
        emit RemovedSpamVoters(projectId, proposalId, indexes);
        for (uint64 index = uint64(indexes.length); index > 0; index--) {
            // avoiding underflow when decrementing, that would have happened for value 0
            uint64 i = uint64(indexes[index - 1]);
            ProposalData storage p = proposals[projectId][proposalId];
            if (!delegatesContract.checkVotingPower(projectId, p.voters[i], minimum_amount)) {
                p.nrOfVoters--;
                delete p.votes[p.voters[i]];
                p.voters[i] = p.voters[p.nrOfVoters];
                delete p.voters[p.nrOfVoters];
            }
        }
    }

    function createProposal(uint projectId, uint32 proposalType, address voterAddress) external restricted(projectId) {
        privateCreateProposal(projectId, proposalType, voterAddress);
    }

    function privateCreateProposal(uint projectId, uint32 proposalType, address voterAddress) private hasMinBalance(projectId, voterAddress)
    {
        ProposalData storage newProposal = proposals[projectId][nextProposalId[projectId]];

        newProposal.votingAllowed = true;
        newProposal.willExecute = false;
        newProposal.voters[0] = voterAddress;
        newProposal.nrOfVoters = 1;
        newProposal.votes[voterAddress] = Vote({hasVoted: true, votedYes: true});
        newProposal.typeOfProposal = proposalType;
        newProposal.endTime = block.timestamp + parameters[projectId][keccak256("VoteDuration")];

        nextProposalId[projectId]++;
        emit NewProposal(projectId, nextProposalId[projectId] - 1, proposalType);
    }

    function getDelegatedVotingPowerExcludingVoters(uint projectId, address delegatedAddr, uint proposalId, ERC20interface tokenContract) public view returns (uint delegatedVotes) {
        address[] memory delegations = delegatesContract.getDelegatorsOf(projectId, delegatedAddr);
        delegatedVotes = 0;
        for (uint i = 0; i < delegations.length; i++) {
            if (delegations[i] != address(0) && !hasVotedAlready(projectId, proposalId, delegations[i])) {
                delegatedVotes += tokenContract.balanceOf(delegations[i]);
            }
        }
    }

    function calculateTotalVotingPower(uint projectId, address addr, uint id, ERC20interface tokenContract) view public returns (uint) {
        return tokenContract.balanceOf(addr) + getDelegatedVotingPowerExcludingVoters(projectId, addr, id, tokenContract);
    }

    function getVotes(uint projectId, uint proposalId, address a) public view returns (bool, bool) {
        Vote storage v = proposals[projectId][proposalId].votes[a];
        return (v.hasVoted, v.votedYes);
    }

    function getVoteCount(uint projectId, uint proposalId) public view returns (uint, uint) {
        ERC20interface votingTokenContract = contractsManagerContract.votingTokenContracts(projectId);
        uint yesVotes;
        uint noVotes;
        for (uint64 i = 0; i < proposals[projectId][proposalId].nrOfVoters; i++) {
            address a = proposals[projectId][proposalId].voters[i];
            Vote storage vote = proposals[projectId][proposalId].votes[a];
            uint votingPower = calculateTotalVotingPower(projectId, a, proposalId, votingTokenContract);
            if (vote.hasVoted) {
                if (vote.votedYes) {
                    yesVotes += votingPower;
                } else {
                    noVotes += votingPower;
                }
            }
        }

        return (yesVotes, noVotes);
    }

    function checkVoteCount(uint projectId, uint proposalId, uint requiredPercentage) public view returns (uint, uint, bool) {
        (uint yesVotes, uint noVotes) = getVoteCount(projectId, proposalId);
        ProposalData storage p = proposals[projectId][proposalId];

        if (yesVotes == noVotes) {
            //use gitswarmAddress as tie-breaker when yes votes == no votes
            return (yesVotes, noVotes, p.votes[gitswarmAddress].votedYes);
        }

        return (yesVotes, noVotes, yesVotes * 100 / (yesVotes + noVotes) >= requiredPercentage);
    }

    function lockVoteCount(uint projectId, uint proposalId) external {
        ProposalData storage p = proposals[projectId][proposalId];
        require(p.endTime <= block.timestamp, "Voting is ongoing");
        require(p.endTime + parameters[0][keccak256("ExpirationPeriod")] >= block.timestamp, "Proposal expired");
        // instead of activeProposal modifier
        require(proposalId < nextProposalId[projectId] && p.votingAllowed,
            "Proposal does not exist or is inactive");
        uint yesVotes;
        uint noVotes;
        bool willExecute;
        if (p.typeOfProposal == CREATE_TOKENS) {
            (yesVotes, noVotes, willExecute) = checkVoteCount(projectId, proposalId, parameters[projectId][keccak256("RequiredVotingPowerPercentageToCreateTokens")]);
        } else {
            (yesVotes, noVotes, willExecute) = checkVoteCount(projectId, proposalId, 50);
        }
        if (!willExecute) {
            delete proposals[projectId][proposalId];
        } else {
            p.willExecute = true;
            p.votingAllowed = false;
            p.endTime = block.timestamp + parameters[projectId][keccak256("BufferBetweenEndOfVotingAndExecuteProposal")];
        }
        emit LockVoteCount(projectId, proposalId, proposals[projectId][proposalId].willExecute, yesVotes, noVotes);
    }

    function proposeParameterChange(uint projectId, bytes32 parameterName, uint value) external {
        require(value >= parameterMinValues[parameterName] && value <= parameterMaxValues[parameterName], "Value out of range");


        changeParameterProposals[projectId][nextProposalId[projectId]] = ChangeParameterProposal({
            parameterName: parameterName,
            value: value
        });
        privateCreateProposal(projectId, CHANGE_PARAMETER, msg.sender);
    }

    function executeProposal(uint projectId, uint proposalId) external {
        ProposalData storage p = proposals[projectId][proposalId];
        require(proposalId < nextProposalId[projectId], "Proposal does not exist");
        require(p.endTime <= block.timestamp, "Buffer time did not end yet");
        require(p.endTime + parameters[0][keccak256("ExpirationPeriod")] >= block.timestamp, "Proposal has expired");
        require(p.willExecute, "Proposal was rejected or vote count was not locked");
        proposals[projectId][proposalId].willExecute = false;

        if (p.typeOfProposal == CHANGE_PARAMETER) {
            parameters[projectId][changeParameterProposals[projectId][proposalId].parameterName] = changeParameterProposals[projectId][proposalId].value;
            delete changeParameterProposals[projectId][proposalId];
        } else {
            revert('Unexpected proposal type');
        }
        delete proposals[projectId][proposalId];
        emit ExecuteProposal(projectId, proposalId);
    }

    function removeGitSwarmAddress() public {
        require(msg.sender == gitswarmAddress);
        gitswarmAddress = address(0);
        emit GitSwarmAddressRemoved(msg.sender);
    }
}
