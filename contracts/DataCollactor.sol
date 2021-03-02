pragma solidity 0.5.16;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./interfaces/compound/CTokenInterfaces.sol";
import "./interfaces/compound/InterestRateModel.sol";
import "./hardworkInterface/ISeedFinanceStrategy.sol";
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

    function getAPY(address vault) public view returns (uint256) {
        //IStrategy(IVault(vault).strategy())
        ISeedFinanceStrategy strategy =  ISeedFinanceStrategy(IVault(vault).strategy());
        uint256 marketNum = strategy.getMarketNum();
        uint totalAPY = 0;
        for (uint i = 0; i < marketNum; i ++) {
            uint currentAPY = 0;
            //ISeedFinanceStrategy.Market memory market = strategy.market(i);
            (, address cToken, , uint percent, ,ISeedFinanceStrategy.MarketType marketType, bool pause) = strategy.market(i);
            if (pause) continue;
            if (marketType == ISeedFinanceStrategy.MarketType.Channels || marketType == ISeedFinanceStrategy.MarketType.Compound) {
                currentAPY = CTokenInterface(cToken).supplyRatePerBlock().mul(10512000);
                totalAPY = totalAPY.add(currentAPY.mul(percent).div(1e12));
            } else if (marketType == ISeedFinanceStrategy.MarketType.Swap) {
            } else if (marketType == ISeedFinanceStrategy.MarketType.RewardPool) {
            }
        }
        return totalAPY.mul(7000).div(10000);
    }

    function getPriceToUsdt(address token, address usdt, address router) public view returns (uint256) {
        uint tokenA = IERC20(token).balanceOf(router);
        uint tokenB = IERC20(usdt).balanceOf(router);
        uint price = tokenB.mul(1e18).div(tokenA);
        return price;
    }

}
