const RewardToken = artifacts.require('RewardToken');
const FeeRewardForwarder = artifacts.require('FeeRewardForwarder');
const ExclusiveRewardPool = artifacts.require('ExclusiveRewardPool');
const Controller = artifacts.require('Controller');
const Vault = artifacts.require('Vault');
const VaultProxy = artifacts.require('VaultProxy');
const SeedFinanceStrategyHT = artifacts.require('SeedFinanceStrategyHT');
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
            if (token.symbol == 'HT') {
                return deployer.deploy(SeedFinanceStrategyHT, process.env.CONTRACT_STORAGE, vaults[token.symbol]['vault'].address, network.dever)
            } else {
                return deployer.deploy(SeedFinanceStrategy, process.env.CONTRACT_STORAGE, vaults[token.symbol]['vault'].address, network.dever)
            }
        }).then(async function(res) {
            vaults[token.symbol]['strategy'] = res;
            return res.setLiquidation(true);
        }).then(function(res) {
            console.log("setLiquidation finish");
            console.dir(res);
            return vaults[token.symbol]['strategy'].transferOwnership(network.miner)
        }).then(async function(res) {
            console.dir("transferOwnership finish");
            console.dir(res);
            if (token.markets != null) {
                for (let j = 0; j < token.markets.length; j ++) {
                    tx = await vaults[token.symbol]['strategy'].addMarket(
                        token.markets[j].underlying, 
                        token.markets[j].cToken, 
                        token.markets[j].comptroller, 
                        token.markets[j].percent, 
                        token.markets[j].type,
                    );
                    console.dir("add new market");
                    console.dir(tx);
                }
            }
            return controller.addVaultAndStrategy(vaults[token.symbol]['vault'].address, vaults[token.symbol]['strategy'].address, {from: network.admin});
        }).then(function(res) {
            console.dir("addVaultAndStrategy finish");
            console.dir(res);
        });
    }
    let vaultInfo = [];
    for (let i = 0; i < network.tokens.length; i ++) {
        let token = network.tokens[i];
        vaultInfo.push({
            'symbol': token.symbol,
            'contract': token.contract,
            'vault': vaults[token.symbol]['vault'].address,
            'strategy': vaults[token.symbol]['strategy'].address,
            'pid': i,
        });
    }
    process.env.VAULTS = JSON.stringify(vaultInfo);
};
