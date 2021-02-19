pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../Controllable.sol";
import "../../hardworkInterface/IStrategyV2.sol";
import "../../interfaces/uniswap/interfaces/IUniswapV2Router02.sol";
import "../RewardTokenProfitNotifier.sol";
import "../../hardworkInterface/IVault.sol";
import "../../interfaces/mdex/IMasterChefHeco.sol";
import "../../interfaces/lava/IRewardPool.sol";
import "../../interfaces/compound/CTokenInterfaces.sol";

contract SeedFinanceStrategy is IStrategyV2, RewardTokenProfitNotifier {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  event ProfitsNotCollected(address);
  event Liquidating(address, uint256);

  IERC20 public underlying;  // 用户金库存的币种
  IERC20 public seed;   //平台币

  enum MarketType { Swap, RewardPool, Compound }

  struct Market {
    IERC20 underlying;    // market 平台币
    address investRouter;    //invest入口
    uint256 percent;   //投资百分比 1e12
    MarketType marketType;
    bool paused;
    bool isSell;
  }

  mapping (address => uint256) public marketId;

  Market[] public market;

  address public vault;
  address public mdexRouterV2;

  bool public claimAllowed;

  mapping (address => mapping (address => address[])) public mdexRoutes;

  // These tokens cannot be claimed by the controller
  mapping (address => bool) public unsalvagableTokens;

  modifier restricted() {
    require(msg.sender == vault || msg.sender == address(controller()) || msg.sender == address(governance()),
      "The sender has to be the controller or vault or governance");
    _;
  }


  constructor(
    address _storage,
    address _vault,
    address _underlying,
    address _mdex
  ) RewardTokenProfitNotifier(_storage) public {
    underlying = IERC20(_underlying);
    vault = _vault;
    mdexRouterV2 = _mdex;

  }

  function depositArbCheck() public view returns(bool) {
    return true;
  }

  /**
  * The strategy invests by supplying the underlying token.
  */
  function investAllUnderlying() public restricted {
    uint256 balance = underlying.balanceOf(address(this));
    for (uint256 i = 0; i < market.length; i++) {
        uint256 singleBalance = balance.mul(market[i].percent).div(1e12);
        underlying.safeApprove(address(market[i].investRouter), 0);
        underlying.safeApprove(address(market[i].investRouter), singleBalance);
        if (market[i].marketType == MarketType.Swap) {
            uint256 pid = IMasterChefHeco(market[i].investRouter).LpOfPid(address(underlying));
            (address lpToken, , ,) = IMasterChefHeco(market[i].investRouter).poolInfo(pid);
            require(lpToken == address(underlying), "pid not found");
            IMasterChefHeco(market[i].investRouter).deposit(pid, singleBalance);
        } else if (market[i].marketType == MarketType.RewardPool) {
            require(IRewardPool(market[i].investRouter).lpToken() == address(underlying), "lp token not found");
            IRewardPool(market[i].investRouter).stake(singleBalance);
        } else if (market[i].marketType == MarketType.Compound) {
            require(CErc20Interface(market[i].investRouter).underlying() == address(underlying), "token not found");
            CErc20Interface(market[i].investRouter).mint(singleBalance);
        }
    }
  }

  /**
  * Exits IDLE and transfers everything to the vault.
  */
  function withdrawAllToVault() external restricted {
    withdrawAll();
    IERC20(address(underlying)).safeTransfer(vault, underlying.balanceOf(address(this)));
  }

  /**
  * Withdraws all from market
  */
  function withdrawAll() internal {
    for (uint256 i = 0; i < market.length; i++) {
        if (market[i].marketType == MarketType.Swap) {
            uint256 pid = IMasterChefHeco(market[i].investRouter).LpOfPid(address(underlying));  //search pid of underlying
            (address lpToken, , ,) = IMasterChefHeco(market[i].investRouter).poolInfo(pid);
            require(lpToken == address(underlying), "pid not found");
            (uint amount,) = IMasterChefHeco(market[i].investRouter).userInfo(pid, address(this));  // get amount
            IMasterChefHeco(market[i].investRouter).withdraw(pid, amount);
        } else if (market[i].marketType == MarketType.RewardPool) {
            require(IRewardPool(market[i].investRouter).lpToken() == address(underlying), "lp token not found");
            IRewardPool(market[i].investRouter).exit();
        } else if (market[i].marketType == MarketType.Compound) {
            require(CErc20Interface(market[i].investRouter).underlying() == address(underlying), "token not found");
            uint amount = CTokenInterface(market[i].investRouter).balanceOf(address(this));
            CErc20Interface(market[i].investRouter).redeem(amount);
        }
        uint256 balance = market[i].underlying.balanceOf(address(this));
        if (market[i].isSell) {
            liquidate(address(market[i].underlying), address(underlying), balance);
        }
    }
  }

  function withdrawToVault(uint256 amountUnderlying) public restricted {
    // this method is called when the vault is missing funds
    // we will calculate the proportion of idle LP tokens that matches
    // the underlying amount requested
    withdrawAll();
    require(amountUnderlying >= underlying.balanceOf(address(this)), "no enough underlying");
    underlying.safeTransfer(vault, amountUnderlying);

    investAllUnderlying();
  }

  /**
  * Withdraws all assets, liquidates COMP, and invests again in the required ratio.
  */
  function doHardWork() public restricted {
    if (claimAllowed) {
      claim();
    }
    for (uint256 i = 0; i < market.length; i++) {
        if (market[i].isSell) {
            uint256 balance = market[i].underlying.balanceOf(address(this));
            liquidate(address(market[i].underlying), address(underlying), balance);
        }
    }

    // this updates the virtual price
    investAllUnderlying();

    // state of supply/loan will be updated by the modifier
  }

  /**
  * Salvages a token.
  */
  function salvage(address recipient, address token, uint256 amount) public onlyGovernance {
    // To make sure that governance cannot come in and take away the coins
    require(!unsalvagableTokens[token], "token is defined as not salvagable");
    IERC20(token).safeTransfer(recipient, amount);
  }

  function claim() internal {
      for (uint256 i = 0; i < market.length; i++) {
        if (market[i].marketType == MarketType.Swap) {
            uint256 pid = IMasterChefHeco(market[i].investRouter).LpOfPid(address(underlying));  //search pid of underlying
            (address lpToken, , ,) = IMasterChefHeco(market[i].investRouter).poolInfo(pid);
            require(lpToken == address(underlying), "pid not found");
            IMasterChefHeco(market[i].investRouter).deposit(pid, 0);
        }
    }
  }


  function liquidate(address tokenSrc, address tokenDst, uint256 rewardBalance) internal {
    // no profit notification, comp is liquidated to IDLE and will be notified there
    notifyProfitInRewardToken(tokenSrc, rewardBalance);

    rewardBalance = IERC20(tokenSrc).balanceOf(address(this));
    if (rewardBalance > 0) {
      emit Liquidating(tokenSrc, rewardBalance);
      IERC20(tokenSrc).safeApprove(mdexRouterV2, 0);
      IERC20(tokenSrc).safeApprove(mdexRouterV2, rewardBalance);
      // we can accept 1 as the minimum because this will be called only by a trusted worker
      IUniswapV2Router02(mdexRouterV2).swapExactTokensForTokens(
        rewardBalance, 1, mdexRoutes[tokenSrc][tokenDst], address(this), block.timestamp
      );
    }
  }


  /**
  * Returns the current balance. Ignores COMP that was not liquidated and invested.
  */
  function investedUnderlyingBalance() public view returns (uint256) {
    // NOTE: The use of virtual price is okay for appreciating assets inside IDLE,
    // but would be wrong and exploitable if funds were lost by IDLE, indicated by
    // the virtualPrice being greater than the token price.
    uint256 amounts;
    for (uint256 i = 0; i < market.length; i++) {
        uint256 amount;
        if (market[i].marketType == MarketType.Swap) {
            uint256 pid = IMasterChefHeco(market[i].investRouter).LpOfPid(address(underlying));  //search pid of underlying
            (address lpToken, , ,) = IMasterChefHeco(market[i].investRouter).poolInfo(pid);
            require(lpToken == address(underlying), "pid not found");
            (amount,) = IMasterChefHeco(market[i].investRouter).userInfo(pid, address(this));  // get amount
        } else if (market[i].marketType == MarketType.RewardPool) {
            require(IRewardPool(market[i].investRouter).lpToken() == address(underlying), "lp token not found");
            amount = IRewardPool(market[i].investRouter).balanceOf(address(this)).mul(IRewardPool(market[i].investRouter).rewardRate()).div(1e18);
        } else if (market[i].marketType == MarketType.Compound) {
            require(CErc20Interface(market[i].investRouter).underlying() == address(underlying), "token not found");
            (,uint256 cTokenBalance, uint256 borrowBalance, uint256 exchangeRateMantissa) = CTokenInterface(market[i].investRouter).getAccountSnapshot(address(this));
            amount = cTokenBalance.mul(exchangeRateMantissa).div(1e18).sub(borrowBalance);
        }
        amounts = amounts.add(amount);
    }
    amounts = amounts.add(underlying.balanceOf(address(this)));
    return amounts;
  }

  function setLiquidation(bool _claimAllowed) public onlyGovernance {
    claimAllowed = _claimAllowed;
  }

  function addMarket(address _underlying, address _investRouter, uint256 _percent, uint256 _type) public onlyGovernance {
    require(marketId[address(_underlying)] == 0 && (market.length == 0 || (market.length > 0 && address(market[0].underlying) != _underlying)), "underlying has been exised");
    market.push(Market({
        underlying: IERC20(_underlying),
        investRouter: _investRouter,
        percent: _percent,
        marketType: MarketType(_type),
        paused: false,
        isSell: true
    }));
    marketId[_underlying] = market.length - 1;
  }

  function setMarketPaused(uint256 _pid, bool state) public onlyGovernance {
    require(_pid < market.length, "id out of range");
    market[_pid].paused = state;
  }

  function setMarketSell(uint256 _pid, bool state) public onlyGovernance {
    require(_pid < market.length, "id out of range");
    market[_pid].isSell = state;
  }

  function setConversionPath(address from, address to, address[] memory _mdexRoute) public onlyGovernance {
    require(from == _mdexRoute[0],
      "The first token of the Uniswap route must be the from token");
    require(to == _mdexRoute[_mdexRoute.length - 1],
      "The last token of the Uniswap route must be the to token");
    mdexRoutes[from][to] = _mdexRoute;
  }
}
