// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity ^0.8.0;

import "./base/Common.sol";
import "./base/ERC20interface.sol";
import "./base/TransparentUpgradeableProxy.sol";

contract ContractsManager is Common, Initializable, IContractsManager {

    mapping(uint => ERC20interface) public votingTokenContracts;
    mapping(uint => address[]) public trustedAddresses;
    mapping(uint => mapping(uint => address)) public changeVotingTokenProposals;
    mapping(uint => mapping(uint => ChangeTrustedAddressProposal)) public changeTrustedAddressProposals;
    mapping(uint => UpgradeContractsProposal) public upgradeContractsProposals;
    mapping(uint => mapping(uint => address)) public addBurnAddressProposals;
    mapping(uint => address[]) public burnAddresses;

    uint public nextProjectId;

    event ExecuteProposal(uint projectId, uint proposalId);
    event CreateProject(uint contractProjectId, string dbProjectId, address tokenAddress);
    event ChangeTrustedAddress(uint projectId, uint proposalId, uint32 contractIndex, address trustedAddress);
    event ContractsUpgraded(uint projectId, uint proposalId);
    event ChangeVotingTokenAddress(uint projectId, uint proposalId, address tokenAddress);

    struct UpgradeContractsProposal {
        address delegates;
        address fundsManager;
        address tokenSell;
        address proposal;
        address gasStation;
        address contractsManager;
    }

    struct ChangeTrustedAddressProposal {
        uint32 contractIndex;
        address trustedAddress;
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
        nextProjectId = 0;
    }

    function deleteExpiredProposals(uint projectId, uint[] memory ids, uint proposalType) external {
        (uint expirationPeriod,,) = proposalContract.parameters(0, keccak256("ExpirationPeriod"));
        for (uint i = 0; i < ids.length; i++) {
            (,uint256 endTime,,,) = proposalContract.proposals(projectId, ids[i]);
            if (endTime + expirationPeriod <= block.timestamp) {
                if (proposalType == CHANGE_TRUSTED_ADDRESS) {
                    delete changeTrustedAddressProposals[projectId][ids[i]];
                } else if (proposalType == CHANGE_VOTING_TOKEN_ADDRESS) {
                    delete changeVotingTokenProposals[projectId][ids[i]];
                } else if (proposalType == ADD_BURN_ADDRESS) {
                    delete addBurnAddressProposals[projectId][ids[i]];
                } else if (proposalType == UPGRADE_CONTRACTS) {
                    delete upgradeContractsProposals[projectId];
                }
                proposalContract.deleteProposal(projectId, ids[i]);
            }
        }
    }

    function getBurnAddresses(uint projectId) view external returns (address[] memory){
        return burnAddresses[projectId];
    }

    function burnedTokens(uint projectId, ERC20interface votingTokenContract) public view returns (uint) {
        uint amount = 0;
        for (uint i = 0; i < burnAddresses[projectId].length; i++) {
            amount += votingTokenContract.balanceOf(burnAddresses[projectId][i]);
        }
        return amount;
    }

    function votingTokenCirculatingSupply(uint projectId) public view returns (uint) {
        ERC20interface votingTokenContract = votingTokenContracts[projectId];
        return votingTokenContract.totalSupply()
        - votingTokenContract.balanceOf(BURN_ADDRESS)
        - burnedTokens(projectId, votingTokenContract)
        - votingTokenContract.balanceOf(address(fundsManagerContract));
    }

    function checkMinBalance(uint projectId, address addr) external view returns (bool) {
        uint required_amount = minimumRequiredAmount(projectId);
        return delegatesContract.checkVotingPower(projectId, addr, required_amount);
    }

    function minimumRequiredAmount(uint projectId) public view returns (uint) {
        (uint value,,) = proposalContract.parameters(projectId, keccak256("MaxNrOfDelegators"));
        return votingTokenCirculatingSupply(projectId) / value;
    }

    function createProject(string memory dbProjectId, address tokenContractAddress) external {
        proposalContract.initializeParameters(nextProjectId);
        burnAddresses[nextProjectId].push(BURN_ADDRESS);
        votingTokenContracts[nextProjectId] = ERC20interface(tokenContractAddress);
        emit CreateProject(nextProjectId, dbProjectId, tokenContractAddress);
        nextProjectId++;
    }

    function isTrustedAddress(uint projectId, address trustedAddress) view public returns (bool) {
        if (
            trustedAddress == address(delegatesContract) ||
            trustedAddress == address(fundsManagerContract) ||
            trustedAddress == address(tokenSellContract) ||
            trustedAddress == address(proposalContract) ||
            trustedAddress == address(gasStationContract) ||
            trustedAddress == address(contractsManagerContract) ||
            trustedAddress == address(votingTokenContracts[projectId])
        ) {
            return true;
        }
        for (uint i = 0; i < trustedAddresses[projectId].length; i++) {
            if (trustedAddresses[projectId][i] == trustedAddress) {
                return true;
            }
        }
        return false;
    }

    function proposeUpgradeContracts(
        address _delegates,
        address _fundsManager,
        address _tokenSell,
        address _proposal,
        address _gasStation,
        address _contractsManager) external {
        upgradeContractsProposals[proposalContract.nextProposalId(0)].delegates = _delegates;
        upgradeContractsProposals[proposalContract.nextProposalId(0)].fundsManager = _fundsManager;
        upgradeContractsProposals[proposalContract.nextProposalId(0)].tokenSell = _tokenSell;
        upgradeContractsProposals[proposalContract.nextProposalId(0)].proposal = _proposal;
        upgradeContractsProposals[proposalContract.nextProposalId(0)].gasStation = _gasStation;
        upgradeContractsProposals[proposalContract.nextProposalId(0)].contractsManager = _contractsManager;
        proposalContract.createProposal(0, UPGRADE_CONTRACTS, msg.sender);
    }

    function proposeChangeTrustedAddress(uint projectId, uint32 contractIndex, address trustedAddress) external {
        require(trustedAddress != address(0x0), "Contract address can't be 0x0");
        changeTrustedAddressProposals[projectId][proposalContract.nextProposalId(projectId)].contractIndex = contractIndex;
        changeTrustedAddressProposals[projectId][proposalContract.nextProposalId(projectId)].trustedAddress = trustedAddress;
        proposalContract.createProposal(projectId, CHANGE_TRUSTED_ADDRESS, msg.sender);
    }

    function proposeChangeVotingToken(uint projectId, address tokenAddress) external {
        require(tokenAddress != address(0x0), "Contract address can't be 0x0");
        changeVotingTokenProposals[projectId][proposalContract.nextProposalId(projectId)] = tokenAddress;
        proposalContract.createProposal(projectId, CHANGE_VOTING_TOKEN_ADDRESS, msg.sender);
    }

    function proposeAddBurnAddress(uint projectId, address burnAddress) external {
        addBurnAddressProposals[projectId][proposalContract.nextProposalId(projectId)] = burnAddress;
        proposalContract.createProposal(projectId, ADD_BURN_ADDRESS, msg.sender);
    }

    function executeProposal(uint projectId, uint proposalId) external {
        (uint32 typeOfProposal, uint256 endTime, , bool willExecute,) = proposalContract.proposals(projectId, proposalId);
        (uint expirationPeriod,,) = proposalContract.parameters(0, keccak256("ExpirationPeriod"));
        require(proposalId < proposalContract.nextProposalId(projectId), "Proposal does not exist");
        require(endTime <= block.timestamp, "Can't execute proposal, buffer time did not end yet");
        require(endTime + expirationPeriod >= block.timestamp, "Can't execute proposal, execute period has expired");
        require(willExecute, "Can't execute, proposal was rejected or vote count was not locked");
        proposalContract.setWillExecute(projectId, proposalId, false);

        if (typeOfProposal == CHANGE_TRUSTED_ADDRESS) {
            ChangeTrustedAddressProposal memory p = changeTrustedAddressProposals[projectId][proposalId];
            trustedAddresses[projectId].push(p.trustedAddress);
            emit ChangeTrustedAddress(projectId, proposalId, p.contractIndex, p.trustedAddress);
            proposalContract.deleteProposal(projectId, proposalId);
            delete changeTrustedAddressProposals[projectId][proposalId];
        }
        else if (typeOfProposal == CHANGE_VOTING_TOKEN_ADDRESS) {
            votingTokenContracts[projectId] = ERC20interface(changeVotingTokenProposals[projectId][proposalId]);
            emit ChangeVotingTokenAddress(projectId, proposalId, changeVotingTokenProposals[projectId][proposalId]);
            proposalContract.deleteProposal(projectId, proposalId);
            delete changeVotingTokenProposals[projectId][proposalId];
        } else if (typeOfProposal == ADD_BURN_ADDRESS) {
            burnAddresses[projectId].push(addBurnAddressProposals[projectId][proposalId]);
            proposalContract.deleteProposal(projectId, proposalId);
            delete addBurnAddressProposals[projectId][proposalId];
        } else if (typeOfProposal == UPGRADE_CONTRACTS) {
            if (upgradeContractsProposals[proposalId].delegates != address(0x0)) {
                ITransparentUpgradeableProxy(address(delegatesContract)).upgradeTo(upgradeContractsProposals[proposalId].delegates);
            }
            if (upgradeContractsProposals[proposalId].fundsManager != address(0x0)) {
                ITransparentUpgradeableProxy(address(fundsManagerContract)).upgradeTo(upgradeContractsProposals[proposalId].fundsManager);
            }
            if (upgradeContractsProposals[proposalId].tokenSell != address(0x0)) {
                ITransparentUpgradeableProxy(address(tokenSellContract)).upgradeTo(upgradeContractsProposals[proposalId].tokenSell);
            }
            if (upgradeContractsProposals[proposalId].proposal != address(0x0)) {
                ITransparentUpgradeableProxy(address(proposalContract)).upgradeTo(upgradeContractsProposals[proposalId].proposal);
            }
            if (upgradeContractsProposals[proposalId].gasStation != address(0x0)) {
                ITransparentUpgradeableProxy(address(gasStationContract)).upgradeTo(upgradeContractsProposals[proposalId].gasStation);
            }
            if (upgradeContractsProposals[proposalId].contractsManager != address(0x0)) {
                ITransparentUpgradeableProxy(address(contractsManagerContract)).upgradeTo(upgradeContractsProposals[proposalId].contractsManager);
            }
            emit ContractsUpgraded(projectId, proposalId);
            proposalContract.deleteProposal(0, proposalId);
            delete upgradeContractsProposals[proposalId];
        } else {
            revert('Unexpected proposal type');
        }
        emit ExecuteProposal(projectId, proposalId);
    }
}
