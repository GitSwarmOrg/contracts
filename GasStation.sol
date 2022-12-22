// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity ^0.8.0;

import "./ContractsManager.sol";
import "./base/Constants.sol";
import "./base/Common.sol";
import "./Proposal.sol";

contract GasStation is Constants, Common {

    mapping(uint => TransferToGasAddressProposal) public transferToGasAddressProposals;

    struct TransferToGasAddressProposal {
        uint amount;
        address to;
    }

    event BuyGasEvent(uint projectId, uint amount);
    event PayForProcessProposalEvent(uint projectId, address proposalContract, uint proposalId, uint value);
    event ExecuteProposal(uint projectId, uint proposalId);

    constructor(address gitSwarmContractsManagerAddress) {
        contractsManager = ContractsManager(gitSwarmContractsManagerAddress);
    }

    function deleteExpiredProposals(uint[] memory ids) external {
        Proposal proposalContract = Proposal(contractsManager.contracts(0, PROPOSAL));
        (uint expirationPeriod,,) = proposalContract.parameters(0, keccak256("ExpirationPeriod"));
        for (uint i = 0; i < ids.length; i++) {
            (,uint256 endTime,,,) = proposalContract.proposals(0, ids[i]);
            if (endTime + expirationPeriod <= block.timestamp) {
                delete transferToGasAddressProposals[ids[i]];
                proposalContract.deleteProposal(0, ids[i]);
            }
        }
    }

    function buyGasForProject(uint projectId) payable external {
        require(msg.value > 0);
        emit BuyGasEvent(projectId, msg.value);
    }

    function payForProcessProposal(uint projectId, address proposalContract, uint proposalId) payable external {
        require(msg.value > 0);
        emit PayForProcessProposalEvent(projectId, proposalContract, proposalId, msg.value);
    }

    function proposeTransferToGasAddress(uint amount, address to) external {
        Proposal proposalContract = Proposal(contractsManager.contracts(0,PROPOSAL));
        transferToGasAddressProposals[proposalContract.nextProposalId(0)].amount = amount;
        transferToGasAddressProposals[proposalContract.nextProposalId(0)].to = to;

        proposalContract.createProposal(0, TRANSFER_TO_GAS_ADDRESS, msg.sender);
    }

    function executeProposal(uint id) external {
        Proposal proposalContract = Proposal(contractsManager.contracts(0, PROPOSAL));
        (uint32 typeOfProposal, uint256 endTime, , bool willExecute,) = proposalContract.proposals(0, id);
        (uint expirationPeriod,,) = proposalContract.parameters(0, keccak256("ExpirationPeriod"));
        require(id < proposalContract.nextProposalId(0), "Proposal does not exist");
        require(endTime <= block.timestamp, "Can't execute proposal, buffer time did not end yet");
        require(endTime + expirationPeriod >= block.timestamp, "Can't execute proposal, execute period has expired");
        require(willExecute, "Can't execute, proposal was rejected or vote count was not locked");
        proposalContract.setWillExecute(0, id, false);
        emit ExecuteProposal(0, id);

        if (typeOfProposal == TRANSFER_TO_GAS_ADDRESS) {
            address payable to_address = payable(transferToGasAddressProposals[id].to);
            uint amount = transferToGasAddressProposals[id].amount;
            require(payable(address(this)).balance >= amount);
            delete transferToGasAddressProposals[id];
            proposalContract.deleteProposal(0, id);
            to_address.transfer(amount);
        } else {
            revert('Unexpected proposal type');
        }
    }
}
