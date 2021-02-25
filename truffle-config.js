const HDWalletProvider = require('@truffle/hdwallet-provider');

module.exports = {
  networks: {
    development: {
     network_id: "*",
     gas: 6721975,
     provider: function () {
       return new HDWalletProvider('0x6bc778fd03fb64cebd855d64ae45048a04b154478f1a8aa25d2ebf4491488a58', `http://172.18.12.88:8545`)
     },
     from: '0x4f7b45C407ec1B106Ba3772e0Ecc7FD4504d3b92'
    },
    ropsten: {
      provider: function () {
        const secret = require("./secret.json");
        return new HDWalletProvider(secret.mnemonic, `https://ropsten.infura.io/v3/${secret.infuraKey}`, 1);
      },
      network_id: 3,
      gas: 4721975,
      skipDryRun: true,
      gasPrice: 23000000000,
    },
    mainnet: {
      provider: function () {
        const secret = require("./secret.json");
        return new HDWalletProvider(secret.mnemonic, `https://mainnet.infura.io/v3/${secret.infuraKey}`);
      },
      network_id: 1,
      gas: 6721975,
      skipDryRun: true,
      gasPrice: 75000000000,
    },
  },
  mocha: {
    timeout: 1200000
  },
  plugins: ["solidity-coverage"],
  compilers: {
    solc: {
      version: "0.5.16",
      settings: {
       optimizer: {
         enabled: true,
         runs: 150
       },
      }
    }
  }
}
