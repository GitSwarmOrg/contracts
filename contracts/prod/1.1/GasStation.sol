// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;

import "./ContractsManager.sol";
import "./base/Common.sol";

/**
 * @title Gas Station for Projects
 * @dev This contract allows projects to buy gas and manage transfers to gas addresses through proposals.
 * @notice This contract uses the ContractsManager and Common contracts for managing access and functionalities.
 */
contract GasStation is Common, Initializable, IGasStation {
    using Address for address payable;

    /// @notice Mapping from proposal ID to TransferToGasAddressProposal details.
    /// @dev This mapping stores the details of proposals for transferring ETH to specific gas addresses.
    mapping(uint => TransferToGasAddressProposal) public transferToGasAddressProposals;

    /**
     * @dev Struct to hold proposals for transferring ETH to gas addresses.
     * @param amount The amount of ETH to transfer.
     * @param to The recipient address of the ETH.
     */
    struct TransferToGasAddressProposal {
        uint amount;
        address to;
    }

    // Events declaration
    /**
     * @dev Emitted when a user buys gas by sending ETH to the contract.
     * @param projectId The ID of the project for which gas is being bought.
     * @param amount The amount of ETH bought by the user.
     */
    event BuyGasEvent(uint projectId, uint amount);

    /**
     * @dev Emitted when a proposal for transferring ETH from the project balance to the gas fund is executed.
     * @param projectId The ID of the project associated with the proposal.
     * @param proposalId The ID of the executed proposal.
     */
    event ExecuteProposal(uint projectId, uint proposalId);

    /**
     * @dev Emitted after ETH has been successfully transferred to a project's gas fund.
     * @param toAddress The recipient address of the ETH.
     * @param amount The amount of ETH transferred.
     */
    event TransferredGas(address toAddress, uint amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract with necessary addresses.
     * @param _delegates Address of the delegates contract.
     * @param _fundsManager Address of the funds manager contract.
     * @param _parameters The address of the parameters contract.
     * @param _proposal Address of the proposal contract.
     * @param _gasStation Address of the gas station contract itself (for initial setup).
     * @param _contractsManager Address of the contracts manager.
     * @notice This function is restricted to be called only once.
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
     * @dev Allows a project to buy gas by sending ETH to the contract.
     * @param projectId The ID of the project for which gas is being bought.
     * @notice This function is payable and requires the sent value to be greater than 0.
     */
    function buyGasForProject(uint projectId) payable external {
        require(msg.value > 0, "Value must be greater than zero");
        emit BuyGasEvent(projectId, msg.value);
    }

    /**
     * @dev Proposes a transfer of ETH to a specified gas address.
     * @param amount The amount of ETH to transfer.
     * @param to The recipient address of the ETH.
     * @notice The proposal is recorded and will be executed upon approval.
     */
    function proposeTransferToGasAddress(uint amount, address to) external {
        transferToGasAddressProposals[proposalContract.nextProposalId(0)].amount = amount;
        transferToGasAddressProposals[proposalContract.nextProposalId(0)].to = to;

        proposalContract.createProposal(0, TRANSFER_TO_GAS_ADDRESS, msg.sender);
    }

    /**
     * @dev Executes an approved proposal for transferring ETH to a gas address.
     * @param proposalId The ID of the proposal to execute.
     * @notice Requires the proposal to exist, to be executable based on timing, and to have been approved.
     */
    function executeProposal(uint proposalId) external {
        (uint32 typeOfProposal, , bool willExecute,, uint256 endTime) = proposalContract.proposals(0, proposalId);
        uint expirationPeriod = parametersContract.parameters(0, keccak256("ExpirationPeriod"));
        require(proposalId < proposalContract.nextProposalId(0), "Proposal does not exist");
        require(endTime <= block.timestamp, "Can't execute proposal, buffer time did not end yet");
        require(endTime + expirationPeriod >= block.timestamp, "Can't execute proposal, execute period has expired");
        require(willExecute, "Can't execute, proposal was rejected or vote count was not locked");
        proposalContract.setWillExecute(0, proposalId, false);

        if (typeOfProposal == TRANSFER_TO_GAS_ADDRESS) {
            address payable to_address = payable(transferToGasAddressProposals[proposalId].to);
            uint amount = transferToGasAddressProposals[proposalId].amount;
            require(payable(address(this)).balance >= amount, "Insufficient balance");
            delete transferToGasAddressProposals[proposalId];
            proposalContract.deleteProposal(0, proposalId);
            to_address.sendValue(amount);
            emit TransferredGas(to_address, amount);
        } else {
            revert('Unexpected proposal type');
        }
        emit ExecuteProposal(0, proposalId);
    }
}
