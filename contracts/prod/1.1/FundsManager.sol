// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;

import "./base/Common.sol";
import "../../openzeppelin-v5.0.1/token/ERC20/utils/SafeERC20.sol";
//import "hardhat/console.sol";

/** @title FundsManager for GitSwarm Projects
  * @notice Manages funds, transactions, and token interactions for projects within GitSwarm.
  */
contract FundsManager is Common, Initializable, IFundsManager {
    using SafeERC20 for IERC20;
    using Address for address payable;

    /** @dev Utilized for calculations involving percentages, set to 10^18. */
    uint256 constant PERCENTAGE_MULTIPLIER = 10 ** 18;

    /** @dev A nested mapping structure to store transaction proposals by project ID and proposal ID. */
    mapping(uint256 => mapping(uint256 => TransactionProposal)) transactionProposals;

    /** @dev Mapping to track token and ETH balances by project ID and token address. */
    mapping(uint256 => mapping(address => uint256)) public balances;

    /** @dev Contains arrays for transaction amounts, project IDs to deposit to, token addresses, and recipient addresses */
    struct TransactionProposal {
        uint256[] amount;
        uint256[] depositToProjectId;
        address[] token;
        address[] to;
    }
    /**
     * @dev Emitted when a transaction proposal is executed.
     * @param projectId The ID of the project for which the proposal is executed.
     * @param proposalId The ID of the executed proposal.
     */
    event ExecuteProposal(uint256 projectId, uint256 proposalId);
    /**
     * @dev Emitted for each transfer within a proposal.
     * @param projectId The ID of the project for which the transfer is part of a proposal.
     * @param tokenContractAddress The address of the token being transferred.
     * @param recipient The address receiving the tokens.
     * @param amount The amount of tokens being transferred.
     * @param proposalId The ID of the proposal the transfer is part of.
     */
    event ProposalTransfer(uint256 projectId, address tokenContractAddress, address recipient, uint256 amount, uint256 proposalId);
    /**
     * @dev Emitted when a transfer of tokens or ETH is made outside of a proposal.
     * @param projectId The ID of the project for which the transfer is made.
     * @param tokenContractAddress The address of the token being transferred, or address(0) for ETH.
     * @param recipient The address receiving the tokens or ETH.
     * @param amount The amount being transferred.
     */
    event Transfer(uint256 projectId, address tokenContractAddress, address recipient, uint256 amount);
    /**
     * @dev Emitted when a transfer of tokens or ETH is made from a project to another project.
     * @param projectId The ID of the project for which the transfer is made.
     * @param tokenContractAddress The address of the token being transferred, or address(0) for ETH.
     * @param recipient The project ID receiving the tokens or ETH.
     * @param amount The amount being transferred.
     */
    event ProjectToProjectTransfer(uint256 projectId, address tokenContractAddress, uint256 recipient, uint256 amount);
    /**
     * @dev Emitted when tokens are deposited to a project's balance.
     * @param tokenAddress The address of the token being deposited.
     * @param projectId The ID of the project receiving the deposit.
     * @param amount The amount of tokens being deposited.
     */
    event DepositToken(address tokenAddress, uint256 projectId, uint256 amount);
    /**
     * @dev Emitted when tokens are destroyed in a reclaim funds operation.
     * @param projectId The ID of the project from which tokens are being destroyed.
     * @param destroyedTokenAmount The amount of tokens being destroyed.
     * @param ethAmount The amount of ETH sent as part of the reclaim.
     * @param sentTokenAddresses The addresses of other tokens sent as part of the reclaim.
     * @param sentTokenAmounts The amounts of other tokens sent as part of the reclaim.
     * @param accountAddress The address of the account performing the reclaim.
     */
    event DestroyToken(uint256 projectId, uint256 destroyedTokenAmount, uint256 ethAmount, address[] sentTokenAddresses, uint256[] sentTokenAmounts, address accountAddress);
    /**
     * @dev Emitted when orphan tokens are sent to the GitSwarm project balance.
     * @param amount The amount of orphan tokens sent.
     */
    event OrphanTokensSent(uint256 amount);
    /**
     * @dev Emitted when tokens are sent to a receiver from a project's balance.
     * @param projectId The ID of the project from which tokens are sent.
     * @param tokenAddress The address of the token being sent.
     * @param receiver The address of the receiver.
     * @param amount The amount of tokens sent.
     */
    event TokensSent(uint256 projectId, address tokenAddress, address receiver, uint256 amount);
    /**
     * @dev Emitted when ETH is sent to a receiver from a project's balance.
     * @param projectId The ID of the project from which ETH is sent.
     * @param receiver The address of the receiver.
     * @param amount The amount of ETH sent.
     */
    event EthSent(uint256 projectId, address receiver, uint256 amount);
    /**
     * @dev Emitted when a project's token balance is updated.
     * @param projectId The ID of the project whose balance is updated.
     * @param tokenAddress The address of the token whose balance is updated.
     * @param amount The new amount added to the balance.
     */
    event BalanceUpdated(uint256 projectId, address tokenAddress, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract with addresses of other components it interacts with.
     * @param _delegates Address of the Delegates contract.
     * @param _fundsManager Address of the FundsManager contract itself.
     * @param _parameters The address of the parameters contract.
     * @param _proposal Address of the Proposal contract.
     * @param _gasStation Address of the GasStation contract.
     * @param _contractsManager Address of the ContractsManager.
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
     * @notice Sends orphan tokens to GitSwarm project balance.
     * @dev Adds all unretrievable tokens to the GitSwarm project balance
     * @param tokenAddress The address of the token to aggregate and send.
     */
    function sendOrphanTokensToGitSwarm(address tokenAddress) external {
        IERC20 tokenContract = IERC20(tokenAddress);
        uint256 amount;
        uint256 nbOfProjects = contractsManagerContract.nextProjectId();
        for (uint256 i = 0; i < nbOfProjects; i++) {
            amount += balances[i][tokenAddress];
        }
        emit OrphanTokensSent(amount);
        balances[0][tokenAddress] += (tokenContract.balanceOf(address(this)) - amount);
    }
    /**
     * @notice Allows deposit of ETH to a project's balance.
     * @dev Credits the sent ETH to the specified project's balance.
     * @param projectId The ID of the project to which ETH is deposited.
     */
    function depositEth(uint256 projectId) external payable {
        balances[projectId][address(0)] += msg.value;
        emit DepositToken(address(0), projectId, msg.value);
    }
    /**
     * @notice Allows deposit of tokens to a project's balance.
     * @dev Credits the sent tokens to the specified project's balance.
     * @param projectId The ID of the project to which tokens are deposited.
     * @param tokenAddress The address of the token to deposit.
     * @param amount The amount of tokens to deposit.
     */
    function depositToken(uint256 projectId, address tokenAddress, uint256 amount) external {
        IERC20 tokenContract = IERC20(tokenAddress);
        tokenContract.safeTransferFrom(msg.sender, address(this), amount);
        balances[projectId][tokenAddress] += amount;
        emit DepositToken(tokenAddress, projectId, amount);
    }
    /**
     * @notice Views a transaction proposal for a project.
     * @dev Returns details of a transaction proposal by project and proposal ID.
     * @param projectId The ID of the project.
     * @param proposalId The ID of the proposal to view.
     */
    function transactionProposal(uint256 projectId, uint256 proposalId) external view returns (address[] memory token, uint256[] memory amount, address[] memory to, uint256[] memory depositToProjectId) {
        token = transactionProposals[projectId][proposalId].token;
        amount = transactionProposals[projectId][proposalId].amount;
        to = transactionProposals[projectId][proposalId].to;
        depositToProjectId = transactionProposals[projectId][proposalId].depositToProjectId;
    }

    /**
     * @notice Proposes a new transaction for a project.
     * @dev Creates a new transaction proposal with details about the transactions to be performed.
     * @param projectId The ID of the project for which the proposal is being made.
     * @param tokenContractAddress Array of addresses of the tokens involved in the transactions.
     * @param amount Array of amounts for each transaction.
     * @param to Array of recipient addresses for the transactions.
     * @param depositToProjectId Array of project IDs to which tokens will be deposited, if applicable.
     */
    function proposeTransaction(
        uint256 projectId,
        address[] memory tokenContractAddress,
        uint256[] memory amount,
        address[] memory to,
        uint256[] memory depositToProjectId) external {

        require(amount.length > 0, "Amount can't be an empty list.");
        require(amount.length == to.length && amount.length == depositToProjectId.length &&
        amount.length == tokenContractAddress.length,
            "'amount', 'to' and 'depositToProjectId' arrays must have equal length");
        for (uint256 i = 0; i < amount.length; i++) {
            require(amount[i] > 0, "Amount must be greater than 0.");
        }

        uint256 nextProposalId = proposalContract.nextProposalId(projectId);
        TransactionProposal storage p = transactionProposals[projectId][nextProposalId];
        p.token = tokenContractAddress;
        p.amount = amount;
        p.depositToProjectId = depositToProjectId;
        p.to = to;
        proposalContract.createProposal(projectId, TRANSACTION, msg.sender);
    }

    /**
     * @notice Executes a transaction proposal for a project.
     * @dev Performs the transactions specified in a proposal, transferring tokens or ETH as detailed.
     * @param projectId The ID of the project for which the proposal is executed.
     * @param proposalId The ID of the proposal to execute.
     */
    function executeProposal(uint256 projectId, uint256 proposalId) external {
        (uint32 typeOfProposal, , bool willExecute,, uint256 endTime) = proposalContract.proposals(projectId, proposalId);
        uint256 expirationPeriod = parametersContract.parameters(projectId, keccak256("ExpirationPeriod"));
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
    /**
     * @dev Executes the transactions defined in a proposal for a specific project.
     * @notice This function is called to perform the token or Ether transfers as specified in a project's transaction proposal.
     * @param projectId The ID of the project for which the transaction proposal is being executed.
     * @param proposalId The ID of the proposal within the project to execute.
     * @param proposalContract The interface of the Proposal contract to interact with proposal data.
     */
    function executeTransactionProposal(uint256 projectId, uint256 proposalId, IProposal proposalContract) private {
        address[] memory tokenAddress = transactionProposals[projectId][proposalId].token;
        address[] memory to_address = transactionProposals[projectId][proposalId].to;
        uint256[] memory amount = transactionProposals[projectId][proposalId].amount;
        uint256[] memory depositToProjectId = transactionProposals[projectId][proposalId].depositToProjectId;

        delete transactionProposals[projectId][proposalId];
        proposalContract.deleteProposal(projectId, proposalId);

        for (uint256 i = 0; i < amount.length; i++) {
            address payable to = payable(to_address[i]);
            if (to == address(0)) {
                emit ProjectToProjectTransfer(projectId, tokenAddress[i], depositToProjectId[i], amount[i]);
                balances[projectId][tokenAddress[i]] -= amount[i];
                balances[depositToProjectId[i]][tokenAddress[i]] += amount[i];
            } else {
                emit ProposalTransfer(projectId, tokenAddress[i], to, amount[i], proposalId);
                if (tokenAddress[i] == address(0)) {
                    balances[projectId][address(0)] -= amount[i];
                    if (to == address(gasStationContract)) {
                        gasStationContract.buyGasForProject{value: amount[i]}(projectId);
                    } else {
                        to.sendValue(amount[i]);
                    }
                } else {
                    IERC20 erc20Contract = IERC20(tokenAddress[i]);
                    balances[projectId][tokenAddress[i]] -= amount[i];
                    erc20Contract.safeTransfer(to, amount[i]);
                }
            }
        }
    }

    /**
     * @notice Allows a token holder to redeem their tokens in exchange for a
     * proportionate share of the project's assets.
     * @dev Redeems the specified amount of tokens from the caller's balance.
     * In exchange, the caller receives a proportionate share of the project's
     * remaining tokens and Ethereum holdings. The redeemed tokens are burned,
     * reducing the total supply and adjusting the distribution of remaining assets.
     * @param projectId The ID of the project from which funds are being reclaimed.
     * @param votingTokenAmount The amount of voting tokens the caller wishes to redeem.
     * @param tokenContractsAddresses An array of token contract addresses for which the
     * caller is redeeming tokens.
     */
    function reclaimFunds(uint256 projectId, uint256 votingTokenAmount, address[] memory tokenContractsAddresses) external {
        IERC20 votingTokenContract = contractsManagerContract.votingTokenContracts(projectId);
        require(votingTokenContract.allowance(msg.sender, payable(address(this))) >= votingTokenAmount, "insufficient allowance");
        require(votingTokenAmount > 0, "cannot reclaim for 0 tokens");
        require(votingTokenAmount <= votingTokenContract.balanceOf(msg.sender), "insufficient balance");
        uint256 percentage = votingTokenAmount * PERCENTAGE_MULTIPLIER / contractsManagerContract.votingTokenCirculatingSupply(projectId);
        uint256 tokenAmount;
        uint256[] memory sentTokenAmounts = new uint256[](tokenContractsAddresses.length);
        IERC20 tokenContract;
        votingTokenContract.safeTransferFrom(msg.sender, BURN_ADDRESS, votingTokenAmount);
        for (uint256 i = 0; i < tokenContractsAddresses.length; i++) {
            if (tokenContractsAddresses[i] != address(votingTokenContract)) {
                tokenContract = IERC20(tokenContractsAddresses[i]);
                tokenAmount = percentage * balances[projectId][tokenContractsAddresses[i]] / PERCENTAGE_MULTIPLIER;
                balances[projectId][tokenContractsAddresses[i]] -= tokenAmount;
                tokenContract.safeTransfer(msg.sender, tokenAmount);
                sentTokenAmounts[i] = tokenAmount;
            }
        }
        uint256 ethAmount = percentage * balances[projectId][address(0)] / PERCENTAGE_MULTIPLIER;
        emit DestroyToken(projectId, votingTokenAmount, ethAmount, tokenContractsAddresses, sentTokenAmounts, msg.sender);
        if (ethAmount > 0) {
            balances[projectId][address(0)] -= ethAmount;
            payable(msg.sender).sendValue(ethAmount);
        }
    }

    /**
     * @notice Transfers a specified amount of tokens from the project's balance to a receiver.
     * @dev Requires that the project has a sufficient balance of the specified token.
     * The transferred tokens are subtracted from the project's balance.
     * @param projectId The ID of the project from which tokens are being sent.
     * @param tokenAddress The address of the token to transfer.
     * @param receiver The address receiving the tokens.
     * @param amount The amount of tokens to transfer.
     */
    function sendToken(uint256 projectId, address tokenAddress, address receiver, uint256 amount) external restricted(projectId) {
        require(receiver != address(0), "Sending to address(0) is forbidden");
        require(amount <= balances[projectId][tokenAddress], "Not enough tokens on FundsManager");
        balances[projectId][tokenAddress] -= amount;
        IERC20 tokenContract = IERC20(tokenAddress);
        tokenContract.safeTransfer(receiver, amount);
        emit TokensSent(projectId, tokenAddress, receiver, amount);
    }

    /**
     * @notice Transfers a specified amount of Ether from the project's balance to a receiver.
     * @dev Requires that the project has a sufficient balance of Ether.
     * The transferred Ether is subtracted from the project's balance.
     * @param projectId The ID of the project from which Ether is being sent.
     * @param receiver The payable address receiving the Ether.
     * @param amount The amount of Ether to transfer.
     */
    function sendEther(uint256 projectId, address payable receiver, uint256 amount) external restricted(projectId) {
        require(receiver != address(0), "Sending to address(0) is forbidden");
        require(amount <= balances[projectId][address(0)], "Not enough Ether on FundsManager");
        balances[projectId][address(0)] -= amount;
        receiver.sendValue(amount);
        emit EthSent(projectId, receiver, amount);
    }
}
