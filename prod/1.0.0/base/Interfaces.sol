// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20interface.sol";

interface IContractsManager {
    function votingTokenContracts(uint projectId) external view returns (ERC20interface);
    function changeTrustedAddressProposals(uint projectId, uint proposalId) external view returns (uint32 contractIndex, address trustedAddress);
    function addBurnAddressProposals(uint projectId, uint proposalId) external view returns (address);
    function nextProjectId() external view returns (uint);
    function deleteExpiredProposals(uint projectId, uint[] memory ids, uint proposalType) external;
    function getBurnAddresses(uint projectId) external view returns (address[] memory);
    function burnedTokens(uint projectId, ERC20interface votingTokenContract) external view returns (uint);
    function votingTokenCirculatingSupply(uint projectId) external view returns (uint);
    function checkMinBalance(uint projectId, address addr) external view returns (bool);
    function minimumRequiredAmount(uint projectId) external view returns (uint);
    function createProject(string memory dbProjectId, address tokenContractAddress) external;
    function isTrustedAddress(uint projectId, address trustedAddress) external view returns (bool);
    function proposeChangeTrustedAddress(uint projectId, uint32 contractIndex, address trustedAddress) external;
    function proposeAddBurnAddress(uint projectId, address burnAddress) external;
    function executeProposal(uint projectId, uint proposalId) external;

    function burnAddresses(uint projectId, uint index) external view returns (address);
    function trustedAddresses(uint projectId, uint index) external view returns (address);
}

interface IDelegates {
    function getDelegates(uint projectId, address delegatedAddress) view external returns (address[] memory);
    function countDelegatedVotes(uint projectId, address delegatedAddr) external view returns (uint);
    function checkVotingPower(uint projectId, address addr, uint minVotingPower) external view returns (bool);
    function delegate(uint projectId, address delegatedAddr) external;
    function undelegate(uint projectId) external;
    function undelegateAllFromAddress(uint projectId) external;
    function removeUnwantedDelegates(uint projectId, address[] memory addresses, uint[] memory indexes) external;
    function getUnwantedDelegates(uint projectId, address delegatedAddr) external view returns (address  [] memory, uint [] memory);
    // Getters for public fields
    function delegates(uint, address, uint) external view returns (address);
    function delegators(uint, address) external view returns (address);
}


interface IFundsManager {
    function sendOrphanTokensToGitSwarm(address tokenAddress) external;
    function deleteExpiredProposals(uint projectId, uint[] memory ids) external;
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
    function deleteExpiredProposals(uint[] memory ids) external;
    function buyGasForProject(uint projectId) payable external;
    function proposeTransferToGasAddress(uint amount, address to) external;
    function executeProposal(uint id) external;
}


interface IProposal {
    function proposals(uint, uint) external view returns (uint32, uint, bool, bool, uint64);
    function changeParameterProposals(uint, uint) external view returns (bytes32, uint);
    function nextProposalId(uint) external view returns (uint);
    function parameters(uint, bytes32) external view returns (uint, uint, uint);
    function initializeParameters(uint) external;
    function deleteExpiredProposals(uint, uint[] memory) external;
    function getVotes(uint, uint, address) external view returns (uint, uint);
    function getVoteAmounts(uint, uint, address) external view returns (uint, uint);
    function setActive(uint, uint, bool) external;
    function setWillExecute(uint, uint, bool) external;
    function hasVotedAlready(uint, uint, address) external view returns (bool);
    function voteProposalId(uint, uint, bool) external;
    function voteWithAmount(uint, uint, uint, uint) external;
    function deleteProposal(uint, uint) external;
    function contestProposal(uint, uint) external;
    function neededToContest(uint) external view returns (uint);
    function getSpamVoters(uint, uint) external view returns (uint[] memory);
    function removeSpamVoters(uint, uint, uint[] memory) external;
    function createProposal(uint, uint32, address) external;
    function countDelegatedVotes(uint, address, uint,  ERC20interface, IDelegates) external view returns (uint);
    function calculateTotalVotingPower(uint, address, uint, ERC20interface, IDelegates) external view returns (uint);
    function getVoteCount(uint, uint) external view returns (uint, uint);
    function checkVoteCount(uint, uint, uint) external view returns (uint, uint, bool);
    function lockVoteCount(uint, uint) external;
    function proposeParameterChange(uint, bytes32, uint) external;
    function executeProposal(uint, uint) external;
}

interface ITokenSell {
    function proposeAuctionTokenSell(uint projectId, address tokenToSell, uint nbOfTokens, uint minimumWei, uint64 auctionStartTime, uint64 auctionEndTime) external;
    function executeProposal(uint projectId, uint proposalId) external;
    function buyAuction(uint projectId, uint proposalId) payable external;
    function withdrawAuction(uint projectId, uint proposalId, uint withdrawAmount) external;
    function setEndTimeAuction(uint projectId, uint proposalId) external;
    function setStartTimeAuction(uint projectId, uint proposalId) external;
    function auctionAmountForBuyer(uint projectId, uint proposalId, address addr) external view returns (uint);
    function claimAuction(uint projectId, uint proposalId) external;
    function massClaimAuction(uint projectId, uint proposalId, address[] memory claimers) external;
    function sendAuctionTokensBack(uint projectId, uint proposalId) external;
}
