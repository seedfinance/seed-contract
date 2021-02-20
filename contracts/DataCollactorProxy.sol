pragma solidity 0.5.16;

import "./hardworkInterface/IUpgradeSource.sol";
import "@openzeppelin/upgrades/contracts/upgradeability/BaseUpgradeabilityProxy.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

contract DataCollactorProxy is BaseUpgradeabilityProxy, Ownable {

  constructor(address _implementation) public {
    _setImplementation(_implementation);
  }

  /**
  * The main logic. If the timer has elapsed and there is a schedule upgrade,
  * the governance can upgrade the vault
  */
  function upgrade(address _newImplementation) external onlyOwner {
    _upgradeTo(_newImplementation);
  }

  function implementation() external view returns (address) {
    return _implementation();
  }
}
