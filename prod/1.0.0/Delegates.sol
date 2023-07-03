// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity ^0.8.0;

import "../../openzeppelin-v4.9.0/proxy/utils/Initializable.sol";
import "./base/ERC20interface.sol";
import "./base/Common.sol";

contract Delegates is Common, Initializable, IDelegates {

    // key - delegated address, value - array of delegators address
    mapping(uint => mapping(address => address[])) public delegates;
    // key - delegator address, value - delegated address
    mapping(uint => mapping(address => address)) public delegators;

    modifier hasMinBalance (uint projectId, address addr) {
        require(contractsManagerContract.checkMinBalance(projectId, addr),
            "Not enough voting power.");
        _;
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
    }

    function getDelegates(uint projectId, address delegatedAddress) view public returns (address[] memory){
        return delegates[projectId][delegatedAddress];
    }

    function countDelegatedVotes(uint projectId, address delegatedAddr) external view returns (uint delegatedVotes) {
        ERC20interface tokenContract = contractsManagerContract.votingTokenContracts(projectId);
        address[] memory delegatesOfDelegatedAddr = getDelegates(projectId, delegatedAddr);
        delegatedVotes = 0;
        for (uint i = 0; i < delegatesOfDelegatedAddr.length; i++) {
            if (delegatesOfDelegatedAddr[i] != address(0)) {
                delegatedVotes += tokenContract.balanceOf(delegatesOfDelegatedAddr[i]);
                //check second level(actual accounts with tokens)
                address[] memory second_level_delegates = getDelegates(projectId, delegatesOfDelegatedAddr[i]);
                for (uint j = 0; j < second_level_delegates.length; j++) {
                    if (second_level_delegates[j] != address(0)) {
                        delegatedVotes += tokenContract.balanceOf(second_level_delegates[j]);
                    }
                }
            }
        }
    }

    function checkVotingPower(uint projectId, address addr, uint minVotingPower) public view returns (bool) {
        ERC20interface tokenContract = contractsManagerContract.votingTokenContracts(projectId);
        uint delegatedPower = tokenContract.balanceOf(addr);
        if (delegatedPower >= minVotingPower) {
            return true;
        }
        address[] memory first_level_delegates = delegates[projectId][addr];
        for (uint i = 0; i < first_level_delegates.length; i++) {
            if (first_level_delegates[i] != address(0)) {
                delegatedPower += tokenContract.balanceOf(first_level_delegates[i]);
                if (delegatedPower >= minVotingPower) {
                    return true;
                }
                //check second level(actual accounts with tokens)
                address[] memory second_level_delegates = delegates[projectId][first_level_delegates[i]];
                for (uint j = 0; j < second_level_delegates.length; j++) {
                    if (second_level_delegates[j] != address(0)) {
                        delegatedPower += tokenContract.balanceOf(second_level_delegates[j]);
                        if (delegatedPower >= minVotingPower) {
                            return true;
                        }
                    }
                }
            }
        }
        return false;
    }

    function removeIfAlreadyDelegated(uint projectId) private {
        if (delegators[projectId][msg.sender] != address(0)) {
            undelegate(projectId);
        }
    }

    function delegate(uint projectId, address delegatedAddr) hasMinBalance(projectId, msg.sender) external {
        require(delegatedAddr != msg.sender && delegators[projectId][delegatedAddr] != msg.sender,
            "Can't delegate to yourself");
        //check if it is already delegated
        removeIfAlreadyDelegated(projectId);

        delegates[projectId][delegatedAddr].push(msg.sender);
        delegators[projectId][msg.sender] = delegatedAddr;
    }

    function undelegate(uint projectId) public {
        undelegateAddress(projectId, msg.sender);
    }

    function undelegateAddress(uint projectId, address addr) private {
        //when the entry is removed, copy the last element in it's position and reduce the length with 1
        address[] storage delegates_array = delegates[projectId][delegators[projectId][addr]];
        for (uint i = 0; i < delegates_array.length; i++) {
            if (delegates_array[i] == addr) {
                delegates_array[i] = delegates_array[delegates_array.length - 1];
                delegates_array.pop();
                break;
            }
        }
        delete delegators[projectId][addr];
    }

    function undelegateAllFromAddress(uint projectId) external {
        for (uint i = delegates[projectId][msg.sender].length; i > 0; i--) {
            delete delegators[projectId][delegates[projectId][msg.sender][i - 1]];
            delegates[projectId][msg.sender].pop();
        }
    }

    function removeUnwantedDelegates(uint projectId, address[] memory addresses, uint[] memory indexes) external {
        (uint value,,) = proposalContract.parameters(projectId, keccak256("MaxNrOfDelegators"));
        uint minimum_amount = contractsManagerContract.votingTokenCirculatingSupply(projectId) / value;

        for (uint ii = addresses.length; ii > 0; ii--) {
            uint i = ii - 1;
            if (!checkVotingPower(projectId, addresses[i], minimum_amount)) {
                address[] storage current_delegates = delegates[projectId][delegators[projectId][addresses[i]]];
                require(addresses[i] == current_delegates[indexes[i]], "Wrong index for address.");
                current_delegates[indexes[i]] = current_delegates[current_delegates.length - 1];
                current_delegates.pop();
                delete delegators[projectId][addresses[i]];
            }
        }
    }

    function getUnwantedDelegates(uint projectId, address delegatedAddr) external view returns (address  [] memory, uint [] memory) {
        (uint value, ,) = proposalContract.parameters(projectId, keccak256("MaxNrOfDelegators"));
        uint minimum_amount = contractsManagerContract.votingTokenCirculatingSupply(projectId) / value;
        address[] storage delegates_array = delegates[projectId][delegatedAddr];
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
            address[] memory second_level_delegates = getDelegates(projectId, delegates_array[i]);
            for (uint j = 0; j < second_level_delegates.length; j++) {
                if (!checkVotingPower(projectId, second_level_delegates[j], minimum_amount)) {
                    addresses[index] = second_level_delegates[j];
                    indexes[index] = j;
                    index++;
                    if (index == 250) {
                        return (addresses, indexes);
                    }
                }
            }

        }
        return (addresses, indexes);
    }
}
