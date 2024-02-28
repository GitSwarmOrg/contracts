// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity ^0.8.0;

import "./ContractsManager.sol";
import "./base/Common.sol";

contract GasStation is Common, Initializable, IGasStation {

    mapping(uint => TransferToGasAddressProposal) public transferToGasAddressProposals;

    struct TransferToGasAddressProposal {
        uint amount;
        address to;
    }

    event BuyGasEvent(uint projectId, uint amount);
    event ExecuteProposal(uint projectId, uint proposalId);
    event TransferredGas(address toAddress, uint amount);

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

    function buyGasForProject(uint projectId) payable external {
        require(msg.value > 0);
        emit BuyGasEvent(projectId, msg.value);
    }

    function proposeTransferToGasAddress(uint amount, address to) external {
        transferToGasAddressProposals[proposalContract.nextProposalId(0)].amount = amount;
        transferToGasAddressProposals[proposalContract.nextProposalId(0)].to = to;

        proposalContract.createProposal(0, TRANSFER_TO_GAS_ADDRESS, msg.sender);
    }

    function executeProposal(uint id) external {
        (uint32 typeOfProposal, uint256 endTime, , bool willExecute,) = proposalContract.proposals(0, id);
        uint expirationPeriod = proposalContract.parameters(0, keccak256("ExpirationPeriod"));
        require(id < proposalContract.nextProposalId(0), "Proposal does not exist");
        require(endTime <= block.timestamp, "Can't execute proposal, buffer time did not end yet");
        require(endTime + expirationPeriod >= block.timestamp, "Can't execute proposal, execute period has expired");
        require(willExecute, "Can't execute, proposal was rejected or vote count was not locked");
        proposalContract.setWillExecute(0, id, false);

        if (typeOfProposal == TRANSFER_TO_GAS_ADDRESS) {
            address payable to_address = payable(transferToGasAddressProposals[id].to);
            uint amount = transferToGasAddressProposals[id].amount;
            require(payable(address(this)).balance >= amount);
            delete transferToGasAddressProposals[id];
            proposalContract.deleteProposal(0, id);
            to_address.transfer(amount);
            emit TransferredGas(to_address, amount);
        } else {
            revert('Unexpected proposal type');
        }
        emit ExecuteProposal(0, id);
    }
}
