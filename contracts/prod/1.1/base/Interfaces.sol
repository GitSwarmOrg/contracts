// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./ERC20interface.sol";

interface IContractsManager {
    function votingTokenContracts(uint projectId) external view returns (ERC20interface);
    function addBurnAddressProposals(uint projectId, uint proposalId) external view returns (address);
    function nextProjectId() external view returns (uint);
    function getBurnAddresses(uint projectId) external view returns (address[] memory);
    function burnedTokens(uint projectId, ERC20interface votingTokenContract) external view returns (uint);
    function votingTokenCirculatingSupply(uint projectId) external view returns (uint);
    function createProject(string memory dbProjectId, address tokenContractAddress) external;
    function createProject(string memory dbProjectId, address tokenContractAddress, bool checkErc20) external;
    function proposeAddBurnAddress(uint projectId, address burnAddress) external;
    function executeProposal(uint projectId, uint proposalId) external;
    function hasMinBalance(uint projectId, address addr) external view returns (bool);
    function minimumRequiredAmount(uint projectId) external view returns (uint);

    function burnAddresses(uint projectId, uint index) external view returns (address);
}

interface IDelegates {
    function getDelegatorsOf(uint projectId, address delegatedAddress) view external returns (address[] memory);
    function getDelegatedVotingPower(uint projectId, address delegatedAddr) external view returns (uint);
    function checkVotingPower(uint projectId, address addr, uint minVotingPower) external view returns (bool);
    function delegate(uint projectId, address delegatedAddr) external;
    function undelegate(uint projectId) external;
    function undelegateAllFromAddress(uint projectId) external;
    function removeSpamDelegates (uint projectId, address[] memory addresses, uint[] memory indexes) external;
    function getSpamDelegates(uint projectId, address delegatedAddr) external view returns (address  [] memory, uint [] memory);

    // Getters for public fields
    function delegations(uint, address, uint) external view returns (address);
    function delegateOf(uint, address) external view returns (address);
}


interface IFundsManager {
    function sendOrphanTokensToGitSwarm(address tokenAddress) external;
    function depositEth(uint projectId) external payable;
    function depositToken(uint projectId, address tokenAddress, uint amount) external;
    function transactionProposal(uint projectId, uint proposalId) external view returns (address[] memory token, uint[] memory amount, address[] memory to, uint[] memory depositToProjectId);
    function proposeTransaction(uint projectId, address[] memory tokenContractAddress, uint[] memory amount, address[] memory to, uint[] memory depositToProjectId) external;
    function executeProposal(uint projectId, uint proposalId) external;
    function reclaimFunds(uint projectId, uint votingTokenAmount, address[] memory tokenContractsAddresses) external;
    function sendToken(uint projectId, address tokenAddress, address receiver, uint amount) external;
    function sendEther(uint projectId, address payable receiver, uint amount) external;
    function updateBalance(uint projectId, address tokenAddress, uint amount) external;
    function balances(uint projectId, address tokenAddress) external view returns (uint);
}


interface IGasStation {
    function buyGasForProject(uint projectId) payable external;
    function proposeTransferToGasAddress(uint amount, address to) external;
    function executeProposal(uint id) external;
}


interface IProposal {
    function proposals(uint, uint) external view returns (uint32, bool, bool, uint64, uint);
    function nextProposalId(uint) external view returns (uint);
    function getVotes(uint, uint, address) external view returns (bool, bool);
    function setActive(uint, uint, bool) external;
    function setWillExecute(uint, uint, bool) external;
    function hasVotedAlready(uint, uint, address) external view returns (bool);
    function vote(uint, uint, bool) external;
    function internal_vote(uint, uint, bool) external;
    function deleteProposal(uint, uint) external;
    function createProposal(uint, uint32, address) external;
    function checkVoteCount(uint, uint, uint) external view returns (uint, uint, bool);
    function lockVoteCount(uint, uint) external;
    function getVoteCount(uint, uint) external view returns (uint, uint);
    function getDelegatedVotingPowerExcludingVoters(uint, address, uint,  ERC20interface) external view returns (uint);
    function calculateTotalVotingPower(uint, address, uint, ERC20interface) external view returns (uint);
}

interface IParameters {
    function changeParameterProposals(uint, uint) external view returns (bytes32, uint);
    function parameters(uint, bytes32) external view returns (uint);
    function initializeParameters(uint) external;
    function neededToContest(uint) external view returns (uint);
    function contestProposal(uint projectId, uint proposalId, bool doRecount) external returns (bool);
    function proposeParameterChange(uint, bytes32, uint) external;
    function executeProposal(uint, uint) external;
    function gitswarmAddress() external view returns (address);
    function isTrustedAddress(uint projectId, address trustedAddress) external view returns (bool);
    function proposeChangeTrustedAddress(uint projectId, uint32 contractIndex, address trustedAddress) external;
    function trustedAddresses(uint projectId, uint index) external view returns (address);
    function changeTrustedAddressProposals(uint projectId, uint proposalId) external view returns (uint32 contractIndex, address trustedAddress);
}
