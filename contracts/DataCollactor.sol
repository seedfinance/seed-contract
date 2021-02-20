pragma solidity 0.5.16;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./hardworkInterface/IController.sol";
import "./hardworkInterface/IStrategy.sol";
import "./hardworkInterface/IVault.sol";
import "./hardworkInterface/ISeedPool.sol";
import "./FeeRewardForwarder.sol";
import "./Governable.sol";
import "./HardRewards.sol";

contract DataCollactor is Ownable {
    using SafeMath for uint256;

    ISeedPool seedPool;

    constructor() public {
    }

    function setSeedPool(address _seedPool) external onlyOwner {
        seedPool = ISeedPool(_seedPool);
    }

    function rewardOneDay(uint pid) public view returns (uint256 amount) {
        uint rewardPerBlock = seedPool.getRewardDuration(block.number, block.number + 1);
        ( , uint256 allocPoint, ,) = seedPool.poolInfo(pid);
        uint256 totalAllocPoint = seedPool.totalAllocPoint();
        amount = rewardPerBlock.mul(allocPoint).mul(28800).mul(7000).div(totalAllocPoint).div(10000);
    }
}
