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
const { verify } = require("truffle-heco-verify/lib");
let activeNetwork = process.env.NETWORK;
if (activeNetwork == null || activeNetwork == "") {
    activeNetwork = 'self';
}
const network = require(format('../networks/heco-{}.json', activeNetwork));

module.exports = async function(deployer, networks) {
    //部署Timelock
    if (!network.useTimelock) {
        return;
    }
    let timelock = null;
    await deployer.deploy(Timelock, network.admin, network.delaySeconds).then(function(res) {
        timelock = res;
        return new Storage(process.env.CONTRACT_STORAGE);
    }).then(function(res) {
        return res.setGovernance(timelock.address, {from: network.admin});
    }).then(function(res) {
        console.dir("change admin to timelock: " + timelock.address);
        console.dir(res);
    });
    if (networks == 'mainnet') {
        await verify(["Timelock@" + timelock.address], networks, "UNLICENSED");
    }
    process.env.CONTRACT_TIMELOCK = timelock.address;
};
