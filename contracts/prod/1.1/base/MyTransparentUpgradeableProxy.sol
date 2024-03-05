// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;
import "../../../openzeppelin-v5.0.1/proxy/transparent/TransparentUpgradeableProxy.sol";
contract MyTransparentUpgradeableProxy is TransparentUpgradeableProxy {
    constructor(address _logic, address _admin, bytes memory _data) payable TransparentUpgradeableProxy(_logic, _admin, _data) {}

    function proxyAdmin() public returns (address) {
        return _proxyAdmin();
    }
}
