pragma solidity 0.5.16;

interface IMasterChefHeco {
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function userInfo(uint256 _pid, address _user) external view returns (uint256 amount, uint256 rewardDebt);
    function poolInfo(uint256 _pid) external view returns (address lpToken, uint256, uint256, uint256);
    function massUpdatePools() external;
    function pending(uint256 _pid, address _user) external view returns (uint256 amount);
    function LpOfPid(address _token) external view returns (uint256 _pid);
    function emergencyWithdraw(uint256 pid) external;
}
interface IWHT {
    function deposit() external payable;
    function withdraw(uint wad) external;
    function totalSupply() external view returns (uint);
    function approve(address guy, uint wad) external returns (bool);
    function transfer(address dst, uint wad) external returns (bool);
    function transferFrom(address src, address dst, uint wad) external returns (bool);
    function balanceOf(address src) external view returns (uint);
    function allowance(address src, address dst) external view returns (uint);
}