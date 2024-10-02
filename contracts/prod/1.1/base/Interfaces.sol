// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IContractsManager {
    function votingTokenContracts(uint256 projectId) external view returns (IERC20);
    function addBurnAddressProposals(uint256 projectId, uint256 proposalId) external view returns (address);
    function nextProjectId() external view returns (uint256);
    function getBurnAddresses(uint256 projectId) external view returns (address[] memory);
    function burnedTokens(uint256 projectId, IERC20 votingTokenContract) external view returns (uint256);
    function votingTokenCirculatingSupply(uint256 projectId) external view returns (uint256);
    function createProject(string memory dbProjectId, address tokenContractAddress) external;
    function createProject(string memory dbProjectId, address tokenContractAddress, bool checkErc20) external;
    function proposeAddBurnAddress(uint256 projectId, address burnAddress) external;
    function executeProposal(uint256 projectId, uint256 proposalId) external;
    function hasMinBalance(uint256 projectId, address addr) external view returns (bool);
    function minimumRequiredAmount(uint256 projectId) external view returns (uint256);

    function burnAddresses(uint256 projectId, uint256 index) external view returns (address);
}

interface IDelegates {
    function getDelegatorsOf(uint256 projectId, address delegatedAddress) view external returns (address[] memory);
    function getDelegatedVotingPower(uint256 projectId, address delegatedAddr) external view returns (uint256);
    function checkVotingPower(uint256 projectId, address addr, uint256 minVotingPower) external view returns (bool);
    function delegate(uint256 projectId, address delegatedAddr) external;
    function undelegate(uint256 projectId) external;
    function undelegateAllFromAddress(uint256 projectId) external;
    function removeSpamDelegates (uint256 projectId, address[] memory addresses, uint256[] memory indexes) external;
    function getSpamDelegates(uint256 projectId, address delegatedAddr) external view returns (address  [] memory, uint256 [] memory);

    // Getters for public fields
    function delegations(uint256, address, uint256) external view returns (address);
    function delegateOf(uint256, address) external view returns (address);
}


interface IFundsManager {
    function sendOrphanTokensToGitSwarm(address tokenAddress) external;
    function depositEth(uint256 projectId) external payable;
    function depositToken(uint256 projectId, address tokenAddress, uint256 amount) external;
    function transactionProposal(uint256 projectId, uint256 proposalId) external view returns (address[] memory token, uint256[] memory amount, address[] memory to, uint256[] memory depositToProjectId);
    function proposeTransaction(uint256 projectId, address[] memory tokenContractAddress, uint256[] memory amount, address[] memory to, uint256[] memory depositToProjectId) external;
    function executeProposal(uint256 projectId, uint256 proposalId) external;
    function reclaimFunds(uint256 projectId, uint256 votingTokenAmount, address[] memory tokenContractsAddresses) external;
    function sendToken(uint256 projectId, address tokenAddress, address receiver, uint256 amount) external;
    function sendEther(uint256 projectId, address payable receiver, uint256 amount) external;
    function balances(uint256 projectId, address tokenAddress) external view returns (uint256);
}


interface IGasStation {
    function buyGasForProject(uint256 projectId) payable external;
    function proposeTransferToGasAddress(uint256 amount, address to) external;
    function executeProposal(uint256 id) external;
}


interface IProposal {
    function proposals(uint256, uint256) external view returns (uint32, bool, bool, uint64, uint256);
    function nextProposalId(uint256) external view returns (uint256);
    function getVotes(uint256, uint256, address) external view returns (bool, bool);
    function setActive(uint256, uint256, bool) external;
    function setWillExecute(uint256, uint256, bool) external;
    function hasVotedAlready(uint256, uint256, address) external view returns (bool);
    function vote(uint256, uint256, bool) external;
    function deleteProposal(uint256, uint256) external;
    function createProposal(uint256, uint32, address) external;
    function checkVoteCount(uint256, uint256, uint256) external view returns (uint256, uint256, bool);
    function lockVoteCount(uint256, uint256) external;
    function getVoteCount(uint256, uint256) external view returns (uint256, uint256);
    function getDelegatedVotingPowerExcludingVoters(uint256, address, uint256,  IERC20) external view returns (uint256);
    function calculateTotalVotingPower(uint256, address, uint256, IERC20) external view returns (uint256);
    function contestProposal(uint256 projectId, uint256 proposalId, bool doRecount) external returns (bool);
}

interface IParameters {
    function changeParameterProposals(uint256, uint256) external view returns (bytes32, uint256);
    function parameters(uint256, bytes32) external view returns (uint256);
    function initializeParameters(uint256) external;
    function neededToContest(uint256) external view returns (uint256);
    function proposeParameterChange(uint256, bytes32, uint256) external;
    function executeProposal(uint256, uint256) external;
    function gitswarmAddress() external view returns (address);
    function isTrustedAddress(uint256 projectId, address trustedAddress) external view returns (bool);
    function proposeChangeTrustedAddress(uint256 projectId, address trustedAddress, bool value) external;
    function trustedAddresses(uint256 projectId, address trustedAddress) external view returns (bool);
    function changeTrustedAddressProposals(uint256 projectId, uint256 proposalId) external view returns (address trustedAddress, bool value);
}
