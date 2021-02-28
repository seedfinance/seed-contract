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
    //输出部署信息
    let result = {};
    result['storage'] = process.env.CONTRACT_STORAGE;
    result['controller'] = process.env.CONTRACT_CONTROLLER;
    result['seedPool'] = process.env.CONTRACT_SEEDPOOL;
    result['rewardToken'] = process.env.CONTRACT_REWARDTOKEN;
    result['stakePool'] = process.env.CONTRACT_AUTOSTAKE;
    result['dataCollactor'] = process.env.CONTRACT_DATACOLLACTOR;
    result['timelock'] = process.env.CONTRACT_TIMELOCK;
    result['tokens'] = [];
    let vaults = JSON.parse(process.env.VAULTS);
    for (let i = 0; i < network.tokens.length; i ++) {
        let token = network.tokens[i];
        result['tokens'].push({
            'symbol' : token.symbol,
            'contract' : token.contract,
            'vault': vaults[i]['vault'],
            'strategy': vaults[i]['strategy'],
            'pid': i,
        })
    }
    console.log("deploy result:");
    console.log(JSON.stringify(result));
    console.log("deploy finish");
};
