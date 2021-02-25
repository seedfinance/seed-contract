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
    //部署Vault
    let vaultLogicer = null;
    let vaults = {}
    await deployer.deploy(Vault).then(function(res) {
        vaultLogicer = res;
    });
    let seedPool = await new SeedPool(process.env.CONTRACT_SEEDPOOL);
    let controller = await new Controller(process.env.CONTRACT_CONTROLLER);
    let result = {}
    for (let i = 0; i < network.tokens.length; i ++) {
        let token = network.tokens[i];
        vaults[token.symbol] = {};
        await deployer.deploy(VaultProxy, vaultLogicer.address).then(function(res) {
            return new Vault(res.address);
        }).then(function(res) {
            vaults[token.symbol]['vault'] = res;
            return res.initializeVault(process.env.CONTRACT_STORAGE, token.contract, token.toInvestNumerator, token.toInvestDenominator)
        }).then(function(res) {
            console.dir("vault initializeVault finish");
            console.dir(res);
            return seedPool.add(token.allocPoint, vaults[token.symbol]['vault'].address, true, {from: network.admin});
        }).then(function(res) {
            console.dir("add seedPool finish");
            console.dir(res);
            return vaults[token.symbol]['vault'].setSeedPoolAddress(process.env.CONTRACT_SEEDPOOL, {from: network.admin});
        }).then(function(res) {
            console.dir("setSeedPoolAddress finish");
            console.dir(res);
            return vaults[token.symbol]['vault'].setSeedPoolId(i, {from: network.admin});
        }).then(function(res) {
            console.dir("setSeedPoolId finish");
            return deployer.deploy(SeedFinanceStrategy, process.env.CONTRACT_STORAGE, vaults[token.symbol]['vault'].address, network.dever)
        }).then(function(res) {
            vaults[token.symbol]['strategy'] = res;
            return controller.addVaultAndStrategy(vaults[token.symbol]['vault'].address, vaults[token.symbol]['strategy'].address, {from: network.admin});
        }).then(function(res) {
            console.dir("addVaultAndStrategy finish");
            console.dir(res);
        });
    }
    //最后部署Timelock
    let timelock = null;
    await deployer.deploy(Timelock, network.admin, network.delaySeconds).then(function(res) {
        timelock = res;
        return new Storage(process.env.CONTRACT_STORAGE);
    }).then(function(res) {
        return res.setGovernance(timelock.address, {from: network.admin});
    }).then(function(res) {
        console.dir("change admin to timelock");
        console.dir(res);
    });
    //最后部署接口合约
    let dataCollactor = null;
    let dataCollactorProxy = null;
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
        console.dir("transferOwnership finish");
        console.dir(res);
    });
    result['controller'] = controller.address;
    result['seedPool'] = seedPool.address;
    result['rewardToken'] = process.env.CONTRACT_REWARDTOKEN;
    result['stakePool'] = process.env.CONTRACT_AUTOSTAKE;
    result['dataCollactor'] = dataCollactor.address;
    result['tokens'] = [];
    result['timelock'] = timelock.address;
    for (let i = 0; i < network.tokens.length; i ++) {
        let token = network.tokens[i];
        result['tokens'].push({
            'symbol' : token.symbol,
            'contract' : token.contract,
            'vault': vaults[token.symbol]['vault'].address,
            'strategy': vaults[token.symbol]['strategy'].address,
            'pid': i,
        })
    }
    console.log("deploy result:");
    console.log(JSON.stringify(result));
    console.log("deploy finish");
};
