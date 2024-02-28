/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: '0.8.20',
    settings: {
      optimizer: {
        enabled: true,
        runs: 2 ** 32 - 1
      },
      viaIR: true
    }
  },
  paths: {
    root: '',
    sources: 'contracts',
    artifacts: 'artifacts'
  },
  networks: {
    hardhat: {
      accounts: [
        {
          privateKey: '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
          balance: '10000000000000000000000000000000000000000000000000000000'
        }
      ],
      chainId: 17
    }
  }
}
