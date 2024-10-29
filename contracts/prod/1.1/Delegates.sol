// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.28;

import "./base/Common.sol";
/**
 * @title Delegates contract for managing delegations within a decentralized voting system.
 * @dev Inherits functionalities from `Common` and implements `IDelegates`.
 */
contract Delegates is Common, Initializable, IDelegates {

    /**
     * @notice Mapping of projectId to delegator address and their array of delegates.
     * @dev key - delegated address, value - array of delegateOf address
     */
    mapping(uint256 => mapping(address => address[])) public delegations;

    /**
     * @notice Mapping of projectId to delegator address to their delegated address.
     * @dev key - delegator address, value - delegated address
     */
    mapping(uint256 => mapping(address => address)) public delegateOf;

    /**
     * @notice Event emitted when a new delegation is made.
     * @param delegator Address of the delegator.
     * @param delegate Address of the delegate.
     */
    event DelegationEvent(address delegator, address delegate);

    /**
     * @notice Event emitted when a delegation is removed.
     * @param delegator Address of the delegator.
     * @param delegate Address of the delegate.
     */
    event UndelegationEvent(address delegator, address delegate);

    /**
     * @notice Event emitted when a delegate removes all delegations from themselves.
     * @param sender Address of the delegate performing the action.
     */
    event UndelegateAllFromSelfEvent(address sender);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract with necessary addresses and contracts.
     * @dev This function should be called once to initialize the contract after deployment.
     * @param _delegates Address of the Delegates contract.
     * @param _fundsManager Address of the FundsManager contract.
     * @param _parameters The address of the parameters contract.
     * @param _proposal Address of the Proposal contract.
     * @param _gasStation Address of the GasStation contract.
     * @param _contractsManager Address of the ContractsManager contract.
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
     * @notice Retrieves the addresses of delegators for a given delegate address and project.
     * @param projectId The ID of the project.
     * @param delegatedAddress The address of the delegate.
     * @return An array of addresses who have delegated to the given address for the specified project.
     */
    function getDelegatorsOf(uint256 projectId, address delegatedAddress) view public returns (address[] memory){
        return delegations[projectId][delegatedAddress];
    }

    /**
     * @notice Computes the total delegated voting power to a given address for a project.
     * @param projectId The ID of the project.
     * @param delegatedAddr The address whose total delegated voting power is being calculated.
     * @return delegatedVotingPower The total voting power delegated to the given address.
     */
    function getDelegatedVotingPower(uint256 projectId, address delegatedAddr) external view returns (uint256 delegatedVotingPower) {
        IERC20 tokenContract = contractsManagerContract.votingTokenContracts(projectId);
        address[] memory delegatesOfDelegatedAddr = getDelegatorsOf(projectId, delegatedAddr);
        delegatedVotingPower = 0;
        for (uint256 i = 0; i < delegatesOfDelegatedAddr.length; i++) {
            delegatedVotingPower += tokenContract.balanceOf(delegatesOfDelegatedAddr[i]);
        }
    }

    /**
     * @notice Checks if an address has at least a specified amount of voting power for a project, including delegated power.
     * @param projectId The ID of the project.
     * @param addr The address to check voting power for.
     * @param minVotingPower The minimum amount of voting power required.
     * @return True if the address has at least the specified amount of voting power, false otherwise.
     */
    function checkVotingPower(uint256 projectId, address addr, uint256 minVotingPower) public view returns (bool) {
        IERC20 tokenContract = contractsManagerContract.votingTokenContracts(projectId);
        uint256 delegatedPower = tokenContract.balanceOf(addr);
        if (delegatedPower >= minVotingPower) {
            return true;
        }
        address[] memory _delegations = delegations[projectId][addr];
        for (uint256 i = 0; i < _delegations.length; i++) {
            delegatedPower += tokenContract.balanceOf(_delegations[i]);
            if (delegatedPower >= minVotingPower) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Removes the current delegation for a sender if it exists, to allow for a new delegation.
     * @param projectId The ID of the project for which the delegation is being removed.
     */
    function removeIfAlreadyDelegated(uint256 projectId) private {
        if (delegateOf[projectId][msg.sender] != address(0)) {
            undelegate(projectId);
        }
    }

    /**
     * @notice Delegates the voting power of the caller to a specified address.
     * @param projectId The ID of the project.
     * @param delegatedAddr The address to which the caller's voting power is being delegated.
     */
    function delegate(uint256 projectId, address delegatedAddr) external {
        IERC20 tokenContract = contractsManagerContract.votingTokenContracts(projectId);
        require(delegatedAddr != msg.sender && delegateOf[projectId][delegatedAddr] != msg.sender,
            "Can't delegate to yourself");
        uint256 minVotingPower = contractsManagerContract.minimumRequiredAmount(projectId);
        require(tokenContract.balanceOf(msg.sender) >= minVotingPower, "Not enough direct voting power");

        //check if it is already delegated
        removeIfAlreadyDelegated(projectId);

        delegations[projectId][delegatedAddr].push(msg.sender);
        delegateOf[projectId][msg.sender] = delegatedAddr;
        emit DelegationEvent(msg.sender, delegatedAddr);
    }

    /**
     * @notice Removes the delegation for the caller's address.
     * @param projectId The ID of the project for which the delegation is being removed.
     */
    function undelegate(uint256 projectId) public {
        undelegateAddress(projectId, msg.sender);
    }

    /**
     * @notice Removes the delegation for a specified address.
     * @param projectId The ID of the project.
     * @param addr The address for which the delegation is being removed.
     */
    function undelegateAddress(uint256 projectId, address addr) private {
        address[] storage delegates_array = delegations[projectId][delegateOf[projectId][addr]];
        uint256 l = delegates_array.length;
        for (uint256 i = 0; i < l; i++) {
            if (delegates_array[i] == addr) {
                // When the entry is removed, copy the last element into its position and reduce the length by 1
                delegates_array[i] = delegates_array[l - 1];
                delegates_array.pop();
                break;
            }
        }
        emit UndelegationEvent(addr, delegateOf[projectId][addr]);
        delete delegateOf[projectId][addr];
    }

    /**
     * @notice Removes all delegations from the caller to other addresses for a specific project.
     * @param projectId The ID of the project.
     */
    function undelegateAllFromAddress(uint256 projectId) external {
        address[] storage d = delegations[projectId][msg.sender];
        for (uint256 i = d.length; i > 0; i--) {
            delete delegateOf[projectId][d[i - 1]];
            d.pop();
        }
        emit UndelegateAllFromSelfEvent(msg.sender);
    }

    /**
     * @notice Removes delegates deemed as spam based on a minimum voting power threshold.
     * @param projectId The ID of the project.
     * @param addresses Array of delegate addresses to check and potentially remove.
     * @param indexes Array of indexes corresponding to the delegate addresses in the project's delegation list.
     */
    function removeSpamDelegates(uint256 projectId, address[] calldata addresses, uint256[] calldata indexes) external {
        uint256 minimum_amount = contractsManagerContract.votingTokenCirculatingSupply(projectId) /
                            parametersContract.parameters(projectId, keccak256("MaxNrOfVoters"));
        require(addresses.length == indexes.length, "addresses and indexes must have same length");
        for (uint256 ii = addresses.length; ii > 0; ii--) {
            uint256 i = ii - 1;
            if (!checkVotingPower(projectId, addresses[i], minimum_amount)) {
                address[] storage current_delegates = delegations[projectId][delegateOf[projectId][addresses[i]]];
                require(addresses[i] == current_delegates[indexes[i]], "Wrong index for address.");
                current_delegates[indexes[i]] = current_delegates[current_delegates.length - 1];
                current_delegates.pop();
                emit UndelegationEvent(addresses[i], delegateOf[projectId][addresses[i]]);
                delete delegateOf[projectId][addresses[i]];
            }
        }
    }

    /**
     * @notice Retrieves delegates deemed as spam for a specific address and project based on a minimum voting power threshold.
     * @param projectId The ID of the project.
     * @param delegatedAddr The address whose delegates are being checked.
     * @return addresses Array of spam delegate addresses.
     * @return indexes Array of indexes corresponding to the spam delegate addresses in the project's delegation list.
     */
    function getSpamDelegates(uint256 projectId, address delegatedAddr) external view returns (address[] memory, uint256[] memory) {
        uint256 minimum_amount = contractsManagerContract.votingTokenCirculatingSupply(projectId) /
                            parametersContract.parameters(projectId, keccak256("MaxNrOfVoters"));
        address[] storage delegates_array = delegations[projectId][delegatedAddr];
        uint256 l = delegates_array.length;
        address[] memory addresses = new address[](l);
        uint256[] memory indexes = new uint256[](l);
        uint256 index = 0;
        for (uint256 i = 0; i < l; i++) {
            if (!checkVotingPower(projectId, delegates_array[i], minimum_amount)) {
                addresses[index] = delegates_array[i];
                indexes[index] = i;
                index++;
            }
        }
        // Resize the arrays to the actual number of valid addresses found
        assembly {
            mstore(addresses, index)
            mstore(indexes, index)
        }
        return (addresses, indexes);
    }
}
