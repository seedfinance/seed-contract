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
            return res.setLiquidation(true);
        }).then(function(res) {
            console.dir("setLiquidation finish");
            console.dir(res);
            return vaults[token.symbol]['strategy'].addMarket('0x843f945C8CeC867dFd75b1EE9ab8D2b80a9180C0', '0xEa4038d164e853B7facb95505F52734A7C4fb5d8', '0xfCDfFFaa5e12673c1570f1565F6D430307b8d7C5', '1000000000000', 3);
        }).then(function(res) {
            console.dir("addMarket finish");
            console.dir(res);
            return controller.addVaultAndStrategy(vaults[token.symbol]['vault'].address, vaults[token.symbol]['strategy'].address, {from: network.admin});
        }).then(function(res) {
            console.dir("addVaultAndStrategy finish");
            console.dir(res);
        });
    }
    process.env.VAULTS = JSON.stringify(vaults);
};
