require("dotenv").config();

require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
// require("hardhat-gas-reporter");
require("solidity-coverage");

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.6.12"
      },
      {
        version: "0.8.10"
      }
    ],
  },

  networks: {

    localhost: {
      url: "http://127.0.0.1:8545",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },

    harmonyTestnet: {
      url: 'https://api.s0.b.hmny.io',
      accounts: [`${process.env.PRIVATE_KEY}`]
    },
    harmony: {
      url: 'https://rpc.hermesdefi.io',
      accounts: [`${process.env.PRIVATE_KEY}`]
    },
  },

};
