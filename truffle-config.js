var HDWalletProvider = require("truffle-hdwallet-provider");
var mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";

module.exports = {
  networks: {
    development: {
      // provider: function() {
      //   return new HDWalletProvider(mnemonic, "http://127.0.0.1:8545", 0, 10);
      // },
      host: "127.0.0.1",
      port: 8545,
      network_id: '*',
      gas: 6721975
    }
  },
  compilers: {
    solc: {
      version: "^0.4.24"
    }
  }
};