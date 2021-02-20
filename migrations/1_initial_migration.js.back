const Storage = artifacts.require('Storage');
const RewardToken = artifacts.require('RewardToken');
const DelayMinter = artifacts.require('DelayMinter');
const FeeRewardForwarder = artifacts.require('FeeRewardForwarder');
const ExclusiveRewardPool = artifacts.require('ExclusiveRewardPool');
const Controller = artifacts.require('Controller');
const Vault = artifacts.require('Vault');
const VaultProxy = artifacts.require('VaultProxy');
const AutoStake = artifacts.require('AutoStake');
const SeedPool = artifacts.require('SeedPool');
const network = require('../networks/heco-self.json');

module.exports = async function(deployer) {
    //部署storage
    let storage = null;
    await deployer.deploy(Storage).then(function(res) {
        storage = res;
        return storage.setGovernance(network.admin);
    }).then(function(res) {
        console.dir("set Governance as " + network.admin);
        console.log(res);
    });
    //部署RewardToken
    let rewardToken = null;
    let delayMinter = null;
    await deployer.deploy(RewardToken, storage.address).then(function(res) {
        rewardToken = res;
        return deployer.deploy(DelayMinter, storage.address, rewardToken.address);
    }).then(function(res) {
        delayMinter = res;
        return delayMinter.announceMint(network.invister, network.invisterRewardDelay, network.invisterRewardAmount, {from: network.admin});
    }).then(function(res) {
        console.dir("add invister reward delay mint");
        console.dir(res);
        return rewardToken.addMinter(delayMinter.address, {from: network.admin});
    }).then(function(res) {
        console.dir("add delayMinter as rewardToken minter finish");
        console.dir(res);
    });
    //部署FeeRewardForward
    let feeRewardForward = null;
    let rewardPool = null;
    let autoStake = null;
    await deployer.deploy(FeeRewardForwarder, storage.address, rewardToken.address, rewardToken.address).then(function(res) {
        feeRewardForward = res; 
        return deployer.deploy(ExclusiveRewardPool, rewardToken.address, rewardToken.address, network.rewardPool.duration, feeRewardForward.address, storage.address)
    }).then(function(res) {
        rewardPool = res;
        return rewardPool.transferOwnership(network.admin);
    }).then(function(res) {
        console.dir("change ownerShip");
        console.dir(res);
        return deployer.deploy(AutoStake, storage.address, rewardPool.address, rewardToken.address, network.greylistEscrow);
    }).then(function(res) {
        autoStake = res;
        return rewardPool.initExclusive(autoStake.address, {from:network.admin});
    }).then(function(res) {
        console.dir("initExclusive finish");
        console.dir(res);
    });
    //部署Controller
    let controller = null;
    await deployer.deploy(Controller, storage.address, feeRewardForward.address).then(function(res) {
        controller = res;
        return controller.setFeeRewardForwarder(feeRewardForward.address, {from: network.admin});
    }).then(function(res) {
        console.dir("setFeeRewardForwarder finish");
        console.dir(res);
    });
    //部署Vault
    let vaultLogicer = null;
    let vaults = {}
    await deployer.deploy(Vault).then(function(res) {
        vaultLogicer = res;
    });
    for (let i = 0; i < network.tokens.length; i ++) {
        let token = network.tokens[i];
        await deployer.deploy(VaultProxy, vaultLogicer.address).then(function(res) {
            return new Vault(res.address);
        }).then(function(res) {
            vaults[token.symbol] = res;
            res.initializeVault(storage.address, token.contract, token.toInvestNumerator, token.toInvestDenominator)
        });
    }
    //部署SeedPool
    let seedPool = null;
    await deployer.deploy(SeedPool, rewardToken.address, network.dever, network.invister, network.seedPerBlock, network.startBlock, network.boundsSeedPerBlocks).then(function(res) {
        seedPool = res;    
        return seedPool.transferOwnership(network.admin);
    }).then(function(res) {
        console.dir("transfer seedPool ownerShip finish");
        console.dir(res);
    });
    for (let i = 0; i < network.tokens.length; i ++) {
        let token = network.tokens[i];
        let vault = vaults[token.symbol];
        let tx = await seedPool.add(token.allocPoint, vault.address, true, {from: network.admin});
        console.dir("add seedPool finish");
        console.dir(tx);
    }
    for (let i = 0; i < network.pools.length; i ++) {
        let pool = network.pools[i];
        /*
        console.dir(pool);
        console.dir(pool.allocPoint);
        console.dir(pool.address);
        console.dir(network.admin);
        */
        let tx = await seedPool.add(pool.allocPoint, pool.address, false, {from:network.admin});
        console.dir("add sendPool finish");
        console.dir(tx);
    }

    /*
    let controller = null;
    await deployer.deploy(Controller
    */
    console.log("deploy finish");
};
