const HDWalletProvider = require('@truffle/hdwallet-provider');
const secret = require("./.secret.json");

module.exports = {
  networks: {
    development: {
     host: "127.0.0.1",
     port: 8545,
     network_id: "*",
     gas: 6721975,
     provider: function () {
       return new HDWalletProvider('0x6bc778fd03fb64cebd855d64ae45048a04b154478f1a8aa25d2ebf4491488a58', `http://172.18.12.88:8545`)
     },
     from: '0x4f7b45C407ec1B106Ba3772e0Ecc7FD4504d3b92'
    },
    mainnet: {
      provider: function () {
        return new HDWalletProvider(secret.privatekey, `wss://ws-mainnet-node.huobichain.com`)
      },
      from:secret.account,
      // confirmations: 2,    // # of confs to wait between deployments. (default: 0)
      gasPrice: 2000000000,
      gas: 17219750,
      network_id: 128,       // Any network (default: none)
      //skipDryRun: true,
      websockets: true,
    },
  },
  mocha: {
    timeout: 1200000
  },
  plugins: ["solidity-coverage", "truffle-heco-verify"],
  compilers: {
    solc: {
      version: "0.5.16",
      settings: {
       optimizer: {
         enabled: true,
         runs: 200
       },
      }
    }
  },
  api_keys: {
    hecoinfo: 'TZHWGUNQ1UNM3ZWTS4IUT4CMNYZYX3KC7V'
  }
}
