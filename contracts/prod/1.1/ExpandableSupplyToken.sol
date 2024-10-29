// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.28;

import "./base/ERC20Base.sol";
import "./base/ExpandableSupplyTokenBase.sol";
//import "hardhat/console.sol";

/**
 * @title Expandable Supply Token
 * @dev Implementation of an ERC20 token with expandable supply.
 * This contract allows for the supply of tokens to be increased after deployment,
 * intended for projects that may require additional token issuance post-launch.
 * The initial supply is allocated upon contract creation, with a portion designated for the creator.
 * The supply can be expanded by authorized addresses as defined by the contract's logic.
 */
contract ExpandableSupplyToken is ExpandableSupplyTokenBase {
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
        createInitialTokens(creatorSupply);
    }
}
