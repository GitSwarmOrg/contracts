// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;

import "./Interfaces.sol";
import "./Constants.sol";
import "../../../openzeppelin-v5.0.1/proxy/utils/Initializable.sol";
import "../../../openzeppelin-v5.0.1/utils/Strings.sol";
import "../../../openzeppelin-v5.0.1/utils/Address.sol";

contract Common is Constants {
    IDelegates public delegatesContract;
    IFundsManager public fundsManagerContract;
    IParameters public parametersContract;
    IProposal public proposalContract;
    IGasStation public gasStationContract;
    IContractsManager public contractsManagerContract;

    receive() external payable {
        revert("You cannot send Ether directly to FundsManager");
    }

    fallback() external payable {
        revert("You cannot send Ether directly to FundsManager");
    }


    modifier restricted(uint projectId) {
        require(parametersContract.isTrustedAddress(projectId, msg.sender), "Restricted function ");
        _;
    }

    function _init(
        address _delegates,
        address _fundsManager,
        address _parameters,
        address _proposal,
        address _gasStation,
        address _contractsManager
    ) internal {
        delegatesContract = IDelegates(_delegates);
        fundsManagerContract = IFundsManager(_fundsManager);
        parametersContract = IParameters(_parameters);
        proposalContract = IProposal(_proposal);
        gasStationContract = IGasStation(_gasStation);
        contractsManagerContract = IContractsManager(_contractsManager);
    }


}
