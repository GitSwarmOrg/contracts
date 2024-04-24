// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;

import "./base/ERC20interface.sol";
import "./base/ERC20Base.sol";
import "./Proposal.sol";
import "./base/ExpandableSupplyTokenBase.sol";

/**
 * @title Upgradable Token Contract
 * @dev This is an upgradable token that we deploy along with
 * the other initially deployed contracts.
 * This is the contract we use for our GitSwarm token.
 */
contract UpgradableToken is ExpandableSupplyTokenBase, Initializable {

    function initialize(
        string memory tokenName,
        string memory tokenSymbol,
        string memory prjId,
        uint supply,
        uint creatorSupply,
        address _delegates,
        address _fundsManager,
        address _tokenSell,
        address _proposal,
        address _gasStation,
        address _contractsManager
    ) public initializer {
        _init(_delegates, _fundsManager, _tokenSell, _proposal, _gasStation, _contractsManager);
        name = tokenName;
        symbol = tokenSymbol;
        contractsManagerContract.createProject(prjId, address(this));
        createInitialTokens(supply, creatorSupply);
    }

}
