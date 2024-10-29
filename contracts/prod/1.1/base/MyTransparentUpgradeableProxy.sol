// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.28;
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * @title My Transparent Upgradeable Proxy
 * @dev Extends OpenZeppelin's TransparentUpgradeableProxy for GitSwarm,
 * implementing the transparent proxy pattern for upgradable contract logic without losing state.
 */
contract MyTransparentUpgradeableProxy is TransparentUpgradeableProxy {
    /**
     * @dev Initializes the proxy with the address of the logic contract,
     * the proxy administrator, and any initial data to be sent to the logic contract.
     * The constructor passes these parameters to the base TransparentUpgradeableProxy constructor.
     * @param _logic Address of the logic contract containing the implementation.
     * @param _admin Address of the proxy administrator.
     * @param _data Initial data to be passed to the logic contract for initialization purposes, if any.
     */
    constructor(address _logic, address _admin, bytes memory _data) payable TransparentUpgradeableProxy(_logic, _admin, _data) {}

    /**
     * @dev Retrieves the address of the proxy administrator.
     * This function allows the identification of the current proxy administrator,
     * who has the authority to upgrade the contract.
     * @return The address of the proxy administrator.
     */
    function proxyAdmin() public returns (address) {
        return _proxyAdmin();
    }
}
