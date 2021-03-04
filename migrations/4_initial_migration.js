const format = require('string-format');
let activeNetwork = process.env.NETWORK;
if (activeNetwork == null || activeNetwork == "") {
    activeNetwork = 'self';
}
const network = require(format('../networks/heco-{}.json', activeNetwork));
const Storage = artifacts.require('Storage');
const RewardToken = artifacts.require('RewardToken');
const FeeRewardForwarder = artifacts.require('FeeRewardForwarder');
const ExclusiveRewardPool = artifacts.require('ExclusiveRewardPool');
const Controller = artifacts.require('Controller');
const Vault = artifacts.require('Vault');
const VaultProxy = artifacts.require('VaultProxy');
const AutoStake = artifacts.require('AutoStake');
const SeedPool = artifacts.require('SeedPool');
const { verify } = require("truffle-heco-verify/lib");
/*
 * 部署Controller
 *
*/
module.exports = async function(deployer, networks) {
    //部署FeeRewardForward
    let feeRewardForward = null;
    let rewardPool = null;
    let autoStake = null;
    let controller = null;
    await deployer.deploy(FeeRewardForwarder, process.env.CONTRACT_STORAGE, process.env.CONTRACT_REWARDTOKEN, process.env.CONTRACT_REWARDTOKEN).then(function(res) {
        feeRewardForward = res;
        return deployer.deploy(ExclusiveRewardPool,
            process.env.CONTRACT_REWARDTOKEN,
            process.env.CONTRACT_REWARDTOKEN,
            network.rewardPool.duration,
            feeRewardForward.address,
            process.env.CONTRACT_STORAGE
        );
    }).then(function(res) {
        rewardPool = res;
        return rewardPool.transferOwnership(network.admin);
    }).then(function(res) {
        console.dir("change ownerShip");
        console.dir(res);
        return deployer.deploy(AutoStake, process.env.CONTRACT_STORAGE, rewardPool.address, process.env.CONTRACT_REWARDTOKEN, network.greylistEscrow);
    }).then(function(res) {
        autoStake = res;
        return rewardPool.initExclusive(autoStake.address, {from:network.admin});
    }).then(function(res) {
        console.dir("initExclusive finish");
        console.dir(res);
        return deployer.deploy(Controller, process.env.CONTRACT_STORAGE, feeRewardForward.address);
    }).then(function(res) {
        controller = res;
        return controller.setFeeRewardForwarder(feeRewardForward.address, {from: network.admin});
    }).then(function(res) {
        console.dir("setFeeRewardForwarder finish");
        console.dir(res);
        return controller.addHardWorker(network.miner, {from: network.admin});
    }).then(function(res) {
        console.dir("add hardWorker " + network.miner);
        console.dir(res);
        return new Storage(process.env.CONTRACT_STORAGE);
    }).then(function(res) {
        return res.setController(controller.address, {from: network.admin});
    }).then(function(res) {
        console.dir("set controller finish");
    });
    if (networks == 'mainnet') {
        await verify(["FeeRewardForwarder@" + feeRewardForward.address], networks, "UNLICENSED");
        await verify(["ExclusiveRewardPool@" + rewardPool.address], networks, "UNLICENSED");
        await verify(["AutoStake@" + autoStake.address], networks, "UNLICENSED");
        await verify(["Controller@" + controller.address], networks, "UNLICENSED");
    }
    process.env.CONTRACT_FEEREWARDFORWARD = feeRewardForward.address;
    process.env.CONTRACT_REWARDPOOL = rewardPool.address;
    process.env.CONTRACT_AUTOSTAKE = autoStake.address;
    process.env.CONTRACT_CONTROLLER = controller.address;
};
