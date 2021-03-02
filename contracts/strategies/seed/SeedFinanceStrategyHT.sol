pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

// import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
// import "../../Controllable.sol";
import "../../hardworkInterface/IStrategyV2.sol";
import "../RewardTokenProfitNotifier.sol";
import "../../hardworkInterface/IVault.sol";
import "../../interfaces/mdex/IMasterChefHeco.sol";
import "../../interfaces/lava/IRewardPool.sol";
import "../../interfaces/compound/CTokenInterfaces.sol";
import "../../interfaces/compound/ComptrollerInterface.sol";
import "../../interfaces/channels/CantrollerInterface.sol";

contract SeedFinanceStrategyHT is IStrategyV2, RewardTokenProfitNotifier, Ownable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event Liquidating(address, uint256);
    IWHT valutUnderlying;

    uint256 public constant devPercent = 300000000000; //total 1e12
    enum MarketType {Swap, RewardPool, Compound, Channels}

    struct Market {
        IERC20 underlying;
        address investRouter; // use for lend ctoken
        address investRouter2;
        uint256 percent; //percent 1e12
        uint256 amount;
        MarketType marketType;
        bool investPaused;
        bool claimPaused;
        bool withdrawPaused;
    }

    Market[] public market;
    mapping(address => uint256) public marketId;

    address public devaddr;

    address public vault;

    bool public claimAllowed;


    modifier restricted() {
        require(
            msg.sender == vault ||
                msg.sender == address(controller()) ||
                msg.sender == address(governance()),
            "The sender has to be the controller or vault or governance"
        );
        _;
    }

    constructor(
        address _storage,
        address _vault,
        address _devaddr
    ) public RewardTokenProfitNotifier(_storage) {
        vault = _vault;
        devaddr = _devaddr;
        valutUnderlying = IWHT(IVault(_vault).underlying());
    }

    function getMarketNum() external view returns (uint256) {
        return market.length;
    }

    function underlying() external view returns (address) {
        return address(valutUnderlying);
    }

    function depositArbCheck() public view returns (bool) {
        return true;
    }

    /**
     * The strategy invests by supplying the underlying token.
     */
    function investAllUnderlying() public restricted {
        uint256 balance = valutUnderlying.balanceOf(address(this));
        for (uint256 i = 0; i < market.length; i++) {
            if (market[i].investPaused) {
                continue;
            }
            uint256 singleBalance = balance.mul(market[i].percent).div(1e12);
            market[i].amount = market[i].amount.add(singleBalance);

            if (market[i].marketType == MarketType.Compound || market[i].marketType == MarketType.Channels) {
                valutUnderlying.withdraw(singleBalance);
                CEtherInterface(market[i].investRouter).mint.value(singleBalance)();
                continue;
            }

            IERC20(address(valutUnderlying)).safeApprove(address(market[i].investRouter), 0);
            IERC20(address(valutUnderlying)).safeApprove(
                address(market[i].investRouter),
                singleBalance
            );
            if (market[i].marketType == MarketType.Swap) {
                uint256 pid =
                    IMasterChefHeco(market[i].investRouter).LpOfPid(
                        address(valutUnderlying)
                    );
                (address lpToken, , , ) =
                    IMasterChefHeco(market[i].investRouter).poolInfo(pid);
                require(lpToken == address(valutUnderlying), "pid not found");
                IMasterChefHeco(market[i].investRouter).deposit(
                    pid,
                    singleBalance
                );
            } else if (market[i].marketType == MarketType.RewardPool) {
                require(
                    IRewardPool(market[i].investRouter).lpToken() ==
                        address(valutUnderlying),
                    "lp token not found"
                );
                IRewardPool(market[i].investRouter).stake(singleBalance);
            }
        }
    }

  function withdrawToVault(uint256 amountUnderlying, uint256) public restricted {
    // this method is called when the vault is missing funds
    // we will calculate the proportion of idle LP tokens that matches
    // the underlying amount requested
    withdrawAll();
    require(amountUnderlying <= valutUnderlying.balanceOf(address(this)), "no enough underlying");
    if (amountUnderlying > 0) {
        IERC20(address(valutUnderlying)).safeTransfer(vault, amountUnderlying);
    }

    investAllUnderlying();
  }

    /**
     * Exits and transfers everything to the vault.
     */
    function withdrawAllToVault() external restricted {
        withdrawAll();
        IERC20(address(valutUnderlying)).safeTransfer(
            vault,
            valutUnderlying.balanceOf(address(this))
        );
    }

    /**
     * Withdraws all from market
     */
    function withdrawAll() internal {
        for (uint256 i = 0; i < market.length; i++) {
            if (market[i].withdrawPaused) {
                continue;
            }
            uint256 oldBalance = valutUnderlying.balanceOf(address(this)).add(market[i].amount);
            if (market[i].marketType == MarketType.Swap) {
                uint256 pid =
                    IMasterChefHeco(market[i].investRouter).LpOfPid(
                        address(valutUnderlying)
                    ); //search pid of underlying
                (address lpToken, , , ) =
                    IMasterChefHeco(market[i].investRouter).poolInfo(pid);
                require(lpToken == address(valutUnderlying), "pid not found");
                (uint256 amount, ) =
                    IMasterChefHeco(market[i].investRouter).userInfo(
                        pid,
                        address(this)
                    ); // get amount
                IMasterChefHeco(market[i].investRouter).withdraw(pid, amount);
            } else if (market[i].marketType == MarketType.RewardPool) {
                require(
                    IRewardPool(market[i].investRouter).lpToken() ==
                        address(valutUnderlying),
                    "lp token not found"
                );
                IRewardPool(market[i].investRouter).withdraw(IRewardPool(market[i].investRouter).balanceOf(address(this)));
            } else if (market[i].marketType == MarketType.Compound || market[i].marketType == MarketType.Channels) {
                uint256 amount =
                    CTokenInterface(market[i].investRouter).balanceOf(
                        address(this)
                    );
                CEtherInterface(market[i].investRouter).redeem(amount);
                valutUnderlying.deposit.value(amount)();
            }
            uint256 newBalance = valutUnderlying.balanceOf(address(this));
            if (newBalance > oldBalance) {
                IERC20(address(valutUnderlying)).safeTransfer(devaddr, (newBalance.sub(oldBalance)).mul(devPercent).div(1e12));
            }

            notifyProfitInRewardToken(address(market[i].underlying), 0); // not yet used
            uint256 marketUnderlyingBalance = market[i].underlying.balanceOf(address(this));
            if (marketUnderlyingBalance > 0) {
                market[i].underlying.safeTransfer(devaddr, marketUnderlyingBalance);
            }
            market[i].amount = 0;
        }
    }

    /**
     * Withdraws all assets, liquidates COMP, and invests again in the required ratio.
     */
    function doHardWork() public restricted {
        if (claimAllowed) {
            claim();
        }

        // this updates the virtual price
        investAllUnderlying();
    }

    /**
     * Salvages a token.
     */
    function salvage(
        address recipient,
        address token,
        uint256 amount
    ) public onlyGovernance {
        IERC20(token).safeTransfer(recipient, amount);
    }

    function claim() internal {
        for (uint256 i = 0; i < market.length; i++) {
            if (market[i].claimPaused) {
                continue;
            }
            if (market[i].marketType == MarketType.Swap) {
                uint256 pid =
                    IMasterChefHeco(market[i].investRouter).LpOfPid(
                        address(valutUnderlying)
                    ); //search pid of underlying
                (address lpToken, , , ) =
                    IMasterChefHeco(market[i].investRouter).poolInfo(pid);
                require(lpToken == address(valutUnderlying), "pid not found");
                IMasterChefHeco(market[i].investRouter).withdraw(pid, 0);
            } else if (market[i].marketType == MarketType.RewardPool) {
                IRewardPool(market[i].investRouter).getReward();
            } else if (market[i].marketType == MarketType.Compound) {
                ComptrollerInterface(market[i].investRouter2).claimComp(address(this));
            } else if (market[i].marketType == MarketType.Channels) {
                CantrollerInterface(market[i].investRouter2).claimCan(address(this));
            }
            uint256 mUnderlyingBalance = market[i].underlying.balanceOf(address(this));
            if (mUnderlyingBalance > 0) {
                market[i].underlying.safeTransfer(devaddr, mUnderlyingBalance);
            }
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
                uint256 pid =
                    IMasterChefHeco(market[i].investRouter).LpOfPid(
                        address(valutUnderlying)
                    ); //search pid of underlying
                (address lpToken, , , ) =
                    IMasterChefHeco(market[i].investRouter).poolInfo(pid);
                require(lpToken == address(valutUnderlying), "pid not found");
                (amount, ) = IMasterChefHeco(market[i].investRouter).userInfo(
                    pid,
                    address(this)
                ); // get amount
            } else if (market[i].marketType == MarketType.RewardPool) {
                require(
                    IRewardPool(market[i].investRouter).lpToken() ==
                        address(valutUnderlying),
                    "lp token not found"
                );
                amount = IRewardPool(market[i].investRouter)
                    .balanceOf(address(this))
                    .mul(IRewardPool(market[i].investRouter).rewardRate())
                    .div(1e18);
            } else if (market[i].marketType == MarketType.Compound || market[i].marketType == MarketType.Channels) {
                (
                    ,
                    uint256 cTokenBalance,
                    uint256 borrowBalance,
                    uint256 exchangeRateMantissa
                ) =
                    CTokenInterface(market[i].investRouter).getAccountSnapshot(
                        address(this)
                    );
                amount = cTokenBalance.mul(exchangeRateMantissa).div(1e18).sub(
                    borrowBalance
                );
            }
            amounts = amounts.add(amount);
        }
        amounts = amounts.add(valutUnderlying.balanceOf(address(this)));
        return amounts;
    }

    function setLiquidation(bool _claimAllowed) public onlyOwner {
        claimAllowed = _claimAllowed;
    }

    function addMarket(
        address _underlying,
        address _investRouter,
        address _investRouter2,
        uint256 _percent,
        uint256 _type
    ) public onlyGovernance {
        require(_underlying != address(0), "underlying not set");
        require(
            marketId[address(_underlying)] == 0 &&
                (market.length == 0 ||
                    (market.length > 0 &&
                        address(market[0].underlying) != _underlying)),
            "underlying has been exised"
        );
        market.push(
            Market({
                underlying: IERC20(_underlying),
                investRouter: _investRouter,
                investRouter2: _investRouter2,
                amount: 0,
                percent: _percent,
                marketType: MarketType(_type),
                investPaused: false,
                withdrawPaused: false,
                claimPaused: false
            })
        );
        marketId[_underlying] = market.length - 1;
    }

    function removeMarket(uint256 _mid) public onlyGovernance {
        require(_mid < market.length, "mid out of range");
        delete marketId[address(market[_mid].underlying)];
        market[_mid] = market[market.length - 1];
        marketId[address(market[_mid].underlying)] = _mid;
        market.length--;
    }

    function setMarketPercent(uint256 _pid, uint256 _percent) public onlyOwner {
        require(_pid < market.length, "id out of range");
        market[_pid].percent = _percent;
    }

    function setMarketInvestPaused(uint256 _pid, bool state) public onlyOwner {
        require(_pid < market.length, "id out of range");
        market[_pid].investPaused = state;
    }

    function setMarketWithdrawPaused(uint256 _pid, bool state) public onlyOwner {
        require(_pid < market.length, "id out of range");
        market[_pid].withdrawPaused = state;
    }

    function setMarketClaimPaused(uint256 _pid, bool state) public onlyOwner {
        require(_pid < market.length, "id out of range");
        market[_pid].claimPaused = state;
    }
    function updateDevAddr(address _newAddress) public onlyGovernance {
        require(_newAddress != address(0), "address is unvalid");
        devaddr = _newAddress;
    }
}