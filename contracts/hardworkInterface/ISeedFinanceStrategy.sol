pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

interface ISeedFinanceStrategy {

    enum MarketType {Swap, RewardPool, Compound, Channels}

    function getMarketNum() external view returns (uint256);

    function market(uint id) external view returns (address, address, address, uint, uint, MarketType, bool);

}
