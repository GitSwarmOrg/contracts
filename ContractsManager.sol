// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity ^0.8.0;

import "./Proposal.sol";
import "./base/Constants.sol";

contract ContractsManager is Constants {

    mapping(uint => address[]) public contracts;
    mapping(uint => mapping(uint => ChangeContractAddressProposal)) public changeContractAddressProposals;
    mapping(uint => mapping(uint => address)) public addBurnAddressProposals;
    mapping(uint => address[]) public burnAddresses;

    uint public nextProjectId;

    address public creatorAddress;

    event ExecuteProposal(uint projectId, uint proposalId);
    event CreateProject(uint contractProjectId, string dbProjectId, address tokenAddress);
    event ChangeContractAddress(uint projectId, uint proposalId, uint32 contractIndex, address contractAddress);

    struct ChangeContractAddressProposal {
        uint32 contractIndex;
        address contractAddress;
    }

    constructor() {
        creatorAddress = msg.sender;
    }

    function deleteExpiredProposals(uint projectId, uint[] memory ids, uint proposalType) external {
        Proposal proposalContract = Proposal(contracts[projectId][PROPOSAL]);
        (uint expirationPeriod,,) = proposalContract.parameters(0, keccak256("ExpirationPeriod"));
        for (uint i = 0; i < ids.length; i++) {
            (,uint256 endTime,,,) = proposalContract.proposals(projectId, ids[i]);
            if (endTime + expirationPeriod <= block.timestamp) {
                if (proposalType == 0) {
                    delete changeContractAddressProposals[projectId][ids[i]];
                } else if (proposalType == 1) {
                    delete addBurnAddressProposals[projectId][ids[i]];
                }
                proposalContract.deleteProposal(projectId, ids[i]);
            }
        }
    }

    function getBurnAddresses(uint projectId) view external returns (address[] memory){
        return burnAddresses[projectId];
    }

    function burnedTokens(uint projectId, Token votingTokenContract) public view returns (uint) {
        uint amount = 0;
        for (uint i = 0; i < burnAddresses[projectId].length; i++) {
            amount += votingTokenContract.balanceOf(burnAddresses[projectId][i]);
        }
        return amount;
    }

    function votingTokenCirculatingSupply(uint projectId) public view returns (uint) {
        Token votingTokenContract = Token(contracts[projectId][TOKEN]);
        return votingTokenContract.totalSupply()
        - votingTokenContract.balanceOf(BURN_ADDRESS)
        - burnedTokens(projectId, votingTokenContract)
        - votingTokenContract.balanceOf(contracts[projectId][FUNDS_MANAGER]);
    }

    function checkMinBalance(uint projectId, address addr) external view returns (bool) {
        Delegates delegatesContract = Delegates(contracts[projectId][DELEGATES]);
        uint required_amount = minimumRequiredAmount(projectId);
        return delegatesContract.checkVotingPower(projectId, addr, required_amount);
    }

    function minimumRequiredAmount(uint projectId) public view returns (uint) {
        Proposal proposalContract = Proposal(contracts[projectId][PROPOSAL]);
        (uint value,,) = proposalContract.parameters(projectId, keccak256("MaxNrOfDelegators"));
        return votingTokenCirculatingSupply(projectId) / value;
    }

    function setContracts(address[] memory addresses) external {
        require(creatorAddress == msg.sender);
        contracts[nextProjectId] = addresses;
        contracts[nextProjectId].push(address(this));
        creatorAddress = address(0x0);
    }

    function createProject(string memory dbProjectId, address tokenContractAddress) external {
        contracts[nextProjectId] = contracts[0];
        contracts[nextProjectId][0] = tokenContractAddress;
        Proposal proposalContract = Proposal(contracts[nextProjectId][PROPOSAL]);
        proposalContract.initializeParameters(nextProjectId);
        burnAddresses[nextProjectId].push(BURN_ADDRESS);
        emit CreateProject(nextProjectId, dbProjectId, tokenContractAddress);
        nextProjectId++;
    }

    function isTrustedContract(uint projectId, address contractAddress) view public returns (bool) {
        for (uint i = 0; i < contracts[projectId].length; i++) {
            if (contracts[projectId][i] == contractAddress) {
                return true;
            }
        }
        return false;
    }

    function proposeChangeContractAddress(uint projectId, uint32 contractIndex, address contractAddress) external {
        Proposal proposalContract = Proposal(contracts[projectId][PROPOSAL]);
        changeContractAddressProposals[projectId][proposalContract.nextProposalId(projectId)].contractIndex = contractIndex;
        changeContractAddressProposals[projectId][proposalContract.nextProposalId(projectId)].contractAddress = contractAddress;
        proposalContract.createProposal(projectId, CHANGE_CONTRACT_ADDRESS, msg.sender);
    }

    function proposeAddBurnAddress(uint projectId, address burnAddress) external {
        Proposal proposalContract = Proposal(contracts[projectId][PROPOSAL]);
        addBurnAddressProposals[projectId][proposalContract.nextProposalId(projectId)] = burnAddress;
        proposalContract.createProposal(projectId, ADD_BURN_ADDRESS, msg.sender);
    }

    function executeProposal(uint projectId, uint proposalId) external {
        Proposal proposalContract = Proposal(contracts[projectId][PROPOSAL]);
        (uint32 typeOfProposal, uint256 endTime, , bool willExecute,) = proposalContract.proposals(projectId, proposalId);
        (uint expirationPeriod,,) = proposalContract.parameters(0, keccak256("ExpirationPeriod"));
        require(proposalId < proposalContract.nextProposalId(projectId), "Proposal does not exist");
        require(endTime <= block.timestamp, "Can't execute proposal, buffer time did not end yet");
        require(endTime + expirationPeriod >= block.timestamp, "Can't execute proposal, execute period has expired");
        require(willExecute, "Can't execute, proposal was rejected or vote count was not locked");
        proposalContract.setWillExecute(projectId, proposalId, false);

        if (typeOfProposal == CHANGE_CONTRACT_ADDRESS) {
            contracts[projectId][changeContractAddressProposals[projectId][proposalId].contractIndex] = changeContractAddressProposals[projectId][proposalId].contractAddress;
            emit ChangeContractAddress(projectId, proposalId, changeContractAddressProposals[projectId][proposalId].contractIndex, changeContractAddressProposals[projectId][proposalId].contractAddress);
            proposalContract.deleteProposal(projectId, proposalId);
            delete changeContractAddressProposals[projectId][proposalId];
        } else if (typeOfProposal == ADD_BURN_ADDRESS) {
            burnAddresses[projectId].push(addBurnAddressProposals[projectId][proposalId]);
            proposalContract.deleteProposal(projectId, proposalId);
            delete addBurnAddressProposals[projectId][proposalId];
        } else {
            revert('Unexpected proposal type');
        }
        emit ExecuteProposal(projectId, proposalId);
    }
}
