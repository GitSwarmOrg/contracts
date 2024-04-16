// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;

import "./base/ERC20interface.sol";
import "./base/Common.sol";

contract Proposal is Common, Initializable, IProposal {

    mapping(uint => mapping(uint => ProposalData)) public proposals;
    mapping(uint => uint) public nextProposalId;

    struct Vote {
        bool hasVoted;
        bool votedYes;
    }

    struct ProposalData {
        uint32 typeOfProposal;
        bool votingAllowed;
        bool willExecute;
        uint64 nrOfVoters;
        uint endTime;
        mapping(uint64 => address) voters;
        mapping(address => Vote) votes;
    }

    event NewProposal(uint projectId, uint proposalId, uint32 proposalType);
    event LockVoteCount(uint projectId, uint proposalId, bool willExecute, uint yesVotes, uint noVotes);
    event ExecuteProposal(uint projectId, uint proposalId);
    event VoteOnProposal(uint projectId, uint proposalId, address userAddress, bool vote);
    event ProposalSetActive(uint projectId, uint proposalId, bool value);
    event ProposalSetWillExecute(uint projectId, uint proposalId, bool value);
    event ProposalDeleted(uint projectId, uint proposalId);
    event RemovedSpamVoters(uint projectId, uint proposalId, uint[] indexes);

    function initialize(
        address _delegates,
        address _fundsManager,
        address _parameters,
        address _proposal,
        address _gasStation,
        address _contractsManager
    ) public initializer {
        _init(_delegates, _fundsManager, _parameters, _proposal, _gasStation, _contractsManager);
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

    function vote(uint projectId, uint proposalId, bool choice) public hasMinBalance(projectId, msg.sender) {
        require(proposalId < nextProposalId[projectId] &&
        proposals[projectId][proposalId].votingAllowed,
            "Proposal does not exist or is inactive");
        require(block.timestamp < proposals[projectId][proposalId].endTime,
            "Proposal voting period has ended ");
        internal_vote(projectId, proposalId, choice);
    }

    function internal_vote(uint projectId, uint proposalId, bool choice) public restricted(projectId) {
        ProposalData storage p = proposals[projectId][proposalId];
        if (!hasVotedAlready(projectId, proposalId, msg.sender)) {
            p.voters[p.nrOfVoters++] = msg.sender;
        }
        p.votes[msg.sender] = Vote({hasVoted: true, votedYes: choice});
        emit VoteOnProposal(projectId, proposalId, msg.sender, choice);
    }

    function deleteProposal(uint projectId, uint proposalId) external restricted(projectId) {
        delete proposals[projectId][proposalId];
        emit ProposalDeleted(projectId, proposalId);
    }

    function createProposal(uint projectId, uint32 proposalType, address voterAddress) external restricted(projectId) {
        privateCreateProposal(projectId, proposalType, voterAddress);
    }

    function getSpamVoters(uint projectId, uint proposalId) external view returns (uint[] memory) {
        uint[] memory indexes = new uint[](200);
        uint index = 0;
        uint circulatingSupply = contractsManagerContract.votingTokenCirculatingSupply(projectId);
        for (uint64 i = 0; i < proposals[projectId][proposalId].nrOfVoters; i++) {
            if (!delegatesContract.checkVotingPower(projectId, proposals[projectId][proposalId].voters[i],
                circulatingSupply / parametersContract.parameters(projectId,keccak256("MaxNrOfVoters")))) {
                indexes[index] = i;
                index++;
                if (index == 200) {
                    return indexes;
                }
            }
        }
        return indexes;
    }

    // Removes votes that no longer meet the minimum voting power requirement. This might be necessary for projects with a high MaxNrOfVoters.
    function removeSpamVoters(uint projectId, uint proposalId, uint[] memory indexes) external {
        uint minimum_amount = contractsManagerContract.votingTokenCirculatingSupply(projectId) / parametersContract.parameters(projectId,keccak256("MaxNrOfVoters"));
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
    function privateCreateProposal(uint projectId, uint32 proposalType, address voterAddress) private hasMinBalance(projectId, voterAddress)
    {
        ProposalData storage newProposal = proposals[projectId][nextProposalId[projectId]];

        newProposal.votingAllowed = true;
        newProposal.willExecute = false;
        newProposal.voters[0] = voterAddress;
        newProposal.nrOfVoters = 1;
        newProposal.votes[voterAddress] = Vote({hasVoted: true, votedYes: true});
        newProposal.typeOfProposal = proposalType;
        newProposal.endTime = block.timestamp + parametersContract.parameters(projectId,keccak256("VoteDuration"));

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
            Vote storage choice = proposals[projectId][proposalId].votes[a];
            uint votingPower = calculateTotalVotingPower(projectId, a, proposalId, votingTokenContract);
            if (choice.hasVoted) {
                if (choice.votedYes) {
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
            return (yesVotes, noVotes, p.votes[parametersContract.gitswarmAddress()].votedYes);
        }

        return (yesVotes, noVotes, yesVotes * 100 / (yesVotes + noVotes) >= requiredPercentage);
    }

    function lockVoteCount(uint projectId, uint proposalId) external {
        ProposalData storage p = proposals[projectId][proposalId];
        require(p.endTime <= block.timestamp, "Voting is ongoing");
        require(p.endTime + parametersContract.parameters(0,keccak256("ExpirationPeriod")) >= block.timestamp, "Proposal expired");
        require(proposalId < nextProposalId[projectId] && p.votingAllowed,
            "Proposal does not exist or is inactive");
        uint yesVotes;
        uint noVotes;
        bool willExecute;
        if (p.typeOfProposal == CREATE_TOKENS) {
            (yesVotes, noVotes, willExecute) = checkVoteCount(projectId, proposalId, parametersContract.parameters(projectId,keccak256("RequiredVotingPowerPercentageToCreateTokens")));
        } else {
            (yesVotes, noVotes, willExecute) = checkVoteCount(projectId, proposalId, 50);
        }
        if (!willExecute) {
            delete proposals[projectId][proposalId];
        } else {
            p.willExecute = true;
            p.votingAllowed = false;
            p.endTime = block.timestamp + parametersContract.parameters(projectId,keccak256("BufferBetweenEndOfVotingAndExecuteProposal"));
        }
        emit LockVoteCount(projectId, proposalId, proposals[projectId][proposalId].willExecute, yesVotes, noVotes);
    }

}
