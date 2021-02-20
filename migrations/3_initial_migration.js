const format = require('string-format');
const Storage = artifacts.require('Storage');
const RewardToken = artifacts.require('RewardToken');
let activeNetwork = process.env.NETWORK;
if (activeNetwork == null || activeNetwork == "") {
    activeNetwork = 'self';
}
const network = require(format('../networks/heco-{}.json', activeNetwork));
const SeedPool = artifacts.require('SeedPool');

/**
  * 部署SeedPool挖矿合约
**/
module.exports = async function(deployer) {
    //部署SeedPool
    let seedPool = null;
    let bonusBlockCycle = [network.startBlock+(network.bonusBlockCycle), network.startBlock+(network.bonusBlockCycle*2), network.startBlock+(network.bonusBlockCycle*3), network.startBlock+(network.bonusBlockCycle*4)]
    await deployer.deploy(SeedPool, process.env.CONTRACT_REWARDTOKEN, network.dever, network.invister, network.seedPerBlock, network.startBlock, bonusBlockCycle, network.boundsSeedPerBlocks).then(function(res) {
        seedPool = res;    
        return seedPool.transferOwnership(network.admin);
    }).then(function(res) {
        console.dir("transfer seedPool ownerShip as " + network.admin);
        return new RewardToken(process.env.CONTRACT_REWARDTOKEN);
    }).then(function(res) {
        return res.addMinter(seedPool.address, {from: network.admin});
    }).then(function(res) {
        console.dir("add seedPool as minter finish");
        console.dir(res);
    });
    process.env.CONTRACT_SEEDPOOL = seedPool.address;
};
