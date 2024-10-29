import * as fs from "node:fs";
import * as assert from "node:assert";
import {expect} from "chai";
import {BaseContract, NonceManager, Numeric, Signer, Wallet} from "ethers";
import hre from "hardhat";
import {
    ContractsManager,
    Delegates,
    ERC20Base,
    FundsManager,
    GasStation,
    Parameters,
    Proposal,
    UpgradableToken
} from "../../typechain-types";

export const ethers = hre.ethers;
export const provider = ethers.provider

export const GITSWARM_ACCOUNT = new ethers.Wallet('26818dd2f0efc09e0ea155634ecfd27cc10694c61fdbcf190e50cd8645387bcf', provider);
export const GS_PROJECT_DB_ID = 'gs'
export const GS_PROJECT_ID = 0
export const INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
export const MANUAL_GAS_LIMIT = 8000000;

export const signer = new ethers.Wallet(INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY, provider);

export function bigIntSerializer(key: any, value: any) {
    if (typeof value === 'bigint') {
        return value.toString();
    }
    return value;
}

export async function increaseTime(seconds: number) {
    await ethers.provider.send('evm_increaseTime', [seconds]);
}

export async function deployContractAndWait(
    {
        contractNameOrPath,
        deployer = null,
        deployArgs = [],
    }: {
        contractNameOrPath: string;
        deployer?: any;
        deployArgs?: any[];
    }
) {
    let basePath = '';
    let contractName = contractNameOrPath;
    if (contractNameOrPath.endsWith('.json')) {
        // @ts-ignore
        contractName = contractNameOrPath.split('/').pop().split('.')[0];
    } else if (contractNameOrPath.includes('/')) {
        const pathSegments = contractNameOrPath.split('/');
        basePath = pathSegments.slice(0, -1).join('/') + '/';
        contractName = pathSegments.pop() as string;
    }

    let artifactsPath;
    if (contractNameOrPath.endsWith('.json')) {
        artifactsPath = contractNameOrPath
    } else if (contractNameOrPath.startsWith('contracts/')) {
        artifactsPath = `artifacts/${contractNameOrPath}.sol/${contractName}.json`;
    } else {
        artifactsPath = `artifacts/contracts/prod/1.1/${basePath}${contractName}.sol/${contractName}.json`;
    }

    const artifact = JSON.parse(fs.readFileSync(artifactsPath, 'utf8'));
    const contractFactory = new ethers.ContractFactory(artifact.abi, artifact.bytecode, new NonceManager(deployer || signer));

    console.log(`Deploying ${contractName} with args ${JSON.stringify(deployArgs, bigIntSerializer)}`);
    const contract = await contractFactory.deploy(...deployArgs);
    await contract.waitForDeployment();
    let address = await contract.getAddress();
    console.log(`${contractName} deployed to: ${address}`);

    const deploymentInfo = {
        address: address,
        abi: artifact.abi
    };

    return [contract, deploymentInfo, artifact.abi];
}

export async function deployProxyContract({
                                              name,
                                              admin = null,
                                              proxy = "MyTransparentUpgradeableProxy",
                                              deployer = signer
                                          }: {
                                              name: string;
                                              admin?: string | null;
                                              proxy?: string;
                                              deployer?: any;
                                          }
) {
    const [logicContract, , abiLogic] = await deployContractAndWait(
        {contractNameOrPath: name, deployer});

    const proxyContractArgs = admin ? [admin] : [];
    const [proxyContract] = await deployContractAndWait({
            contractNameOrPath: `base/${proxy}`,
            deployer,
            deployArgs: [await logicContract.getAddress(),
                ...proxyContractArgs,
                "0x"]
        }
    );

    const proxyWithSigner = new ethers.Contract(await proxyContract.getAddress(), abiLogic, deployer);

    return [logicContract, proxyWithSigner];
}

interface ContractDetail {
    logic?: any;  // Define more specific types instead of `any` based on usage
    proxy?: any;  // Define more specific types instead of `any` based on usage
    args: any[];
}

interface Contracts {
    ContractsManager: ContractDetail;
    Delegates: ContractDetail;
    FundsManager: ContractDetail;
    Parameters: ContractDetail;
    Proposal: ContractDetail;
    GasStation: ContractDetail;
    Token: ContractDetail;
    UpgradableToken: ContractDetail;
}

export async function initialDeployGsContracts(
    tokenName: string,
    tokenSymbol: string,
    tokenBufferAmount: BigInt,
    deployer = undefined,
): Promise<Contracts> {
    const [contractsManagerLogic, contractsManagerContract] = await deployProxyContract({
            name: "ContractsManager",
            deployer,
            proxy: "SelfAdminTransparentUpgradeableProxy"
        }
    );

    let contracts: Partial<Contracts> = {
        Delegates: {args: []},
        Parameters: {args: [GITSWARM_ACCOUNT.address]},
        Proposal: {args: []},
        GasStation: {args: []},
        UpgradableToken: {args: [tokenName, tokenSymbol, GS_PROJECT_DB_ID, tokenBufferAmount]},
        FundsManager: {args: []},
    };

    for (const [name, details] of Object.entries(contracts)) {
        const [logicContract, proxyContract] = await deployProxyContract({
                name,
                admin: await contractsManagerContract.getAddress(),
                deployer
            }
        );
        contracts[name as keyof Contracts] = {logic: logicContract, proxy: proxyContract, ...details};
    }

    contracts = {
        ContractsManager: {
            proxy: contractsManagerContract,
            logic: contractsManagerLogic,
            args: [],
        },
        ...contracts
    };

    contracts["Token"] = contracts["UpgradableToken"];
    delete contracts["UpgradableToken"];

    const contractAddresses = [
        // @ts-ignore
        await contracts['Delegates']['proxy'].getAddress(),
        // @ts-ignore
        await contracts['FundsManager']['proxy'].getAddress(),
        // @ts-ignore
        await contracts['Parameters']['proxy'].getAddress(),
        // @ts-ignore
        await contracts['Proposal']['proxy'].getAddress(),
        // @ts-ignore
        await contracts['GasStation']['proxy'].getAddress(),
        // @ts-ignore
        await contracts['ContractsManager']['proxy'].getAddress(),
    ]

    for (const [name, details] of Object.entries(contracts)) {
        console.log(`calling initialize on ${name} with details ${JSON.stringify(Object.keys(details), bigIntSerializer)} |||| ${JSON.stringify([...(details.args || []), ...contractAddresses], bigIntSerializer)}`)
        const tx = await details.proxy.initialize(...(details.args || []), ...contractAddresses);
        await tx.wait(); // Wait for the transaction to be mined
    }

    return contracts as Contracts;
}


export class TestBase {
    static DAY = 86400;
    static tokenBufferAmount = 10n ** 20n;
    static fmSupply = 10n ** 20n;
    static TEST_ACCOUNT_DEFAULT_TOKEN_AMOUNT = 10n ** 18n;
    static TEST_ACCOUNT_DEFAULT_ETH_AMOUNT = 10n ** 20n;
    static VOTE_DURATION = 3 * TestBase.DAY + 3
    static EXPIRATION_PERIOD = 7 * TestBase.DAY
    static BUFFER_BETWEEN_END_OF_VOTING_AND_EXECUTE_PROPOSAL: number = 3 * TestBase.DAY;
    static DECIMALS: bigint = 10n ** 18n;
    skipDeploy = false;
    ethAccount!: Wallet;
    accounts!: any[];
    fundsManagerContract!: FundsManager;
    delegatesContract!: Delegates;
    parametersContract!: Parameters;
    proposalContract!: Proposal;
    gasStationContract!: GasStation;
    contractsManagerContract!: ContractsManager;
    tokenContract!: ERC20Base;
    UpgradableTokenContract!: UpgradableToken;
    pId!: any;
    ethNonceMgAccount: any;

    async setup() {
        this.accounts = [];
        this.ethAccount = new ethers.Wallet(INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY, provider);
        this.ethNonceMgAccount = new NonceManager(this.ethAccount)
        await sendEth(ethers.parseEther("100"), this.ethAccount.address, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY);

        if (!this.skipDeploy) {
            const contracts = await initialDeployGsContracts(
                "GitSwarm",
                "GS",
                TestBase.tokenBufferAmount
            );

            this.delegatesContract = contracts.Delegates.proxy;
            this.fundsManagerContract = contracts.FundsManager.proxy;
            this.parametersContract = contracts.Parameters.proxy;
            this.proposalContract = contracts.Proposal.proxy;
            this.gasStationContract = contracts.GasStation.proxy;
            this.contractsManagerContract = contracts.ContractsManager.proxy;
            this.tokenContract = contracts.Token.proxy;
            this.UpgradableTokenContract = contracts.Token.proxy;

            const pId = await this.contractsManagerContract.nextProjectId();
            this.pId = pId - 1n;

            assert.equal(await this.tokenContract.delegatesContract(), await this.delegatesContract.getAddress());
            assert.equal(await this.tokenContract.fundsManagerContract(), await this.fundsManagerContract.getAddress());
            assert.equal(await this.tokenContract.parametersContract(), await this.parametersContract.getAddress());
            assert.equal(await this.tokenContract.proposalContract(), await this.proposalContract.getAddress());
            assert.equal(await this.tokenContract.gasStationContract(), await this.gasStationContract.getAddress());
            assert.equal(await this.tokenContract.contractsManagerContract(), await this.contractsManagerContract.getAddress());
            assert.equal((await this.tokenContract.totalSupply()).toString(), TestBase.tokenBufferAmount);
            assert.equal((await this.tokenContract.balanceOf(await this.ethAccount.getAddress())), TestBase.tokenBufferAmount);
        }
    }

    async setTrustedAddress(trustedAddress: any) {
        const proposalId = await this.proposalContract.nextProposalId(this.pId);

        await this.parametersContract.proposeChangeTrustedAddress(this.pId, trustedAddress, true);

        await increaseTime(TestBase.VOTE_DURATION + 5);
        await this.processProposal(this.parametersContract, proposalId, this.pId, true);

        expect(await this.parametersContract.isTrustedAddress(this.pId, trustedAddress)).to.be.true;
    }

    async resetProjectAndAccounts({createAccounts = true, tokenContract = 'FixedSupplyToken'} = {}) {
        this.accounts = []
        this.pId = await this.contractsManagerContract.nextProjectId();
        [this.tokenContract] = await deployContractAndWait({
                contractNameOrPath: tokenContract,
                deployArgs: ['PROJECT_ID',
                    TestBase.tokenBufferAmount,
                    await this.contractsManagerContract.getAddress(),
                    await this.fundsManagerContract.getAddress(),
                    await this.proposalContract.getAddress(),
                    await this.parametersContract.getAddress(),
                    "GitSwarm",
                    "GS"]
            }
        )
        if (createAccounts) {
            await this.createFiveTestAccounts()
        }
    }

    async createTestAccount({
                                tokenContract = null,
                                tokenAmount = TestBase.TEST_ACCOUNT_DEFAULT_TOKEN_AMOUNT,
                                ethAmount = TestBase.TEST_ACCOUNT_DEFAULT_ETH_AMOUNT
                            }: {
        tokenContract?: ERC20Base | null,
        tokenAmount?: bigint,
        ethAmount?: bigint
    } = {}) {
        if (tokenContract === null) {
            // @ts-ignore
            tokenContract = this.tokenContract as ERC20Base;
        }
        const account = Wallet.createRandom().connect(provider);
        this.accounts.push(account);

        let balance = await tokenContract.balanceOf(signer.address);
        if (balance < tokenAmount) {
            throw new Error(`Insufficient tokens! Buffer amount is ${balance}, requested amount is ${tokenAmount}`);
        }
        if (ethAmount !== 0n) {
            await sendEth(ethAmount, account.address, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY);
        }
        if (tokenAmount !== 0n) {
            const noncyTokenContract = tokenContract.connect(new NonceManager(this.ethAccount))
            const tx = await noncyTokenContract.transfer(account.address, tokenAmount);
            await tx.wait()
        }

        console.log(`Created test account ${account.address} with ${tokenAmount.toString()} tokens and ${ethAmount.toString()} eth. Total accounts: ${this.accounts.length}`);
        return account;
    }

    async createFiveTestAccounts() {
        for (let i = 0; i < 4; i++) {
            await this.createTestAccount();
        }
        await this.createTestAccount({tokenAmount: 10n});
    }


    async processProposal(contract: BaseContract, proposalId: Numeric, contractProjectId: Numeric, expectToExecute = false, expectToNotExecute = false, options = {}) {
        const txList = [await this.proposalContract.lockVoteCount(contractProjectId, proposalId, options)];
        await txList[0].wait()
        const proposal = await this.proposalContract.proposals(contractProjectId, proposalId);

        if (expectToExecute && !proposal.willExecute) {
            throw new Error('Expected proposal to execute but the vote did not pass.');
        }
        if (expectToNotExecute && proposal.willExecute) {
            throw new Error('Expected proposal not to execute but the vote did pass.');
        }

        await increaseTime(TestBase.BUFFER_BETWEEN_END_OF_VOTING_AND_EXECUTE_PROPOSAL + 5);
        if (await contract.getAddress() == await this.tokenContract.getAddress() ||
            await contract.getAddress() == await this.gasStationContract.getAddress()) {
            // @ts-ignore
            txList.push(await contract.executeProposal(proposalId, options));
        } else {
            // @ts-ignore
            txList.push(await contract.executeProposal(contractProjectId, proposalId, options));
        }

        return txList;
    }
}

export async function sendEth(amount: string | Numeric, to: string, signer: Signer | string, unit = "wei") {
    let sender;
    if (typeof signer === 'string') {
        sender = new NonceManager(new ethers.Wallet(signer, provider));
    } else {
        sender = signer
    }
    console.log(`Sending ${amount} to ${to} from ${await sender.getAddress()}`);
    const tx = {
        to: to,
        value: ethers.parseUnits(amount.toString(), unit),
        gasLimit: 21000
    };
    const transaction = await sender.sendTransaction(tx);
    await transaction.wait();
}
