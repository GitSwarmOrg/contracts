pragma solidity ^0.8.0;

import "./Interfaces.sol";
import "./Constants.sol";
import "../../../openzeppelin-v4.9.0/proxy/utils/Initializable.sol";
import "../../../openzeppelin-v4.9.0/utils/Strings.sol";

contract Common is Constants {
    IDelegates public delegatesContract;
    IFundsManager public fundsManagerContract;
    ITokenSell public tokenSellContract;
    IProposal public proposalContract;
    IGasStation public gasStationContract;
    IContractsManager public contractsManagerContract;

    modifier restricted(uint projectId) {
        require(contractsManagerContract.isTrustedAddress(projectId, msg.sender),
            string.concat("Restricted function ", Strings.toHexString(uint256(uint160(msg.sender)))));
        _;
    }

    function _init(
        address _delegates,
        address _fundsManager,
        address _tokenSell,
        address _proposal,
        address _gasStation,
        address _contractsManager
    ) internal {
        delegatesContract = IDelegates(_delegates);
        fundsManagerContract = IFundsManager(_fundsManager);
        tokenSellContract = ITokenSell(_tokenSell);
        proposalContract = IProposal(_proposal);
        gasStationContract = IGasStation(_gasStation);
        contractsManagerContract = IContractsManager(_contractsManager);
    }

}
