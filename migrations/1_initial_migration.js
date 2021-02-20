const format = require('string-format');
const Storage = artifacts.require('Storage');
let activeNetwork = process.env.NETWORK;
if (activeNetwork == null || activeNetwork == "") {
    activeNetwork = 'self';
}
const network = require(format('../networks/heco-{}.json', activeNetwork));
/**
  * 部署基础的权限管理合约Storage
**/
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
    //更新到环境变量,方便下个合约使用
    process.env.CONTRACT_STORAGE = storage.address;
};
