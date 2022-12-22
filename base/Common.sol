pragma solidity ^0.8.0;

import "../ContractsManager.sol";

contract Common {

    ContractsManager public contractsManager;

    modifier restricted(uint projectId) {
        require(contractsManager.isTrustedContract(projectId, msg.sender), "Restricted function");
        _;
    }

}
