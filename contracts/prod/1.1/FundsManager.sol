// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity ^0.8.20;

import "./base/ERC20interface.sol";
import "./base/Common.sol";
//import "hardhat/console.sol";

contract FundsManager is Common, Initializable, IFundsManager {
    uint constant PERCENTAGE_MULTIPLIER = 10 ** 18;

    mapping(uint => mapping(uint => TransactionProposal)) transactionProposals;

    mapping(uint => mapping(address => uint)) public balances;

    struct TransactionProposal {
        uint[] amount;
        uint[] depositToProjectId;
        address[] token;
        address[] to;
    }

    event ExecuteProposal(uint projectId, uint proposalId);
    event ProposalTransfer(uint projectId, address tokenContractAddress, address recipient, uint amount, uint proposalId);
    event Transfer(uint projectId, address tokenContractAddress, address recipient, uint amount);
    event DepositToken(address tokenAddress, uint projectId, uint amount);
    event DestroyToken(uint projectId, uint destroyedTokenAmount, uint ethAmount, address[] sentTokenAddresses, uint[] sentTokenAmounts, address accountAddress);

    receive() external payable {
        revert("You cannot send Ether directly to FundsManager");
    }

    fallback() external payable {
        revert("You cannot send Ether directly to FundsManager");
    }


    function initialize(
        address _delegates,
        address _fundsManager,
        address _tokenSell,
        address _proposal,
        address _gasStation,
        address _contractsManager
    ) public initializer {
        _init(_delegates, _fundsManager, _tokenSell, _proposal, _gasStation, _contractsManager);
    }

    //adds all unretrievable tokens to the GitSwarm project balance
    function sendOrphanTokensToGitSwarm(address tokenAddress) external {
        ERC20interface tokenContract = ERC20interface(tokenAddress);
        uint amount;
        uint nbOfProjects = contractsManagerContract.nextProjectId();
        for (uint i = 0; i < nbOfProjects; i++) {
            amount += balances[i][tokenAddress];
        }
        balances[0][tokenAddress] += (tokenContract.balanceOf(address(this)) - amount);
    }

    function depositEth(uint projectId) external payable {
        balances[projectId][address(0)] += msg.value;
        emit DepositToken(address(0), projectId, msg.value);
    }

    function depositToken(uint projectId, address tokenAddress, uint amount) external {
        ERC20interface tokenContract = ERC20interface(tokenAddress);
        require(tokenContract.transferFrom(msg.sender, address(this), amount), "Token transfer from failed");
        balances[projectId][tokenAddress] += amount;
        emit DepositToken(tokenAddress, projectId, amount);
    }

    function transactionProposal(uint projectId, uint proposalId) external view returns (address[] memory token, uint[] memory amount, address[] memory to, uint[] memory depositToProjectId) {
        token = transactionProposals[projectId][proposalId].token;
        amount = transactionProposals[projectId][proposalId].amount;
        to = transactionProposals[projectId][proposalId].to;
        depositToProjectId = transactionProposals[projectId][proposalId].depositToProjectId;
    }

    function proposeTransaction(
        uint projectId,
        address[] memory tokenContractAddress,
        uint[] memory amount,
        address[] memory to,
        uint[] memory depositToProjectId) external {

        require(amount.length > 0, "Amount can't be an empty list.");
        require(amount.length == to.length && amount.length == depositToProjectId.length &&
        amount.length == tokenContractAddress.length,
            "'amount', 'to' and 'depositToProjectId' arrays must have equal length");
        for (uint i = 0; i < amount.length; i++) {
            require(amount[i] > 0, "Amount must be greater than 0.");
        }

        uint nextProposalId = proposalContract.nextProposalId(projectId);
        transactionProposals[projectId][nextProposalId].token = tokenContractAddress;
        transactionProposals[projectId][nextProposalId].amount = amount;
        transactionProposals[projectId][nextProposalId].depositToProjectId = depositToProjectId;
        transactionProposals[projectId][nextProposalId].to = to;
        proposalContract.createProposal(projectId, TRANSACTION, msg.sender);
    }

    function executeProposal(uint projectId, uint proposalId) external {
        (uint32 typeOfProposal, uint256 endTime, , bool willExecute,) = proposalContract.proposals(projectId, proposalId);
        uint expirationPeriod = proposalContract.parameters(0, keccak256("ExpirationPeriod"));
        require(proposalId < proposalContract.nextProposalId(projectId), "Proposal does not exist");
        require(endTime <= block.timestamp, "Can't execute proposal, buffer time did not end yet");
        require(endTime + expirationPeriod >= block.timestamp, "Can't execute proposal, execute period has expired");
        require(willExecute, "Can't execute, proposal was rejected or vote count was not locked");
        proposalContract.setWillExecute(projectId, proposalId, false);
        if (typeOfProposal == TRANSACTION) {
            executeTransactionProposal(projectId, proposalId, proposalContract);
        } else {
            revert('Unexpected proposal type');
        }
        emit ExecuteProposal(projectId, proposalId);
    }

    function executeTransactionProposal(uint projectId, uint proposalId, IProposal proposalContract) private {
        address[] memory tokenAddress = transactionProposals[projectId][proposalId].token;
        address[] memory to_address = transactionProposals[projectId][proposalId].to;
        uint[] memory amount = transactionProposals[projectId][proposalId].amount;
        uint[] memory depositToProjectId = transactionProposals[projectId][proposalId].depositToProjectId;

        delete transactionProposals[projectId][proposalId];
        proposalContract.deleteProposal(projectId, proposalId);

        for (uint i = 0; i < amount.length; i++) {
            address payable to = payable(to_address[i]);
            emit ProposalTransfer(projectId, tokenAddress[i], to, amount[i], proposalId);
            if (to == address(0)) {
                balances[projectId][tokenAddress[i]] -= amount[i];
                balances[depositToProjectId[i]][tokenAddress[i]] += amount[i];
            } else {
                if (tokenAddress[i] == address(0)) {
                    balances[projectId][address(0)] -= amount[i];
                    if (to == address(gasStationContract)) {
                        gasStationContract.buyGasForProject{value: amount[i]}(projectId);
                    } else {
                        to.transfer(amount[i]);
                    }
                } else {
                    ERC20interface erc20Contract = ERC20interface(tokenAddress[i]);
                    balances[projectId][tokenAddress[i]] -= amount[i];
                    require(erc20Contract.transfer(to, amount[i]), "Token transfer failed");
                }
            }
        }
    }

/**
 * @dev Redeems the specified amount of tokens from the caller's balance.
 * In exchange, the caller receives a proportionate share of the project's
 * remaining tokens and Ethereum holdings. The redeemed tokens are burned,
 * reducing the total supply and adjusting the distribution of remaining assets.
 */

    function reclaimFunds(uint projectId, uint votingTokenAmount, address[] memory tokenContractsAddresses) external {
        ERC20interface votingTokenContract = contractsManagerContract.votingTokenContracts(projectId);
        require(votingTokenContract.allowance(msg.sender, payable(address(this))) >= votingTokenAmount, "insufficient allowance");
        require(votingTokenAmount <= votingTokenContract.balanceOf(msg.sender), "insufficient balance");
        uint percentage = votingTokenAmount * PERCENTAGE_MULTIPLIER / contractsManagerContract.votingTokenCirculatingSupply(projectId);
        uint tokenAmount;
        uint[] memory sentTokenAmounts = new uint[](tokenContractsAddresses.length);
        ERC20interface tokenContract;
        require(votingTokenContract.transferFrom(msg.sender, BURN_ADDRESS, votingTokenAmount), "Token transfer from failed");
        for (uint i = 0; i < tokenContractsAddresses.length; i++) {
            if (tokenContractsAddresses[i] != address(votingTokenContract)) {
                tokenContract = ERC20interface(tokenContractsAddresses[i]);
                tokenAmount = percentage * balances[projectId][tokenContractsAddresses[i]] / PERCENTAGE_MULTIPLIER;
                balances[projectId][tokenContractsAddresses[i]] -= tokenAmount;
                require(tokenContract.transfer(msg.sender, tokenAmount), "Token transfer failed");
                sentTokenAmounts[i] = tokenAmount;
            }
        }
        uint ethAmount = percentage * balances[projectId][address(0)] / PERCENTAGE_MULTIPLIER;
        emit DestroyToken(projectId, votingTokenAmount, ethAmount, tokenContractsAddresses, sentTokenAmounts, msg.sender);
        if (ethAmount > 0) {
            balances[projectId][address(0)] -= ethAmount;
            payable(msg.sender).transfer(ethAmount);
        }
    }

    function sendToken(uint projectId, address tokenAddress, address receiver, uint amount) external restricted(projectId) {
        require(amount <= balances[projectId][tokenAddress], "Not enough tokens on FundsManager");
        balances[projectId][tokenAddress] -= amount;
        ERC20interface tokenContract = ERC20interface(tokenAddress);
        require(tokenContract.transfer(receiver, amount), "Token transfer failed");
    }

    function sendEther(uint projectId, address payable receiver, uint amount) external restricted(projectId) {
        require(amount <= balances[projectId][address(0)], "Not enough Ether on FundsManager");
        balances[projectId][address(0)] -= amount;
        receiver.transfer(amount);
    }

    function updateBalance(uint projectId, address tokenAddress, uint amount) external restricted(projectId) {
        balances[projectId][tokenAddress] += amount;
    }
}
