// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity ^0.8.0;

import "./base/ERC20interface.sol";
import "./base/Constants.sol";
import "./base/Common.sol";
import "./Token.sol";
import "./Proposal.sol";
import "./GasStation.sol";

contract FundsManager is Constants, Common {

    uint constant PERCENTAGE_MULTIPLIER = 10 ** 18;

    mapping(uint => mapping(uint => TransactionProposal)) transactionProposals;

    mapping(uint => mapping(address => uint)) public balances;

    event ExecuteProposal(uint projectId, uint proposalId);
    event ProposalTransfer(uint projectId, address tokenContractAddress, address recipient, uint amount, uint proposalId);
    event Transfer(uint projectId, address tokenContractAddress, address recipient, uint amount);
    event DepositToken(address tokenAddress, uint projectId, uint amount);
    event DestroyToken(uint projectId, uint destroyedTokenAmount, uint ethAmount, address[] sentTokenAddresses, uint[] sentTokenAmounts, address accountAddress);

    struct TransactionProposal {
        uint[] amount;
        uint[] depositToProjectId;
        address[] token;
        address[] to;
    }

    constructor(address contractsManagerAddress) {
        contractsManager = ContractsManager(contractsManagerAddress);
    }

    receive() external payable {
        revert("You cannot send Ether directly to FundsManager");
    }

    fallback() external payable {
        revert("You cannot send Ether directly to FundsManager");
    }

    function sendOrphanTokensToGitSwarm(address tokenAddress) external {
        ERC20interface tokenContract = ERC20interface(tokenAddress);
        uint amount;
        uint nbOfProjects = contractsManager.nextProjectId();
        for (uint i = 0; i < nbOfProjects; i++) {
            amount += balances[i][tokenAddress];
        }
        balances[0][tokenAddress] += (tokenContract.balanceOf(address(this)) - amount);
    }

    function deleteExpiredProposals(uint projectId, uint[] memory ids) external {
        Proposal proposalContract = Proposal(contractsManager.contracts(projectId, PROPOSAL));
        (uint expirationPeriod,,) = proposalContract.parameters(0, keccak256("ExpirationPeriod"));
        for (uint i = 0; i < ids.length; i++) {
            (,uint256 endTime,,,) = proposalContract.proposals(projectId, ids[i]);
            if (endTime + expirationPeriod <= block.timestamp) {
                delete transactionProposals[projectId][ids[i]];
                proposalContract.deleteProposal(projectId, ids[i]);
            }
        }
    }

    function depositEth(uint projectId) external payable {
        balances[projectId][address(0x0)] += msg.value;
        emit DepositToken(address(0x0), projectId, msg.value);
    }

    function depositToken(uint projectId, address tokenAddress, uint amount) external {
        ERC20interface tokenContract = ERC20interface(tokenAddress);
        require(tokenContract.allowance(msg.sender, address(this)) >= amount, "Not enough token approved on token contract for this contract");
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

    function proposeTransaction(uint projectId, address[] memory tokenContractAddress, uint[] memory amount, address[] memory to, uint[] memory depositToProjectId) external {
        require(amount.length > 0, "Amount can't be an empty list.");
        require(amount.length == to.length && amount.length == depositToProjectId.length && amount.length == tokenContractAddress.length, "'amount', 'to' and 'depositToProjectId' arrays must have equal length");
        for (uint i = 0; i < amount.length; i++) {
            require(amount[i] > 0, "Amount must be greater than 0.");
        }
        Proposal proposalContract = Proposal(contractsManager.contracts(projectId, PROPOSAL));
        transactionProposals[projectId][proposalContract.nextProposalId(projectId)].token = tokenContractAddress;
        transactionProposals[projectId][proposalContract.nextProposalId(projectId)].amount = amount;
        transactionProposals[projectId][proposalContract.nextProposalId(projectId)].depositToProjectId = depositToProjectId;
        transactionProposals[projectId][proposalContract.nextProposalId(projectId)].to = to;

        proposalContract.createProposal(projectId, TRANSACTION, msg.sender);
    }

    function executeProposal(uint projectId, uint proposalId) external {
        Proposal proposalContract = Proposal(contractsManager.contracts(projectId, PROPOSAL));
        (uint32 typeOfProposal, uint256 endTime, , bool willExecute,) = proposalContract.proposals(projectId, proposalId);
        (uint expirationPeriod,,) = proposalContract.parameters(0, keccak256("ExpirationPeriod"));
        require(proposalId < proposalContract.nextProposalId(projectId), "Proposal does not exist");
        require(endTime <= block.timestamp, "Can't execute proposal, buffer time did not end yet");
        require(endTime + expirationPeriod >= block.timestamp, "Can't execute proposal, execute period has expired");
        require(willExecute, "Can't execute, proposal was rejected or vote count was not locked");
        proposalContract.setWillExecute(projectId, proposalId, false);
        emit ExecuteProposal(projectId, proposalId);
        if (typeOfProposal == TRANSACTION) {
            executeTransactionProposal(projectId, proposalId, proposalContract);
        } else {
            revert('Unexpected proposal type');
        }
    }

    function executeTransactionProposal(uint projectId, uint proposalId, Proposal proposalContract) private {
        address[] memory tokenAddress = transactionProposals[projectId][proposalId].token;
        address[] memory to_address = transactionProposals[projectId][proposalId].to;
        uint[] memory amount = transactionProposals[projectId][proposalId].amount;
        uint[] memory depositToProjectId = transactionProposals[projectId][proposalId].depositToProjectId;

        delete transactionProposals[projectId][proposalId];
        proposalContract.deleteProposal(projectId, proposalId);

        for (uint i = 0; i < amount.length; i++) {
            address payable to = payable(to_address[i]);
            emit ProposalTransfer(projectId, tokenAddress[i], to, amount[i], proposalId);
            if (to == address(0x0)) {
                if (tokenAddress[i] == address(0x0)) {
                    balances[projectId][address(0x0)] -= amount[i];
                    balances[depositToProjectId[i]][address(0x0)] += amount[i];
                } else {
                    balances[projectId][tokenAddress[i]] -= amount[i];
                    balances[depositToProjectId[i]][tokenAddress[i]] += amount[i];
                }
            } else {
                if (tokenAddress[i] == address(0x0)) {
                    balances[projectId][address(0x0)] -= amount[i];
                    if (to == contractsManager.contracts(projectId, GAS_STATION)) {
                        GasStation(payable(contractsManager.contracts(projectId, GAS_STATION))).buyGasForProject{value : amount[i]}(projectId);
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

    function reclaimFunds(uint projectId, uint votingTokenAmount, address[] memory tokenContractsAddresses) external {
        Token votingTokenContract = Token(contractsManager.contracts(projectId, TOKEN));
        require(votingTokenContract.allowance(msg.sender, payable(address(this))) >= votingTokenAmount && votingTokenAmount <= votingTokenContract.balanceOf(msg.sender));
        uint percentage = votingTokenAmount * PERCENTAGE_MULTIPLIER / contractsManager.votingTokenCirculatingSupply(projectId);
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
        uint ethAmount = percentage * balances[projectId][address(0x0)] / PERCENTAGE_MULTIPLIER;
        emit DestroyToken(projectId, votingTokenAmount, ethAmount, tokenContractsAddresses, sentTokenAmounts, msg.sender);
        if (ethAmount > 0) {
            balances[projectId][address(0x0)] -= ethAmount;
            payable(msg.sender).transfer(ethAmount);
        }
    }

    function sendToken(uint projectId, address tokenAddress, address receiver, uint amount) external restricted(projectId) {
        require(amount <= balances[projectId][tokenAddress], "Not enough tokens on funds manager");
        balances[projectId][tokenAddress] -= amount;
        ERC20interface tokenContract = ERC20interface(tokenAddress);
        require(tokenContract.transfer(receiver, amount), "Token transfer failed");
    }

    function sendEther(uint projectId, address payable receiver, uint amount) external restricted(projectId) {
        require(amount <= balances[projectId][address(0x0)], "Not enough Ether on FundsManager");
        balances[projectId][address(0x0)] -= amount;
        receiver.transfer(amount);
    }

    function updateBalance(uint projectId, address tokenAddress, uint amount) external restricted(projectId) {
        balances[projectId][tokenAddress] += amount;
    }
}
