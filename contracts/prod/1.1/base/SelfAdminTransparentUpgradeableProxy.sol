// SPDX-License-Identifier: MIT
import "../../../openzeppelin-v5.0.1/proxy/transparent/TransparentUpgradeableProxy.sol";

contract SelfAdminTransparentUpgradeableProxy is TransparentUpgradeableProxy {
    constructor(address _logic, bytes memory _data) payable TransparentUpgradeableProxy(_logic, address(this), _data) {}

    function proxyAdmin() public returns (address) {
        return _proxyAdmin();
    }
}
