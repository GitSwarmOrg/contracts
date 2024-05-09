// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;

import "./base/Common.sol";
import "./base/MyTransparentUpgradeableProxy.sol";
import "../../openzeppelin-v5.0.1/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../../openzeppelin-v5.0.1/proxy/transparent/ProxyAdmin.sol";
import "../../openzeppelin-v5.0.1/token/ERC20/IERC20.sol";

/**
 * @title Contracts Manager for Governance
 * @notice Manages governance-related contract functionalities including upgrade, trusted addresses,
 * changing voting tokens and burn addresses through proposals.
 */
contract ContractsManager is Common, Initializable, IContractsManager {

    /// Maps project IDs to their associated ERC20 voting token contracts
    mapping(uint => IERC20) public votingTokenContracts;

    /// Stores proposals for changing the voting token of a project
    mapping(uint => mapping(uint => address)) public changeVotingTokenProposals;

    /// Stores proposals for upgrading contracts associated with a project
    mapping(uint => UpgradeContractsProposal) public upgradeContractsProposals;

    /// Stores proposals for adding new burn addresses for a project
    mapping(uint => mapping(uint => address)) public addBurnAddressProposals;

    /// Stores burn addresses for each project,
    /// which are addresses where tokens can be sent to be considered "burned" or removed from circulation
    mapping(uint => address[]) public burnAddresses;

    /// Counter for the next project ID to be assigned
    uint public nextProjectId;

    /**
     * @dev Emitted when a proposal is executed for a project.
     * @param projectId The ID of the project related to the proposal.
     * @param proposalId The ID of the proposal that was executed.
     */
    event ExecuteProposal(uint projectId, uint proposalId);

    /**
     * @dev Emitted when a new project is created.
     * @param contractProjectId The project ID assigned to the new project.
     * @param dbProjectId The database ID of the new project.
     * @param tokenAddress The ERC20 voting token address associated with the new project.
     */
    event CreateProject(uint contractProjectId, string dbProjectId, address tokenAddress);

    /**
     * @dev Emitted when contracts associated with a project are upgraded.
     * @param projectId The ID of the project whose contracts were upgraded.
     * @param proposalId The ID of the proposal that initiated the upgrade.
     */
    event ContractsUpgraded(uint projectId, uint proposalId);

    /**
     * @dev Emitted when the voting token address is changed for a project.
     * @param projectId The ID of the project for which the voting token address was changed.
     * @param proposalId The ID of the proposal that initiated the change.
     * @param tokenAddress The new voting token address.
     */
    event ChangeVotingTokenAddress(uint projectId, uint proposalId, address tokenAddress);

    /**
     * @dev Emitted when a burn address is added for a project.
     * @param burnAddress The burn address that was added.
     */
    event AddBurnAddress(address burnAddress);

    /**
     * @notice A proposal structure for upgrading contracts.
     * @dev Used to store addresses of the new contract versions for a project upgrade proposal.
     */
    struct UpgradeContractsProposal {
        address delegates;
        address fundsManager;
        address parameters;
        address proposal;
        address gasStation;
        address contractsManager;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract with given addresses for various roles and functionalities.
     * @dev Marks the contract as initialized and sets up essential components and roles.
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
        nextProjectId = 0;
    }

    /**
     * @notice Retrieves the burn addresses for a given project.
     * @param projectId The ID of the project for which to retrieve burn addresses.
     * @return An array of burn addresses associated with the specified project.
     */
    function getBurnAddresses(uint projectId) view external returns (address[] memory){
        return burnAddresses[projectId];
    }

    /**
     * @notice Calculates the total amount of tokens burned for a project.
     * @param projectId The ID of the project for which to calculate burned tokens.
     * @param votingTokenContract The ERC20 voting token contract associated with the project.
     * @return The total amount of tokens burned.
     */
    function burnedTokens(uint projectId, IERC20 votingTokenContract) public view returns (uint) {
        uint amount = 0;
        for (uint i = 0; i < burnAddresses[projectId].length; i++) {
            amount += votingTokenContract.balanceOf(burnAddresses[projectId][i]);
        }
        return amount;
    }

    /**
     * @notice Calculates the circulating supply of the voting token for a given project, excluding burned tokens and tokens held by the funds manager.
     * @param projectId The ID of the project.
     * @return The circulating supply of the project's voting token.
     */
    function votingTokenCirculatingSupply(uint projectId) public view returns (uint) {
        IERC20 votingTokenContract = votingTokenContracts[projectId];
        return votingTokenContract.totalSupply()
        - burnedTokens(projectId, votingTokenContract)
            - votingTokenContract.balanceOf(address(fundsManagerContract));
    }

    /**
     * @notice Checks if an address holds the minimum required balance of the voting token to create a proposal.
     * @dev Special exemption for the GitSwarm address, used for payroll proposals.
     * @param projectId The ID of the project.
     * @param addr The address to check.
     * @return True if the address holds the minimum required balance, false otherwise.
     */
    function hasMinBalance(uint projectId, address addr) external view returns (bool) {
        if (addr == parametersContract.gitswarmAddress()) {
            // GitSwarm is exempt, used for payroll proposals
            return true;
        }
        uint required_amount = minimumRequiredAmount(projectId);
        return delegatesContract.checkVotingPower(projectId, addr, required_amount);
    }

    /**
     * @notice Determines the minimum required amount of voting tokens needed to create or vote on a proposal.
     * @param projectId The ID of the project.
     * @return The minimum required amount of voting tokens.
     */
    function minimumRequiredAmount(uint projectId) public view returns (uint) {
        return votingTokenCirculatingSupply(projectId) /
            parametersContract.parameters(projectId, keccak256("MaxNrOfVoters"));
    }

    /**
     * @notice Creates a new project with the given parameters.
     * @dev Adds the specified ERC20 token as the voting token for the new project and emits a `CreateProject` event.
     * @param dbProjectId The database ID of the project, used for external reference.
     * @param tokenContractAddress The address of the ERC20 token contract to be used as the voting token.
     * @param checkErc20 A flag indicating whether to validate the token contract as a compliant ERC20 token.
     */
    function createProject(string memory dbProjectId, address tokenContractAddress, bool checkErc20) public {
        require(tokenContractAddress != address(0), "Contract address can't be 0x0");
        if (checkErc20) {
            require(isERC20Token(tokenContractAddress), "Address is not an ERC20 token contract");
        }
        parametersContract.initializeParameters(nextProjectId);
        burnAddresses[nextProjectId].push(BURN_ADDRESS);
        votingTokenContracts[nextProjectId] = IERC20(tokenContractAddress);
        emit CreateProject(nextProjectId, dbProjectId, tokenContractAddress);
        nextProjectId++;
    }

    /**
     * @notice Overloaded function to create a new project with a default ERC20 token check.
     * @param dbProjectId The database identifier for the new project.
     * @param tokenContractAddress The ERC20 token contract address to be used as the voting token for the project.
     */
    function createProject(string memory dbProjectId, address tokenContractAddress) external {
        createProject(dbProjectId, tokenContractAddress, true);
    }

    /**
     * @notice Proposes an upgrade to the contracts associated with a project.
     * @dev The proposal will be recorded and can later be executed after a successful vote.
     * @param _delegates The address of the delegates contract.
     * @param _fundsManager The address of the funds manager contract.
     * @param _parameters The address of the parameters contract.
     * @param _proposal The address of the proposal contract.
     * @param _gasStation The address of the gas station contract.
     * @param _contractsManager The address of the contracts manager.
     */
    function proposeUpgradeContracts(
        address _delegates,
        address _fundsManager,
        address _parameters,
        address _proposal,
        address _gasStation,
        address _contractsManager) external {
        upgradeContractsProposals[proposalContract.nextProposalId(0)] = UpgradeContractsProposal({delegates: _delegates,
            fundsManager: _fundsManager,
            parameters: _parameters,
            proposal: _proposal,
            gasStation: _gasStation,
            contractsManager: _contractsManager});
        proposalContract.createProposal(0, UPGRADE_CONTRACTS, msg.sender);
    }

    /**
     * @notice Verifies if a given address is an ERC20 token contract.
     * @dev Attempts to call ERC20-specific functions to confirm compliance.
     * @param _addr The address to be verified.
     * @return True if the address implements the decimals methods totalSupply, balanceOf and allowance false otherwise.
     */
    function isERC20Token(address _addr) public view returns (bool) {
        address dummyAddress = 0x0000000000000000000000000000000000000000;

        if (_addr.code.length == 0) {
            return false;
        }

        try IERC20(_addr).totalSupply() {} catch {return false;}
        try IERC20(_addr).balanceOf(dummyAddress) {} catch {return false;}
        try IERC20(_addr).allowance(dummyAddress, dummyAddress) {} catch {return false;}

        return true;
    }

    /**
     * @notice Proposes a change in the voting token for a specific project.
     * @param projectId The ID of the project for which the voting token is to be changed.
     * @param tokenAddress The address of the new voting token contract.
     */
    function proposeChangeVotingToken(uint projectId, address tokenAddress) external {
        require(tokenAddress != address(0), "Contract address can't be 0x0");
        require(isERC20Token(tokenAddress), "Address is not an ERC20 token contract");
        changeVotingTokenProposals[projectId][proposalContract.nextProposalId(projectId)] = tokenAddress;
        proposalContract.createProposal(projectId, CHANGE_VOTING_TOKEN_ADDRESS, msg.sender);
    }

    /**
     * @notice Proposes the addition of a new burn address for a specific project.
     * @param projectId The ID of the project for which a burn address is to be added.
     * @param burnAddress The address to be added as a new burn address.
     */
    function proposeAddBurnAddress(uint projectId, address burnAddress) external {
        addBurnAddressProposals[projectId][proposalContract.nextProposalId(projectId)] = burnAddress;
        proposalContract.createProposal(projectId, ADD_BURN_ADDRESS, msg.sender);
    }

    /**
     * @notice Executes a proposal that has passed voting.
     * @dev This function handles various types of proposals by executing the corresponding changes.
     * @param projectId The ID of the project for which the proposal is executed.
     * @param proposalId The ID of the proposal to be executed.
     */
    function executeProposal(uint projectId, uint proposalId) external {
        (uint32 typeOfProposal, , bool willExecute,, uint256 endTime) = proposalContract.proposals(projectId, proposalId);
        uint expirationPeriod = parametersContract.parameters(projectId, keccak256("ExpirationPeriod"));
        require(proposalId < proposalContract.nextProposalId(projectId), "Proposal does not exist");
        require(endTime <= block.timestamp, "Can't execute proposal, buffer time did not end yet");
        require(endTime + expirationPeriod >= block.timestamp, "Can't execute proposal, execute period has expired");
        require(willExecute, "Can't execute, proposal was rejected or vote count was not locked");
        proposalContract.setWillExecute(projectId, proposalId, false);


        if (typeOfProposal == CHANGE_VOTING_TOKEN_ADDRESS) {
            votingTokenContracts[projectId] = IERC20(changeVotingTokenProposals[projectId][proposalId]);
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

            upgradeContract(address(delegatesContract), upgradeContractsProposals[proposalId].delegates);
            upgradeContract(address(fundsManagerContract), upgradeContractsProposals[proposalId].fundsManager);
            upgradeContract(address(parametersContract), upgradeContractsProposals[proposalId].parameters);
            upgradeContract(address(proposalContract), upgradeContractsProposals[proposalId].proposal);
            upgradeContract(address(gasStationContract), upgradeContractsProposals[proposalId].gasStation);
            upgradeContract(address(contractsManagerContract), upgradeContractsProposals[proposalId].contractsManager);

            emit ContractsUpgraded(projectId, proposalId);
            proposalContract.deleteProposal(0, proposalId);
            delete upgradeContractsProposals[proposalId];
        } else {
            revert('Unexpected proposal type');
        }
        emit ExecuteProposal(projectId, proposalId);
    }

    function upgradeContract(address contractAddr, address newImplementation) private {
        if (newImplementation != address(0)) {
            ProxyAdmin admin = ProxyAdmin(MyTransparentUpgradeableProxy(payable(contractAddr)).proxyAdmin());
            admin.upgradeAndCall(ITransparentUpgradeableProxy(contractAddr), newImplementation, "");
        }
    }
}
