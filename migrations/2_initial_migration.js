const format = require('string-format');
const RewardToken = artifacts.require('RewardToken');
const { verify } = require("truffle-heco-verify/lib");
let activeNetwork = process.env.NETWORK;
if (activeNetwork == null || activeNetwork == "") {
    activeNetwork = 'self';
}
const network = require(format('../networks/heco-{}.json', activeNetwork));
/**
  * 部署RewardToken
  *
**/
module.exports = async function(deployer, networks) {
    //部署RewardToken
    let rewardToken = null;
    await deployer.deploy(RewardToken, process.env.CONTRACT_STORAGE).then(function(res) {
        rewardToken = res;
    });
    if (networks == 'mainnet') {
        await verify(["RewardToken@" + rewardToken.address], networks, "UNLICENSED");
    }
    //更新相关信息到环境变量,方便后续合约使用
    process.env.CONTRACT_REWARDTOKEN = rewardToken.address;
};
