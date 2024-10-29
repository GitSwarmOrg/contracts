// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.28;

import "./base/ERC20Base.sol";
import {FundsManager} from "./FundsManager.sol";
//import "hardhat/console.sol";

/**
 * @title Fixed Supply Token Contract
 * @dev This contract implements a token with a fixed supply.
 * It is deployed when a user wants to create a new token with a fixed amount.
 * @notice Deploy this contract for creating a token with a fixed supply.
 */
contract FixedSupplyToken is ERC20Base {
    uint256 immutable public projectId;
    /**
     * @param prjId The project ID for the new token.
     * @param creatorSupply The portion of the supply allocated to the creator.
     * @param contractsManagerAddress Address of the Contracts Manager.
     * @param fundsManagerContractAddress Address of the Funds Manager Contract.
     * @param proposalContractAddress Address of the Proposal Contract.
     * @param tokenName The name of the token.
     * @param tokenSymbol The symbol of the token.
     *
     */
    constructor(
        string memory prjId,
        uint256 creatorSupply,
        address contractsManagerAddress,
        address fundsManagerContractAddress,
        address proposalContractAddress,
        address parametersContractAddress,
        string memory tokenName,
        string memory tokenSymbol
    ) {
        name = tokenName;
        symbol = tokenSymbol;
        _init(address(0), fundsManagerContractAddress, parametersContractAddress, proposalContractAddress, address(0), contractsManagerAddress);
        contractsManagerContract.createProject(prjId, address(this), false);
        projectId = contractsManagerContract.nextProjectId() - 1;
        __totalSupply = creatorSupply;
        __balanceOf[msg.sender] = creatorSupply;
    }
}
