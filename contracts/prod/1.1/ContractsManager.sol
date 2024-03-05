// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;

import "./base/Common.sol";
import "./base/ERC20interface.sol";
import "./base/MyTransparentUpgradeableProxy.sol";
import "../../openzeppelin-v5.0.1/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../../openzeppelin-v5.0.1/proxy/transparent/ProxyAdmin.sol";


contract ContractsManager is Common, Initializable, IContractsManager {

    mapping(uint => ERC20interface) public votingTokenContracts;
    // Trusted addresses per project, may include other contracts or external addresses.
    // They can call any restricted methods and enables them to send funds without proposals:
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
    event AddBurnAddress(address burnAddress);

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
        - burnedTokens(projectId, votingTokenContract)
            - votingTokenContract.balanceOf(address(fundsManagerContract));
    }

//  only addresses that have the required minimum balance can create a proposal
    function hasMinBalance(uint projectId, address addr) external view returns (bool) {
//      gitswarm is exempt, used for payroll proposals
        if (addr == proposalContract.gitswarmAddress()) {
            return true;
        }
        uint required_amount = minimumRequiredAmount(projectId);
        return delegatesContract.checkVotingPower(projectId, addr, required_amount);
    }

    // minimum required amount for voting on/creating a proposal
    function minimumRequiredAmount(uint projectId) public view returns (uint) {
        return votingTokenCirculatingSupply(projectId) /
            proposalContract.parameters(projectId, keccak256("MaxNrOfDelegators"));
    }

    function createProject(string memory dbProjectId, address tokenContractAddress, bool checkErc20) public {
        require(tokenContractAddress != address(0), "Contract address can't be 0x0");
        if (checkErc20) {
            require(isERC20Token(tokenContractAddress), "Address is not an ERC20 token contract");
        }
        proposalContract.initializeParameters(nextProjectId);
        burnAddresses[nextProjectId].push(BURN_ADDRESS);
        votingTokenContracts[nextProjectId] = ERC20interface(tokenContractAddress);
        emit CreateProject(nextProjectId, dbProjectId, tokenContractAddress);
        nextProjectId++;
    }

    function createProject(string memory dbProjectId, address tokenContractAddress) external {
       createProject(dbProjectId, tokenContractAddress, true);
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
        upgradeContractsProposals[proposalContract.nextProposalId(0)] = UpgradeContractsProposal({delegates: _delegates,
            fundsManager: _fundsManager,
            tokenSell: _tokenSell,
            proposal: _proposal,
            gasStation: _gasStation,
            contractsManager: _contractsManager});
        proposalContract.createProposal(0, UPGRADE_CONTRACTS, msg.sender);
    }

    function proposeChangeTrustedAddress(uint projectId, uint32 contractIndex, address trustedAddress) external {
        require(contractIndex >= 0 && contractIndex <= trustedAddresses[projectId].length, "contractIndex out of bounds");
        changeTrustedAddressProposals[projectId][proposalContract.nextProposalId(projectId)] = ChangeTrustedAddressProposal({
            contractIndex: contractIndex,
            trustedAddress: trustedAddress});
        proposalContract.createProposal(projectId, CHANGE_TRUSTED_ADDRESS, msg.sender);
    }

    function isERC20Token(address _addr) public view returns (bool) {
        address dummyAddress = 0x0000000000000000000000000000000000000000;

        if (_addr.code.length == 0) {
            return false;
        }

        try ERC20interface(_addr).name() {} catch {return false;}
        try ERC20interface(_addr).symbol() {} catch {return false;}
        try ERC20interface(_addr).decimals() {} catch {return false;}
        try ERC20interface(_addr).totalSupply() {} catch {return false;}
        try ERC20interface(_addr).balanceOf(dummyAddress) {} catch {return false;}
        try ERC20interface(_addr).allowance(dummyAddress, dummyAddress) {} catch {return false;}

        return true;
    }

    function proposeChangeVotingToken(uint projectId, address tokenAddress) external {
        require(tokenAddress != address(0), "Contract address can't be 0x0");
        require(isERC20Token(tokenAddress), "Address is not an ERC20 token contract");
        changeVotingTokenProposals[projectId][proposalContract.nextProposalId(projectId)] = tokenAddress;
        proposalContract.createProposal(projectId, CHANGE_VOTING_TOKEN_ADDRESS, msg.sender);
    }

    function proposeAddBurnAddress(uint projectId, address burnAddress) external {
        addBurnAddressProposals[projectId][proposalContract.nextProposalId(projectId)] = burnAddress;
        proposalContract.createProposal(projectId, ADD_BURN_ADDRESS, msg.sender);
    }

    function executeProposal(uint projectId, uint proposalId) external {
        (uint32 typeOfProposal, , bool willExecute,, uint256 endTime) = proposalContract.proposals(projectId, proposalId);
        uint expirationPeriod = proposalContract.parameters(0, keccak256("ExpirationPeriod"));
        require(proposalId < proposalContract.nextProposalId(projectId), "Proposal does not exist");
        require(endTime <= block.timestamp, "Can't execute proposal, buffer time did not end yet");
        require(endTime + expirationPeriod >= block.timestamp, "Can't execute proposal, execute period has expired");
        require(willExecute, "Can't execute, proposal was rejected or vote count was not locked");
        proposalContract.setWillExecute(projectId, proposalId, false);

        if (typeOfProposal == CHANGE_TRUSTED_ADDRESS) {
            ChangeTrustedAddressProposal memory p = changeTrustedAddressProposals[projectId][proposalId];
            address[] storage ta = trustedAddresses[projectId];
            if (p.trustedAddress != address(0)) {
                if (p.contractIndex == ta.length) {
                    ta.push(p.trustedAddress);
                } else {
                    ta[p.contractIndex] = p.trustedAddress;
                }
            } else {
                require(ta.length > 0, "No element in trustedAddress array.");
                ta[p.contractIndex] = ta[ta.length - 1];
                ta.pop();
            }

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
            address newBurnAddress = addBurnAddressProposals[projectId][proposalId];
            for (uint i = 0; i < burnAddresses[projectId].length; i++) {
                if (burnAddresses[projectId][i] == newBurnAddress) {
                    revert("Duplicate burn address not allowed");
                }
            }

            emit AddBurnAddress(newBurnAddress);
            burnAddresses[projectId].push(newBurnAddress);
            proposalContract.deleteProposal(projectId, proposalId);
            delete addBurnAddressProposals[projectId][proposalId];
        } else if (typeOfProposal == UPGRADE_CONTRACTS) {

            if (upgradeContractsProposals[proposalId].delegates != address(0)) {
                ProxyAdmin(MyTransparentUpgradeableProxy(payable(address(delegatesContract))).proxyAdmin())
                .upgradeAndCall(ITransparentUpgradeableProxy(address(delegatesContract)),
                    upgradeContractsProposals[proposalId].delegates, "");
            }
            if (upgradeContractsProposals[proposalId].fundsManager != address(0)) {
                ProxyAdmin(MyTransparentUpgradeableProxy(payable(address(fundsManagerContract))).proxyAdmin())
                .upgradeAndCall(ITransparentUpgradeableProxy(address(fundsManagerContract)),
                    upgradeContractsProposals[proposalId].fundsManager, "");
            }
            if (upgradeContractsProposals[proposalId].tokenSell != address(0)) {
                ProxyAdmin(MyTransparentUpgradeableProxy(payable(address(tokenSellContract))).proxyAdmin())
                .upgradeAndCall(ITransparentUpgradeableProxy(address(tokenSellContract)),
                    upgradeContractsProposals[proposalId].tokenSell, "");
            }
            if (upgradeContractsProposals[proposalId].proposal != address(0)) {
                ProxyAdmin(MyTransparentUpgradeableProxy(payable(address(proposalContract))).proxyAdmin())
                .upgradeAndCall(ITransparentUpgradeableProxy(address(proposalContract)),
                    upgradeContractsProposals[proposalId].proposal, "");
            }
            if (upgradeContractsProposals[proposalId].gasStation != address(0)) {
                ProxyAdmin(MyTransparentUpgradeableProxy(payable(address(gasStationContract))).proxyAdmin())
                .upgradeAndCall(ITransparentUpgradeableProxy(address(gasStationContract)),
                    upgradeContractsProposals[proposalId].gasStation, "");
            }
            if (upgradeContractsProposals[proposalId].contractsManager != address(0)) {
                ProxyAdmin(MyTransparentUpgradeableProxy(payable(address(contractsManagerContract))).proxyAdmin())
                .upgradeAndCall(ITransparentUpgradeableProxy(address(contractsManagerContract)),
                    upgradeContractsProposals[proposalId].contractsManager, "");
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
