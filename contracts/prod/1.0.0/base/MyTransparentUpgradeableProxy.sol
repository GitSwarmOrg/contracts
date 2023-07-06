// SPDX-License-Identifier: MIT
import "./TransparentUpgradeableProxy.sol";
// We deploy this contract instead of TransparentUpgradeableProxy because the constructor is
// missing from the abi when we compile TransparentUpgradeableProxy directly.

contract MyTransparentUpgradeableProxy is TransparentUpgradeableProxy {
    constructor(address _logic, address _admin, bytes memory _data) payable TransparentUpgradeableProxy(_logic, _admin, _data) {}
}
