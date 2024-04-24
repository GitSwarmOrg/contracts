// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;

import "./base/ERC20interface.sol";
import "./base/Common.sol";

/**
 * @title The proposal management contract for GitSwarm
 * @notice GitSwarm Proposal Flow Documentation
 * The proposal flow in the GitSwarm system involves several key phases:
 * creation, voting, contesting (optional), and execution.
 * Token holders with sufficient governance tokens can influence the direction of the project
 * by participating in this process.
 *
 * 1. **Voting Period**: Once a proposal is created, it enters the voting period.
 * Token holders vote on the proposal using the `vote` method.
 * Votes are recorded, and the number of yes/no votes is tallied. This method ensures
 * that only active proposals are voted on (`activeProposal` modifier)
 * and that voters meet the minimum balance requirement (`hasMinBalance` modifier).
 *
 * 2. **Contesting Period**: After the voting period, there is a contesting period for proposals.
 * Proposals can be contested with the `contestProposal` method.
 * This method allows for a recount and possible invalidation if one of these conditions is met
 * - there are more no votes than yes votes or
 * - the VetoMinimumPercentage (percentage of circulating supply) has been met
 *
 * 3. **Execution Period**: Proposals that successfully pass the contesting phase move to the execution period,
 * which begins when `VoteDuration` seconds pass after `lockVoteCount` was called.
 * The `executeProposal` method can now be called until `ExpirationPeriod` seconds pass, after which the proposal
 * is expired and can no longer be executed.
 *
 * Key Methods:
 * - `createProposal(uint projectId, uint32 proposalType, address voterAddress)`: Initiates a new proposal.
 * - `vote(uint projectId, uint proposalId, bool choice)`: Records a vote for a proposal.
 * - `lockVoteCount(uint projectId, uint proposalId)`: Locks the vote count and starts the contesting period.
 * - `contestProposal(uint projectId, uint proposalId, bool doRecount)`: Can be used to contest
 * during the contesting period.
 * - `executeProposal(uint projectId, uint proposalId)`: Executes the changes proposed if approved
 * and the contesting period has passed.
 */
contract Proposal is Common, Initializable, IProposal {

    /**
     * @notice Stores proposal data for each project
     * @dev Nested mapping of project ID to proposal ID to ProposalData
     */
    mapping(uint => mapping(uint => ProposalData)) public proposals;

    /**
     * @notice Tracks the next proposal ID for each project
     * @dev Mapping of project ID to the next proposal ID
     */
    mapping(uint => uint) public nextProposalId;

    /**
     * @notice Struct for holding vote data
     * @dev Contains information if the voter has voted and their choice
     */
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

    // Events
    /**
     * @notice Emitted when a new proposal is created.
     * @param projectId The ID of the project for which the proposal is made.
     * @param proposalId The unique ID of the new proposal.
     * @param proposalType The type of the proposal.
     */
    event NewProposal(uint projectId, uint proposalId, uint32 proposalType);

    /**
     * @notice Emitted when the vote count for a proposal is locked and its execution decision is finalized.
     * @param projectId The ID of the project for which the proposal is made.
     * @param proposalId The ID of the proposal being locked.
     * @param willExecute Whether the proposal has been approved to execute.
     * @param yesVotes The total number of yes votes the proposal received.
     * @param noVotes The total number of no votes the proposal received.
     */
    event LockVoteCount(uint projectId, uint proposalId, bool willExecute, uint yesVotes, uint noVotes);

    /**
     * @notice Emitted when a proposal is executed.
     * @param projectId The ID of the project for which the proposal is made.
     * @param proposalId The ID of the proposal being executed.
     */
    event ExecuteProposal(uint projectId, uint proposalId);

    /**
     * @notice Emitted when a vote is cast on a proposal.
     * @param projectId The ID of the project for which the proposal is made.
     * @param proposalId The ID of the proposal being voted on.
     * @param userAddress The address of the voter.
     * @param vote The vote cast by the voter.
     */
    event VoteOnProposal(uint projectId, uint proposalId, address userAddress, bool vote);

    /**
     * @notice Emitted when a proposal's active state is changed.
     * @param projectId The ID of the project for which the proposal is made.
     * @param proposalId The ID of the proposal being modified.
     * @param value The new active state of the proposal.
     */
    event ProposalSetActive(uint projectId, uint proposalId, bool value);

    /**
     * @notice Emitted when a proposal's willExecute state is set.
     * @param projectId The ID of the project for which the proposal is made.
     * @param proposalId The ID of the proposal being modified.
     * @param value The new willExecute state of the proposal.
     */
    event ProposalSetWillExecute(uint projectId, uint proposalId, bool value);

    /**
     * @notice Emitted when a proposal is deleted.
     * @param projectId The ID of the project for which the proposal is made.
     * @param proposalId The ID of the proposal being deleted.
     */
    event ProposalDeleted(uint projectId, uint proposalId);

    /**
     * @notice Emitted when votes deemed as spam are removed from a proposal.
     * @param projectId The ID of the project for which the proposal is made.
     * @param proposalId The ID of the proposal from which spam voters are removed
     * @
     * @param indexes The indexes of the voters removed from the proposal's voter list.
     */
    event RemovedSpamVoters(uint projectId, uint proposalId, uint[] indexes);

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
        address _delegates,
        address _fundsManager,
        address _parameters,
        address _proposal,
        address _gasStation,
        address _contractsManager
    ) public initializer {
        _init(_delegates, _fundsManager, _parameters, _proposal, _gasStation, _contractsManager);
    }

    /**
     * @notice Sets a proposal's active state
     * @dev Allows to activate or deactivate a proposal
     */
    function setActive(uint projectId, uint proposalId, bool value) external restricted(projectId) {
        proposals[projectId][proposalId].votingAllowed = value;
        emit ProposalSetActive(projectId, proposalId, value);
    }

    /**
     * @notice Sets a proposal's willExecute state
     * @dev Allows setting whether a proposal will be executed or not
    */
    function setWillExecute(uint projectId, uint proposalId, bool value) external restricted(projectId) {
        proposals[projectId][proposalId].willExecute = value;
        emit ProposalSetWillExecute(projectId, proposalId, value);
    }

    /**
     * @notice Checks if an address has already voted on a proposal
     * @dev Utility function for checking vote status
    */
    function hasVotedAlready(uint projectId, uint proposalId, address addr) public view returns (bool) {
        return proposals[projectId][proposalId].votes[addr].hasVoted;
    }

    /**
     * @notice Modifier to check if the caller has the minimum balance to vote
     * @dev Ensures the caller has enough tokens to participate in voting
    */
    modifier hasMinBalance (uint projectId, address addr) {
        require(contractsManagerContract.hasMinBalance(projectId, addr),
            "Not enough voting power.");
        _;
    }

    /**
     * @notice Allows voting on a proposal
     * @dev Records a vote on a proposal by an eligible voter
     */
    function vote(uint projectId, uint proposalId, bool choice) public hasMinBalance(projectId, msg.sender) {
        require(proposalId < nextProposalId[projectId] &&
        proposals[projectId][proposalId].votingAllowed,
            "Proposal does not exist or is inactive");
        require(block.timestamp < proposals[projectId][proposalId].endTime,
            "Proposal voting period has ended");
        internal_vote(projectId, proposalId, choice);
    }

    function internal_vote(uint projectId, uint proposalId, bool choice) internal {
        ProposalData storage p = proposals[projectId][proposalId];
        if (!hasVotedAlready(projectId, proposalId, msg.sender)) {
            p.voters[p.nrOfVoters++] = msg.sender;
        }
        p.votes[msg.sender] = Vote({hasVoted: true, votedYes: choice});
        emit VoteOnProposal(projectId, proposalId, msg.sender, choice);
    }

    /**
     * @notice Contests a proposal if certain conditions are met:
     * - there are more no votes than yes votes or
     * - the VetoMinimumPercentage (percentage of circulating supply) has been met
     * @dev Allows a proposal to be contested and possibly invalidated
     */
    function contestProposal(uint projectId, uint proposalId, bool doRecount) external returns (bool) {
        require(contractsManagerContract.hasMinBalance(projectId, msg.sender),
            "Not enough voting power.");
        ProposalData storage proposal = proposals[projectId][proposalId];
        require(proposal.willExecute, "Can not contest this proposal, it is not in the phase of contesting");
        internal_vote(projectId, proposalId, false);

        if (!doRecount) {
            return false;
        }

        return processContest(projectId, proposalId);
    }

    function processContest(uint projectId, uint proposalId) internal returns (bool) {
        (uint yesVotes, uint noVotes) = getVoteCount(projectId, proposalId);
        if (noVotes >= parametersContract.neededToContest(projectId)) {
            delete proposals[projectId][proposalId];
            emit ContestedProposal(projectId, proposalId, yesVotes, noVotes);
            return true;
        }

        if (noVotes > yesVotes) {
            delete proposals[projectId][proposalId];
            emit ContestedProposal(projectId, proposalId, yesVotes, noVotes);
            return true;
        }
        return false;
    }

    /**
     * @notice Deletes a proposal
     * @dev Allows removal of a proposal from the system
     */
    function deleteProposal(uint projectId, uint proposalId) external restricted(projectId) {
        delete proposals[projectId][proposalId];
        emit ProposalDeleted(projectId, proposalId);
    }

    /**
     * @notice Creates a new proposal
     * @dev Internal function to initialize a proposal
     */
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
        newProposal.endTime = block.timestamp + parametersContract.parameters(projectId, keccak256("VoteDuration"));

        nextProposalId[projectId]++;
        emit NewProposal(projectId, nextProposalId[projectId] - 1, proposalType);
    }

    /**
     * @notice Identifies spam voters in a proposal
     * @dev Returns a list of voters who no longer meet the minimum voting power requirement
     */
    function getSpamVoters(uint projectId, uint proposalId) external view returns (uint[] memory) {
        uint minimum_amount = contractsManagerContract.votingTokenCirculatingSupply(projectId) /
                            parametersContract.parameters(projectId, keccak256("MaxNrOfVoters"));
        ProposalData storage p = proposals[projectId][proposalId];
        uint[] memory indexes = new uint[](p.nrOfVoters);
        uint index = 0;

        for (uint64 i = 0; i < p.nrOfVoters; i++) {
            if (!delegatesContract.checkVotingPower(projectId, p.voters[i], minimum_amount)) {
                indexes[index] = i;
                index++;
            }
        }

        // Resize the array to the actual number of valid indexes found
        assembly {
            mstore(indexes, index)
        }

        return indexes;
    }

    /**
     * @notice Removes votes from voters who no longer meet the minimum voting power requirement.
     * This can be necessary for projects with a high MaxNrOfVoters.
     * @dev Helps maintain integrity by removing spam or irrelevant votes
     */
    function removeSpamVoters(uint projectId, uint proposalId, uint[] memory indexes) external {
        uint minimum_amount = contractsManagerContract.votingTokenCirculatingSupply(projectId) / parametersContract.parameters(projectId, keccak256("MaxNrOfVoters"));
        emit RemovedSpamVoters(projectId, proposalId, indexes);
        ProposalData storage p = proposals[projectId][proposalId];
        for (uint64 index = uint64(indexes.length); index > 0; index--) {
            // avoiding underflow when decrementing, that would have happened for value 0
            uint64 i = uint64(indexes[index - 1]);
            require(i < p.nrOfVoters, "Index out of bounds");
            if (!delegatesContract.checkVotingPower(projectId, p.voters[i], minimum_amount)) {
                p.nrOfVoters--;
                delete p.votes[p.voters[i]];
                p.voters[i] = p.voters[p.nrOfVoters];
                delete p.voters[p.nrOfVoters];
            }
        }
    }

    /**
     * @notice Calculates the delegated voting power excluding voters who have already voted
     * @dev Utility function to calculate total voting power for a delegate
     */
    function getDelegatedVotingPowerExcludingVoters(uint projectId, address delegatedAddr, uint proposalId, ERC20interface tokenContract) public view returns (uint delegatedVotes) {
        address[] memory delegations = delegatesContract.getDelegatorsOf(projectId, delegatedAddr);
        delegatedVotes = 0;
        for (uint i = 0; i < delegations.length; i++) {
            if (delegations[i] != address(0) && !hasVotedAlready(projectId, proposalId, delegations[i])) {
                delegatedVotes += tokenContract.balanceOf(delegations[i]);
            }
        }
    }

    /**
     * @notice Calculates the total voting power of an address for a proposal
     * @dev Sums the balance of tokens and delegated tokens, excluding delegators who have already voted
     */
    function calculateTotalVotingPower(uint projectId, address addr, uint id, ERC20interface tokenContract) view public returns (uint) {
        return tokenContract.balanceOf(addr) + getDelegatedVotingPowerExcludingVoters(projectId, addr, id, tokenContract);
    }

    /**
     * @notice Retrieves the vote status and choice for an address on a proposal
     * @dev Utility function to check if an address has voted and their choice
     */
    function getVotes(uint projectId, uint proposalId, address a) public view returns (bool, bool) {
        Vote storage v = proposals[projectId][proposalId].votes[a];
        return (v.hasVoted, v.votedYes);
    }

    /**
     * @notice Counts the yes and no votes for a proposal
     * @dev Aggregates the voting power of yes and no votes
     */
    function getVoteCount(uint projectId, uint proposalId) public view returns (uint, uint) {
        ERC20interface votingTokenContract = contractsManagerContract.votingTokenContracts(projectId);
        uint yesVotes;
        uint noVotes;
        for (uint64 i = 0; i < proposals[projectId][proposalId].nrOfVoters; i++) {
            address a = proposals[projectId][proposalId].voters[i];
            Vote storage choice = proposals[projectId][proposalId].votes[a];
            uint votingPower = calculateTotalVotingPower(projectId, a, proposalId, votingTokenContract);
            if (choice.votedYes) {
                yesVotes += votingPower;
            } else {
                noVotes += votingPower;
            }
        }

        return (yesVotes, noVotes);
    }

    /**
     * @notice Checks if the vote count meets the required percentage for a proposal to pass
     * @dev Compares the yes vote count against a required threshold
     */
    function checkVoteCount(uint projectId, uint proposalId, uint requiredPercentage) public view returns (uint, uint, bool) {
        (uint yesVotes, uint noVotes) = getVoteCount(projectId, proposalId);
        ProposalData storage p = proposals[projectId][proposalId];

        if (yesVotes == noVotes) {
            //use gitswarmAddress as tie-breaker when yes votes == no votes
            return (yesVotes, noVotes, p.votes[parametersContract.gitswarmAddress()].votedYes);
        }

        return (yesVotes, noVotes, yesVotes * 10000 / (yesVotes + noVotes) >= requiredPercentage * 100);
    }

    /**
     * @notice Locks the vote count for a proposal and starts the contesting phase or deletes it if it did not pass
     */
    function lockVoteCount(uint projectId, uint proposalId) external {
        ProposalData storage p = proposals[projectId][proposalId];
        require(p.endTime <= block.timestamp, "Voting is ongoing");
        require(proposalId < nextProposalId[projectId] && p.votingAllowed,
            "Proposal does not exist or is inactive");
        require(p.endTime + parametersContract.parameters(projectId, keccak256("ExpirationPeriod")) >= block.timestamp, "Proposal expired");
        uint yesVotes;
        uint noVotes;
        bool willExecute;
        if (p.typeOfProposal == CREATE_TOKENS) {
            (yesVotes, noVotes, willExecute) = checkVoteCount(projectId, proposalId, parametersContract.parameters(projectId, keccak256("RequiredVotingPowerPercentageToCreateTokens")));
        } else {
            (yesVotes, noVotes, willExecute) = checkVoteCount(projectId, proposalId, 50);
        }
        if (!willExecute) {
            delete proposals[projectId][proposalId];
        } else {
            p.willExecute = true;
            p.votingAllowed = false;
            p.endTime = block.timestamp + parametersContract.parameters(projectId, keccak256("BufferBetweenEndOfVotingAndExecuteProposal"));
        }
        emit LockVoteCount(projectId, proposalId, proposals[projectId][proposalId].willExecute, yesVotes, noVotes);
    }

}
