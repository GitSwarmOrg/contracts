// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;

import "./base/ERC20interface.sol";
import "./base/ERC20Base.sol";
import "./base/ExpandableSupplyTokenBase.sol";
//import "hardhat/console.sol";

// We deploy this contract when a user creates a new token
// and they want to be able to increase the supply later.
contract ExpandableSupplyToken is ExpandableSupplyTokenBase {
    constructor(
        string memory prjId,
        uint supply,
        uint creatorSupply,
        address contractsManagerAddress,
        address fundsManagerContractAddress,
        address proposalContractAddress,
        string memory tokenName,
        string memory tokenSymbol
    ) {
        require(creatorSupply != 0 && 0 == __totalSupply);
        name = tokenName;
        symbol = tokenSymbol;
        _init(address(0), fundsManagerContractAddress, address(0), proposalContractAddress, address(0), contractsManagerAddress);
        contractsManagerContract.createProject(prjId, address(this), false);
        createInitialTokens(supply, creatorSupply);
    }
}
