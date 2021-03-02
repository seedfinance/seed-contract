pragma solidity ^0.5.16;

contract ComptrollerInterface {
    function claimComp(address holder) external;
    function claimComp(address holder, address[] calldata ctoken) external;
}
