// SPDX-License-Identifier: MIT
import "../../../openzeppelin-v4.9.0/proxy/transparent/TransparentUpgradeableProxy.sol";

contract SelfAdminTransparentUpgradeableProxy is TransparentUpgradeableProxy {
    constructor(address _logic, bytes memory _data) payable TransparentUpgradeableProxy(_logic, address(this), _data) {}
}
