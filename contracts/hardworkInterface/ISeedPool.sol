pragma solidity 0.5.16;

interface ISeedPool {

    function poolLength() external view returns (uint256);

    function getseedPerBlock() external view returns (uint256);

    function add(uint256 _allocPoint, address _lpToken, bool _withUpdate) external;

    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) external;

    function pendingSeed(uint256 _pid, address _user) external view returns (uint256);

    function massUpdatePools() external;

    function updatePool(uint256 _pid) external;

    function deposit(uint256 _pid, uint256 _amount) external;

    function depositFor(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function emergencyWithdraw(uint256 _pid) external;

    function dev(address _devaddr) external;
}
