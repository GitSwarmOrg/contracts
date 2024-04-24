import {HardhatUserConfig} from "hardhat/config"

import "hardhat-deploy"
import "@nomiclabs/hardhat-solhint"
import "@nomicfoundation/hardhat-ethers"
import "@typechain/hardhat"
import "@nomicfoundation/hardhat-chai-matchers"
import "solidity-coverage"

const config: HardhatUserConfig =
    {
        solidity: {
            version: '0.8.20',
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
            }
        },
        // @ts-ignore
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
