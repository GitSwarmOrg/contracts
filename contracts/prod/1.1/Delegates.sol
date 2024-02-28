// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;

import "./base/ERC20interface.sol";
import "./base/Common.sol";

contract Delegates is Common, Initializable, IDelegates {

    // key - delegated address, value - array of delegateOf address
    mapping(uint => mapping(address => address[])) public delegations;
    // key - delegator address, value - delegated address
    mapping(uint => mapping(address => address)) public delegateOf;

    modifier hasMinBalance (uint projectId, address addr) {
        require(contractsManagerContract.hasMinBalance(projectId, addr),
            "Not enough voting power.");
        _;
    }

    event DelegationEvent(address delegator, address delegate);
    event UndelegationEvent(address delegator, address delegate);
    event UndelegateAllFromSelfEvent(address sender);

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

    function getDelegatorsOf(uint projectId, address delegatedAddress) view public returns (address[] memory){
        return delegations[projectId][delegatedAddress];
    }

    function getDelegatedVotingPower(uint projectId, address delegatedAddr) external view returns (uint delegatedVotes) {
        ERC20interface tokenContract = contractsManagerContract.votingTokenContracts(projectId);
        address[] memory delegatesOfDelegatedAddr = getDelegatorsOf(projectId, delegatedAddr);
        delegatedVotes = 0;
        for (uint i = 0; i < delegatesOfDelegatedAddr.length; i++) {
            if (delegatesOfDelegatedAddr[i] != address(0)) {
                delegatedVotes += tokenContract.balanceOf(delegatesOfDelegatedAddr[i]);
            }
        }
    }

    function checkVotingPower(uint projectId, address addr, uint minVotingPower) public view returns (bool) {
        ERC20interface tokenContract = contractsManagerContract.votingTokenContracts(projectId);
        uint delegatedPower = tokenContract.balanceOf(addr);
        if (delegatedPower >= minVotingPower) {
            return true;
        }
        address[] memory first_level_delegates = delegations[projectId][addr];
        for (uint i = 0; i < first_level_delegates.length; i++) {
            if (first_level_delegates[i] != address(0)) {
                delegatedPower += tokenContract.balanceOf(first_level_delegates[i]);
                if (delegatedPower >= minVotingPower) {
                    return true;
                }
            }
        }
        return false;
    }

    function removeIfAlreadyDelegated(uint projectId) private {
        if (delegateOf[projectId][msg.sender] != address(0)) {
            undelegate(projectId);
        }
    }

    function delegate(uint projectId, address delegatedAddr) hasMinBalance(projectId, msg.sender) external {
        require(delegatedAddr != msg.sender && delegateOf[projectId][delegatedAddr] != msg.sender,
            "Can't delegate to yourself");
        //check if it is already delegated
        removeIfAlreadyDelegated(projectId);

        delegations[projectId][delegatedAddr].push(msg.sender);
        delegateOf[projectId][msg.sender] = delegatedAddr;
        emit DelegationEvent(msg.sender, delegatedAddr);
    }

    function undelegate(uint projectId) public {
        undelegateAddress(projectId, msg.sender);
    }

    function undelegateAddress(uint projectId, address addr) private {
        address[] storage delegates_array = delegations[projectId][delegateOf[projectId][addr]];
        for (uint i = 0; i < delegates_array.length; i++) {
            if (delegates_array[i] == addr) {
                //when the entry is removed, copy the last element into its position and reduce the length by 1
                delegates_array[i] = delegates_array[delegates_array.length - 1];
                delegates_array.pop();
                break;
            }
        }
        emit UndelegationEvent(addr, delegateOf[projectId][addr]);
        delete delegateOf[projectId][addr];
    }

    function undelegateAllFromAddress(uint projectId) external {
        for (uint i = delegations[projectId][msg.sender].length; i > 0; i--) {
            delete delegateOf[projectId][delegations[projectId][msg.sender][i - 1]];
            delegations[projectId][msg.sender].pop();
        }
        emit UndelegateAllFromSelfEvent(msg.sender);
    }

    function removeSpamDelegates(uint projectId, address[] memory addresses, uint[] memory indexes) external {
        uint minimum_amount = contractsManagerContract.votingTokenCirculatingSupply(projectId) /
                            proposalContract.parameters(projectId, keccak256("MaxNrOfDelegators"));
        for (uint ii = addresses.length; ii > 0; ii--) {
            uint i = ii - 1;
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

    function getSpamDelegates(uint projectId, address delegatedAddr) external view returns (address [] memory, uint [] memory) {
        uint minimum_amount = contractsManagerContract.votingTokenCirculatingSupply(projectId) /
                            proposalContract.parameters(projectId, keccak256("MaxNrOfDelegators"));
        address[] storage delegates_array = delegations[projectId][delegatedAddr];
        address[] memory addresses = new address[](250);
        uint[] memory indexes = new uint[](250);
        uint index = 0;

        for (uint i = 0; i < delegates_array.length; i++) {
            if (!checkVotingPower(projectId, delegates_array[i], minimum_amount)) {
                addresses[index] = delegates_array[i];
                indexes[index] = i;
                index++;
                if (index == 250) {
                    return (addresses, indexes);
                }
            }
        }
        return (addresses, indexes);
    }
}
