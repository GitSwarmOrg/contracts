// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity ^0.8.0;
pragma abicoder v1;

import "./base/ERC20interface.sol";
import "./base/Common.sol";

contract Proposal is Common, Initializable, IProposal {

    uint constant public ALL_TOKENS = 2 ** 256 - 1;

    mapping(uint => mapping(uint => ProposalData)) public proposals;
    mapping(uint => mapping(uint => ChangeParameterProposal)) public changeParameterProposals;
    mapping(uint => uint) public nextProposalId;

    mapping(uint => mapping(bytes32 => Parameter)) public parameters;

    struct Vote {
        uint amountYes;
        uint amountNo;
    }

    struct Parameter {
        uint value;
        uint min;
        uint max;
    }

    struct ProposalData {
        uint32 typeOfProposal;
        uint endTime;
        bool votingAllowed;
        bool willExecute;
        uint64 nrOfVoters;
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
    event VoteOnProposal(uint projectId, uint proposalId, address userAddress);
    event ContestedProposal(uint projectId, uint proposalId);

    function initialize(
        address _delegates,
        address _fundsManager,
        address _tokenSell,
        address _proposal,
        address _gasStation,
        address _contractsManager
    ) public initializer {
        _init(_delegates, _fundsManager, _tokenSell, _proposal, _gasStation, _contractsManager);
        internalInitializeParameters(0);
    }

    function initializeParameters(uint projectId) external restricted(projectId) {
        internalInitializeParameters(projectId);
    }

    function internalInitializeParameters(uint projectId) internal virtual {
        parameters[projectId][keccak256("VoteDuration")].value = 60 seconds;
        parameters[projectId][keccak256("VoteDuration")].min = 60 seconds;
        parameters[projectId][keccak256("VoteDuration")].max = 2592000 seconds; // 30 days
        parameters[projectId][keccak256("MaxNrOfDelegators")].value = 1000;
        parameters[projectId][keccak256("MaxNrOfDelegators")].min = 10;
        parameters[projectId][keccak256("MaxNrOfDelegators")].max = 10000;
        parameters[projectId][keccak256("BufferBetweenEndOfVotingAndExecuteProposal")].value = 60 seconds;
        parameters[projectId][keccak256("BufferBetweenEndOfVotingAndExecuteProposal")].min = 60 seconds;
        parameters[projectId][keccak256("BufferBetweenEndOfVotingAndExecuteProposal")].max = 2592000 seconds;
        parameters[projectId][keccak256("RequiredVotingPowerPercentageToCreateTokens")].value = 80;
        parameters[projectId][keccak256("RequiredVotingPowerPercentageToCreateTokens")].min = 50;
        parameters[projectId][keccak256("RequiredVotingPowerPercentageToCreateTokens")].max = 100;
        parameters[projectId][keccak256("VetoMinimumPercentage")].value = 30;
        parameters[projectId][keccak256("VetoMinimumPercentage")].min = 25;
        parameters[projectId][keccak256("VetoMinimumPercentage")].max = 50;
        parameters[projectId][keccak256("ExpirationPeriod")].value = 5 minutes;
        parameters[projectId][keccak256("ExpirationPeriod")].min = 60 seconds;
        parameters[projectId][keccak256("ExpirationPeriod")].max = 2592000 seconds;
    }

    modifier activeProposal(uint projectId, uint proposalId) {
        require(proposalId < nextProposalId[projectId] && proposals[projectId][proposalId].votingAllowed && block.timestamp < proposals[projectId][proposalId].endTime,
            "Proposal does not exist or is inactive");
        _;
    }

    modifier hasMinBalance (uint projectId, address addr) {
        require(contractsManagerContract.checkMinBalance(projectId, addr),
            "Not enough voting power.");
        _;
    }

    function deleteExpiredProposals(uint projectId, uint[] memory ids) external {
        (uint expirationPeriod,,) = proposalContract.parameters(0, keccak256("ExpirationPeriod"));
        for (uint i = 0; i < ids.length; i++) {
            (,uint256 endTime,,,) = proposalContract.proposals(projectId, ids[i]);
            if (endTime + expirationPeriod <= block.timestamp) {
                delete changeParameterProposals[projectId][ids[i]];
                delete proposals[projectId][ids[i]];
            }
        }
    }

    function getVotes(uint projectId, uint proposalId, address a) public view returns (uint, uint) {
        ERC20interface votingTokenContract = contractsManagerContract.votingTokenContracts(projectId);
        (uint amountYes, uint amountNo) = getVoteAmounts(projectId, proposalId, a);
        if (amountYes == ALL_TOKENS) {
            return (calculateTotalVotingPower(projectId, a, proposalId, votingTokenContract, delegatesContract), 0);
        } else if (amountNo == ALL_TOKENS) {
            return (0, calculateTotalVotingPower(projectId, a, proposalId, votingTokenContract, delegatesContract));
        } else {
            uint actualAmount = calculateTotalVotingPower(projectId, a, proposalId, votingTokenContract, delegatesContract);
            return adjustAmount(actualAmount, amountYes, amountNo);
        }
    }

    function getVoteAmounts(uint projectId, uint proposalId, address a) public view returns (uint, uint) {
        Vote storage vote = proposals[projectId][proposalId].votes[a];
        return (vote.amountYes, vote.amountNo);
    }

    function setActive(uint projectId, uint proposalId, bool value) external restricted(projectId) {
        proposals[projectId][proposalId].votingAllowed = value;
    }

    function setWillExecute(uint projectId, uint proposalId, bool value) external restricted(projectId) {
        proposals[projectId][proposalId].willExecute = value;
    }

    function hasVotedAlready(uint projectId, uint proposalId, address addr) public view returns (bool) {
        if (proposals[projectId][proposalId].votes[addr].amountYes != 0 || proposals[projectId][proposalId].votes[addr].amountNo != 0) {
            return true;
        }
        return false;
    }

    function voteProposalId(uint projectId, uint proposalId, bool vote) external {
        if (vote) {
            voteWithAmount(projectId, proposalId, ALL_TOKENS, 0);
        } else {
            voteWithAmount(projectId, proposalId, 0, ALL_TOKENS);
        }
    }

    function voteWithAmount(uint projectId, uint proposalId, uint amountYes, uint amountNo) activeProposal(projectId, proposalId) hasMinBalance(projectId, msg.sender) public {
        internalVoteWithAmount(projectId, proposalId, amountYes, amountNo);
    }

    function internalVoteWithAmount(uint projectId, uint proposalId, uint amountYes, uint amountNo) internal {
        require(amountYes != 0 || amountNo != 0, "Can't vote with 0 amounts.");
        require(amountYes < 10 ** 40 || amountNo < 10 ** 40, "Amount for vote too big");
        if (!hasVotedAlready(projectId, proposalId, msg.sender)) {
            proposals[projectId][proposalId].voters[proposals[projectId][proposalId].nrOfVoters++] = msg.sender;
        }
        proposals[projectId][proposalId].votes[msg.sender] = Vote({amountYes : amountYes, amountNo : amountNo});
        emit VoteOnProposal(projectId, proposalId, msg.sender);
    }

    function deleteProposal(uint projectId, uint proposalId) external restricted(projectId) {
        delete proposals[projectId][proposalId];
    }

    function contestProposal(uint projectId, uint proposalId) external hasMinBalance(projectId, msg.sender) {
        ERC20interface votingTokenContract = contractsManagerContract.votingTokenContracts(projectId);
        require(proposals[projectId][proposalId].willExecute, "Can not contest this proposal, it is not in the phase of contesting");
        internalVoteWithAmount(projectId, proposalId, 0, ALL_TOKENS);
        uint noVotes;
        for (uint64 i = 0; i < proposals[projectId][proposalId].nrOfVoters; i++) {
            if (proposals[projectId][proposalId].votes[proposals[projectId][proposalId].voters[i]].amountNo == ALL_TOKENS) {
                noVotes += calculateTotalVotingPower(projectId, proposals[projectId][proposalId].voters[i], proposalId, votingTokenContract, delegatesContract);
            } else if (proposals[projectId][proposalId].votes[proposals[projectId][proposalId].voters[i]].amountNo != 0) {
                //case for site address(or vote with amount)
                //adjust the amount for votes if the actual amount is smaller
                uint amountYes = proposals[projectId][proposalId].votes[proposals[projectId][proposalId].voters[i]].amountYes;
                uint amountNo = proposals[projectId][proposalId].votes[proposals[projectId][proposalId].voters[i]].amountNo;
                uint actualAmount = calculateTotalVotingPower(projectId, proposals[projectId][proposalId].voters[i], proposalId, votingTokenContract, delegatesContract);
                if (actualAmount < (amountYes + amountNo)) {
                    (amountYes, amountNo) = adjustAmount(actualAmount, amountYes, amountNo);
                }
                noVotes += amountNo;
            }
            if (noVotes * 100 / contractsManagerContract.votingTokenCirculatingSupply(projectId) >= parameters[projectId][keccak256("VetoMinimumPercentage")].value) {
                delete proposals[projectId][proposalId];
                emit ContestedProposal(projectId, proposalId);
            }
        }
    }

    function neededToContest(uint projectId) external view returns (uint) {
        return parameters[projectId][keccak256("VetoMinimumPercentage")].value * contractsManagerContract.votingTokenCirculatingSupply(projectId) / 100;
    }

    function getSpamVoters(uint projectId, uint proposalId) external view returns (uint[] memory) {
        uint[] memory indexes = new uint[](200);
        uint index = 0;
        for (uint64 i = 0; i < proposals[projectId][proposalId].nrOfVoters; i++) {
            if (!delegatesContract.checkVotingPower(projectId, proposals[projectId][proposalId].voters[i],
                contractsManagerContract.votingTokenCirculatingSupply(projectId) / parameters[projectId][keccak256("MaxNrOfDelegators")].value)) {
                indexes[index] = i;
                index++;
                if (index == 200) {
                    return indexes;
                }
            }
        }
        return indexes;
    }

    function removeSpamVoters(uint projectId, uint proposalId, uint[] memory indexes) external {
        uint minimum_amount = contractsManagerContract.votingTokenCirculatingSupply(projectId) / parameters[projectId][keccak256("MaxNrOfDelegators")].value;
        for (uint64 index = uint64(indexes.length); index > 0; index--) {
            //avoiding underflow when decrementing, that would have happened for value 0
            uint64 i = index - 1;
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

    function privateCreateProposal(uint projectId, uint32 proposalType, address voterAddress) private hasMinBalance(projectId, voterAddress) {
        proposals[projectId][nextProposalId[projectId]].votingAllowed = true;
        proposals[projectId][nextProposalId[projectId]].willExecute = false;
        proposals[projectId][nextProposalId[projectId]].voters[0] = voterAddress;
        proposals[projectId][nextProposalId[projectId]].nrOfVoters = 1;
        proposals[projectId][nextProposalId[projectId]].votes[voterAddress] = Vote({amountYes : ALL_TOKENS, amountNo : 0});
        proposals[projectId][nextProposalId[projectId]].typeOfProposal = proposalType;
        proposals[projectId][nextProposalId[projectId]].endTime = block.timestamp + parameters[projectId][keccak256("VoteDuration")].value;
        nextProposalId[projectId]++;
        emit NewProposal(projectId, nextProposalId[projectId] - 1, proposalType);
    }

    function countDelegatedVotes(uint projectId, address delegatedAddr, uint proposalId, ERC20interface tokenContract, IDelegates delegatesContract) public view returns (uint delegatedVotes) {
        address[] memory delegates = delegatesContract.getDelegates(projectId, delegatedAddr);
        delegatedVotes = 0;
        for (uint i = 0; i < delegates.length; i++) {
            if (delegates[i] != address(0) && !hasVotedAlready(projectId, proposalId, delegates[i])) {
                delegatedVotes += tokenContract.balanceOf(delegates[i]);
                //check second level(actual accounts with tokens)
                address[] memory second_level_delegates = delegatesContract.getDelegates(projectId, delegates[i]);
                for (uint j = 0; j < second_level_delegates.length; j++) {
                    if (second_level_delegates[j] != address(0) && !hasVotedAlready(projectId, proposalId, second_level_delegates[j])) {
                        delegatedVotes += tokenContract.balanceOf(second_level_delegates[j]);
                    }
                }
            }
        }
    }

    function calculateTotalVotingPower(uint projectId, address addr, uint id, ERC20interface tokenContract, IDelegates delegatesContract) view public returns (uint) {
        return tokenContract.balanceOf(addr) + countDelegatedVotes(projectId, addr, id, tokenContract, delegatesContract);
    }

    function adjustAmount(uint actualAmount, uint amountYes, uint amountNo) private pure returns (uint, uint) {
        uint actualAmountYes = 0;
        uint actualAmountNo = 0;
        if (amountYes > 0) {
            actualAmountYes = amountYes * actualAmount / (amountYes + amountNo);
        }
        if (amountNo > 0) {
            actualAmountNo = actualAmount - actualAmountYes;
        }

        return (actualAmountYes, actualAmountNo);
    }

    function getVoteCount(uint projectId, uint proposalId) public view returns (uint, uint) {
        uint yesVotes;
        uint noVotes;
        for (uint64 i = 0; i < proposals[projectId][proposalId].nrOfVoters; i++) {
            (uint amountYes, uint amountNo) = getVotes(projectId, proposalId, proposals[projectId][proposalId].voters[i]);
            yesVotes += amountYes;
            noVotes += amountNo;
        }

        return (yesVotes, noVotes);
    }

    function checkVoteCount(uint projectId, uint proposalId, uint requiredPercentage) public view returns (uint, uint, bool) {
        (uint yesVotes, uint noVotes) = getVoteCount(projectId, proposalId);

        if (yesVotes == noVotes) {
            return (yesVotes, noVotes, false);
        }

        return (yesVotes, noVotes, yesVotes * 100 / (yesVotes + noVotes) >= requiredPercentage);
    }

    function lockVoteCount(uint projectId, uint proposalId) external {
        require(proposals[projectId][proposalId].endTime <= block.timestamp, "Voting is ongoing");
        require(proposals[projectId][proposalId].endTime + parameters[0][keccak256("ExpirationPeriod")].value >= block.timestamp, "Proposal expired");
        // instead of activeProposal modifier
        require(proposalId < nextProposalId[projectId] && proposals[projectId][proposalId].votingAllowed,
            "Proposal does not exist or is inactive");
        uint yesVotes;
        uint noVotes;
        bool willExecute;
        if (proposals[projectId][proposalId].typeOfProposal == CREATE_TOKENS) {
            (yesVotes, noVotes, willExecute) = checkVoteCount(projectId, proposalId, parameters[projectId][keccak256("RequiredVotingPowerPercentageToCreateTokens")].value);
        } else {
            (yesVotes, noVotes, willExecute) = checkVoteCount(projectId, proposalId, 50);
        }
        if (!willExecute) {
            delete proposals[projectId][proposalId];
        } else {
            proposals[projectId][proposalId].willExecute = true;
            proposals[projectId][proposalId].votingAllowed = false;
            proposals[projectId][proposalId].endTime = block.timestamp + parameters[projectId][keccak256("BufferBetweenEndOfVotingAndExecuteProposal")].value;
        }
        emit LockVoteCount(projectId, proposalId, proposals[projectId][proposalId].willExecute, yesVotes, noVotes);
    }

    function proposeParameterChange(uint projectId, bytes32 parameterName, uint value) external {
        require(value >= parameters[projectId][parameterName].min && value <= parameters[projectId][parameterName].max, "Value out of range");
        changeParameterProposals[projectId][nextProposalId[projectId]].parameterName = parameterName;
        changeParameterProposals[projectId][nextProposalId[projectId]].value = value;
        privateCreateProposal(projectId, CHANGE_PARAMETER, msg.sender);
    }

    function executeProposal(uint projectId, uint proposalId) external {
        ProposalData storage p = proposals[projectId][proposalId];
        require(proposalId < nextProposalId[projectId], "Proposal does not exist");
        require(p.endTime <= block.timestamp, "Buffer time did not end yet");
        require(p.endTime + parameters[0][keccak256("ExpirationPeriod")].value >= block.timestamp, "Proposal has expired");
        require(p.willExecute, "Proposal was rejected or vote count was not locked");
        proposals[projectId][proposalId].willExecute = false;

        if (p.typeOfProposal == CHANGE_PARAMETER) {
            parameters[projectId][changeParameterProposals[projectId][proposalId].parameterName].value = changeParameterProposals[projectId][proposalId].value;
            delete changeParameterProposals[projectId][proposalId];
        } else {
            revert('Unexpected proposal type');
        }
        delete proposals[projectId][proposalId];
        emit ExecuteProposal(projectId, proposalId);
    }

}
