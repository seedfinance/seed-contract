pragma solidity ^0.5.16;
contract CantrollerInterface {
    function claimCan(address holder) external;
    function claimCan(address holder, address[] calldata ctoken) external;
}