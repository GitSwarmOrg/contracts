import {HardhatUserConfig} from "hardhat/config"

import "hardhat-deploy"
import "@nomiclabs/hardhat-solhint"
import "@nomicfoundation/hardhat-ethers"
import "@nomiclabs/hardhat-etherscan"
import "@typechain/hardhat"
import "@nomicfoundation/hardhat-chai-matchers"
import "solidity-coverage"

const config: HardhatUserConfig =
    {
        solidity: {
            version: '0.8.28',
            settings: {
                optimizer: {
                    enabled: true,
                    runs: 1,
                    details: {
                        yulDetails: {
                            optimizerSteps: ''
                        },
                        "yul": true
                    }
                },
            }
        },
        paths: {
            root: '',
            sources: 'contracts',
            artifacts: 'artifacts',
            tests: 'test/js_tests'
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
            },
            localhost: {
                url: "http://127.0.0.1:8545"
            },
            mainnet: {
                url: "https://eth.gitswarm.com:2096",
                chainId: 1
            }
        },
        etherscan: {
            // Your API key for Etherscan
            // Obtain one at https://etherscan.io/
            apiKey: ''
        },
        sourcify: {
            // Doesn't need an API key
            enabled: true
        },
        solidityCoverage: {
            measureStatementCoverage: true,
            measureFunctionCoverage: true,
            measureBranchCoverage: true,
            measureLineCoverage: true,
            sources: '/contracts/prod/1.1/',
        },
        mocha: {
            timeout: 300000
        }
    }

export default config;
