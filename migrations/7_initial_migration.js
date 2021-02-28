const RewardToken = artifacts.require('RewardToken');
const FeeRewardForwarder = artifacts.require('FeeRewardForwarder');
const ExclusiveRewardPool = artifacts.require('ExclusiveRewardPool');
const Controller = artifacts.require('Controller');
const Vault = artifacts.require('Vault');
const VaultProxy = artifacts.require('VaultProxy');
const AutoStake = artifacts.require('AutoStake');
const SeedPool = artifacts.require('SeedPool');
const format = require('string-format');
const Storage = artifacts.require('Storage');
const SeedFinanceStrategy = artifacts.require('SeedFinanceStrategy');
const Timelock = artifacts.require('Timelock');
const DataCollactor = artifacts.require('DataCollactor');
const DataCollactorProxy = artifacts.require('DataCollactorProxy');
let activeNetwork = process.env.NETWORK;
if (activeNetwork == null || activeNetwork == "") {
    activeNetwork = 'self';
}
const network = require(format('../networks/heco-{}.json', activeNetwork));

module.exports = async function(deployer) {
    //部署接口合约
    let dataCollactor = null;
    let dataCollactorProxy = null;
    let seedPool = await new SeedPool(process.env.CONTRACT_SEEDPOOL);
    await deployer.deploy(DataCollactor).then(function(res) {
        dataCollactor = res;
        return deployer.deploy(DataCollactorProxy, res.address);
    }).then(function(res) {
        dataCollactorProxy = res;
        return new DataCollactor(dataCollactorProxy.address);
    }).then(function(res) {
        dataCollactor = res;
        return dataCollactor.setSeedPool(seedPool.address);
    }).then(function(res) {
        console.dir("set seedPool finish");
        console.dir(res);
        return dataCollactorProxy.transferOwnership(network.admin);
    }).then(function(res) {
        console.dir("transferOwnership finish to " + network.admin);
        console.dir(res);
    });
    process.env.CONTRACT_DATACOLLACTOR = dataCollactor.address;
};
