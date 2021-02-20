pragma solidity 0.5.16;

interface ISeedPool {

    function userInfo(uint256 _pid, address _user) external view returns (uint256, uint256);

    function poolLength() external view returns (uint256);

    function getseedPerBlock() external view returns (uint256);

    function add(uint256 _allocPoint, address _lpToken, bool _withUpdate) external;

    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) external;

    function pendingSeed(uint256 _pid, address _user) external view returns (uint256);

    function massUpdatePools() external;

    function updatePool(uint256 _pid) external;

    function deposit(uint256 _pid, uint256 _amount) external;

    function depositFor(uint256 _pid, address _user, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function withdrawFor(uint256 _pid, address _user, uint256 _amount) external;

    function emergencyWithdraw(uint256 _pid) external;

    function dev(address _devaddr) external;

    function getRewardDuration(uint256 _from, uint256 _to) external view returns (uint256 amount);

    function poolInfo(uint256 _pid) external view returns (address, uint256, uint256, uint256);

    function totalAllocPoint() external view returns (uint256);

}
