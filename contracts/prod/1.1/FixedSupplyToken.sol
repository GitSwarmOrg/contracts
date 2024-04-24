// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;

import "./base/ERC20interface.sol";
import "./base/ERC20Base.sol";
//import "hardhat/console.sol";

/**
 * @title Fixed Supply Token Contract
 * @dev This contract implements a token with a fixed supply.
 * It is deployed when a user wants to create a new token with a fixed amount.
 * @notice Deploy this contract for creating a token with a fixed supply.
 */
contract FixedSupplyToken is ERC20Base {
    uint immutable public projectId;
    /**
     * @param prjId The project ID for the new token.
     * @param supply The total fixed supply of the token.
     * @param creatorSupply The portion of the supply allocated to the creator.
     * @param contractsManagerAddress Address of the Contracts Manager.
     * @param fundsManagerContractAddress Address of the Funds Manager Contract.
     * @param proposalContractAddress Address of the Proposal Contract.
     * @param tokenName The name of the token.
     * @param tokenSymbol The symbol of the token.
     *
     * Requirements:
     * - `creatorSupply` must be non-zero.
     * - Contract must have no pre-existing supply (`__totalSupply` == 0).
     */
    constructor(
        string memory prjId,
        uint supply,
        uint creatorSupply,
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
        __totalSupply = supply + creatorSupply;
        __balanceOf[msg.sender] = creatorSupply;
        __balanceOf[address(fundsManagerContract)] = supply;
        fundsManagerContract.updateBalance(projectId, address(this), supply);
    }
}
