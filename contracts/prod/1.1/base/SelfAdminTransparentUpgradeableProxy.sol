// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.28;
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * @title SelfAdmin Transparent Upgradeable Proxy
 * @dev Extends OpenZeppelin's TransparentUpgradeableProxy for use in GitSwarm, similar to MyTransparentUpgradeableProxy,
 * with a key difference: this version initializes itself as its own admin.
 */
contract SelfAdminTransparentUpgradeableProxy is TransparentUpgradeableProxy {
    /**
     * @dev Initializes the proxy with the address of the logic contract and any initial data,
     * setting itself as the proxy administrator.
     * @param _logic Address of the logic contract containing the implementation.
     * @param _data Initial data to be passed to the logic contract for initialization purposes, if any.
     */
    constructor(address _logic, bytes memory _data) payable TransparentUpgradeableProxy(_logic, address(this), _data) {}

    function proxyAdmin() public returns (address) {
        return _proxyAdmin();
    }
}
