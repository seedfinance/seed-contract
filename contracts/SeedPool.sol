pragma solidity 0.5.16;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./RewardToken.sol";

contract SeedPool is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of SUSHIs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accSeedPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accSeedPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. SUSHIs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that SUSHIs distribution occurs.
        uint256 accSeedPerShare; // Accumulated SUSHIs per share, times 1e12. See below.
    }

    // The SEED TOKEN!
    RewardToken public seed;
    // Dev address.
    address public devaddr;
    // investor address.
    address public investoraddr;
    // SEED tokens created per block.
    uint256 public seedPerBlock;

    uint256[] public bonusSeedPerBlocks;
    uint256[] public bonusBlockCycle;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when SEED mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    modifier onlyLpToken(uint256 pid) {
        require(address(poolInfo[pid].lpToken) == msg.sender, "Only LpToken Can Call");
        _;
    }

    constructor(
        RewardToken _seed,
        address _devaddr,
        address _investoraddr,
        uint256 _seedPerBlock,
        uint256 _startBlock,
        uint256[] memory _bonusBlockCycle,
        uint256[] memory _bonusSeedPerBlocks
    ) public {
        require(_bonusBlockCycle.length == _bonusSeedPerBlocks.length, "Unequal length");
        seed = _seed;
        devaddr = _devaddr;
        investoraddr = _investoraddr;
        seedPerBlock = _seedPerBlock;
        bonusBlockCycle = _bonusBlockCycle;
        bonusSeedPerBlocks = _bonusSeedPerBlocks;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function getRewardDuration(uint256 _from, uint256 _to) public view returns (uint256 amount) {

        if (_to < startBlock) {
            return 0;
        }
        uint256 _ifrom = _from < startBlock ? startBlock : _from;
        for (uint256 i = 0; i < bonusBlockCycle.length; i++) {
            if (_ifrom >= bonusBlockCycle[i]) {
                continue;
            }
            // _from in this context
            if (_to < bonusBlockCycle[i]) {
                return amount.add(_to.sub(_ifrom).mul(bonusSeedPerBlocks[i]));
            }
            amount = amount.add(bonusBlockCycle[i].sub(_ifrom).mul(bonusSeedPerBlocks[i]));
            _ifrom = bonusBlockCycle[i];
        }
        if (_to >= bonusBlockCycle[bonusBlockCycle.length - 1]) {
            amount = amount.add(_to.sub(_ifrom).mul(seedPerBlock));
        }
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) public onlyOwner {
        require(address(_lpToken) != address(0), "lptoken not set");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accSeedPerShare: 0
        }));
    }

    // Update the given pool's SEED allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // View function to see pending SUSHIs on frontend.
    function pendingSeed(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accSeedPerShare = pool.accSeedPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0 && seed.totalSupply() < seed.cap()) {
            uint256 seedReward = getRewardDuration(pool.lastRewardBlock, block.number).mul(pool.allocPoint).div(totalAllocPoint);
            seedReward = seedReward.mul(7000).div(10000);
            accSeedPerShare = accSeedPerShare.add(seedReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accSeedPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        // mint if seed not caps
        if (seed.totalSupply() < seed.cap()) {
            uint256 seedReward = getRewardDuration(pool.lastRewardBlock, block.number).mul(pool.allocPoint).div(totalAllocPoint);
            if (seed.totalSupply().add(seedReward) > seed.cap()) {
                seedReward = seed.cap().sub(seed.totalSupply());
            }
            uint256 devseed = seedReward.mul(1000).div(10000);
            uint256 investorseed = seedReward.mul(2000).div(10000);
            uint256 poolReward = seedReward.sub(devseed).sub(investorseed);

            seed.mint(devaddr, devseed);
            seed.mint(investoraddr, investorseed);
            seed.mint(address(this), poolReward);

            pool.accSeedPerShare = pool.accSeedPerShare.add(poolReward.mul(1e12).div(lpSupply));
        }
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for SEED allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accSeedPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeSeedTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accSeedPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Deposit LP tokens to MasterChef for SEED allocation.
    function depositFor(uint256 _pid, address _user, uint256 _amount) public onlyLpToken(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accSeedPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeSeedTransfer(_user, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(_user, address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accSeedPerShare).div(1e12);
        emit Deposit(_user, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accSeedPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeSeedTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accSeedPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdrawFor(uint256 _pid, address _user, uint256 _amount) public onlyLpToken(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accSeedPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeSeedTransfer(_user, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(_user), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accSeedPerShare).div(1e12);
        emit Withdraw(_user, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe seed transfer function, just in case if rounding error causes pool to not have enough SUSHIs.
    function safeSeedTransfer(address _to, uint256 _amount) internal {
        uint256 seedBal = seed.balanceOf(address(this));
        if (_amount > seedBal) {
            seed.transfer(_to, seedBal);
        } else {
            seed.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }
}
