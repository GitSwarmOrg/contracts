import {BigNumber, Contract, ethers, Wallet} from "ethers";
import * as fs from "node:fs";
import * as assert from "node:assert";
import {expect} from "chai";


const GITSWARM_ACCOUNT_ADDRESS = '0x0634D869e44cB96215bE5251fE9dE0AEE10a52Ce'
const GS_PROJECT_DB_ID = 'gs'
const GS_PROJECT_ID = 0
const ETHEREUM_NODE_ADDRESS = "http://localhost:8545"
const INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
const MANUAL_GAS_LIMIT = 8000000;

const provider = new ethers.providers.JsonRpcProvider(ETHEREUM_NODE_ADDRESS);
const signer = new ethers.Wallet(INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY, provider);

async function deployContractVersionAndWait(
    contractName: string,
    version: string,
    ...deployArgs: any[]
) {
    let basePath = '';
    if (contractName.includes('/')) {
        const pathSegments = contractName.split('/');
        basePath = pathSegments.slice(0, -1).join('/') + '/';
        contractName = pathSegments.pop();
    }

    const artifactsPath = `artifacts/contracts/prod/1.1/${basePath}${contractName}.sol/${contractName}.json`;

    const artifact = JSON.parse(fs.readFileSync(artifactsPath, 'utf8'));
    const contractFactory = new ethers.ContractFactory(artifact.abi, artifact.bytecode, signer);

    console.log(`Deploying ${contractName} with args ${JSON.stringify(deployArgs)}...`);
    const contract = await contractFactory.deploy(...deployArgs, {gasLimit: MANUAL_GAS_LIMIT});
    await contract.deployed();
    console.log(`${contractName} deployed to: ${contract.address}`);

    const deploymentInfo = {
        address: contract.address,
        abi: artifact.abi
    };

    return [contract, deploymentInfo, artifact.abi];
}

async function deployProxyContract(
    name: string,
    admin: string | null,
    privateKey: string,
    proxy: string = "MyTransparentUpgradeableProxy",
) {
    const [logicContract, infoLogic, abiLogic] = await deployContractVersionAndWait(
        name,
        "latest"
    );

    const proxyContractArgs = admin ? [admin] : [];
    const [proxyContract, infoProxy] = await deployContractVersionAndWait(
        `base/${proxy}`,
        "latest",
        logicContract.address,
        ...proxyContractArgs,
        "0x"
    );

    const contractWithSigner = new ethers.Contract(proxyContract.address, abiLogic, signer);

    return [logicContract, contractWithSigner];
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
    GitSwarmToken: ContractDetail;
}

async function initialDeployGsContracts(
    tokenName: string,
    tokenSymbol: string,
    fmSupply: BigNumber,
    tokenBufferAmount: BigNumber,
    privateKey: string
): Promise<Partial<Contracts>> {
    const [contractsManagerLogic, contractsManagerContract] = await deployProxyContract(
        "ContractsManager",
        null,
        privateKey,
        "SelfAdminTransparentUpgradeableProxy"
    );

    let contracts: Partial<Contracts> = {
        Delegates: {args: []},
        Parameters: {args: [GITSWARM_ACCOUNT_ADDRESS]},
        Proposal: {args: []},
        GasStation: {args: []},
        GitSwarmToken: {args: [tokenName, tokenSymbol, GS_PROJECT_DB_ID, fmSupply, tokenBufferAmount]},
        FundsManager: {args: []},
    };

    for (const [name, details] of Object.entries(contracts)) {
        const [logicContract, proxyContract] = await deployProxyContract(
            name,
            contractsManagerContract.address,
            privateKey,
        );
        contracts[name] = {logic: logicContract, proxy: proxyContract, ...details};
    }

    contracts = {
        ContractsManager: {
            proxy: contractsManagerContract,
            logic: contractsManagerLogic,
            args: [],
        },
        ...contracts
    };

    contracts["Token"] = contracts["GitSwarmToken"];
    delete contracts["GitSwarmToken"];

    const contractAddresses = [
        contracts['Delegates']['proxy'].address,
        contracts['FundsManager']['proxy'].address,
        contracts['Parameters']['proxy'].address,
        contracts['Proposal']['proxy'].address,
        contracts['GasStation']['proxy'].address,
        contracts['ContractsManager']['proxy'].address,
    ]

    for (const [name, details] of Object.entries(contracts)) {
        console.log(`calling initialize on ${name} with details ${JSON.stringify(Object.keys(details))} |||| ${JSON.stringify([...(details.args || []), ...contractAddresses])}`)
        await details.proxy.initialize(...(details.args || []), ...contractAddresses);
    }

    return contracts;
}


class TestBase {
    static tokenBufferAmount = ethers.BigNumber.from("10").pow(20);
    static fmSupply = ethers.BigNumber.from("10").pow(20);
    skipDeploy = false;
    private ethAccount?: Wallet;
    private accounts?: any[];
    private fundsManagerContract?: Contract;
    private delegatesContract?: Contract;
    private parametersContract?: Contract;
    private proposalContract?: Contract;
    private gasStationContract?: Contract;
    private contractsManagerContract?: Contract;
    private tokenContract?: Contract;
    private pId?: any;

    async setup() {
        this.accounts = [];
        this.ethAccount = new ethers.Wallet(INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY, provider);
        await sendEth(ethers.utils.parseEther("100"), this.ethAccount.address, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY);

        if (!this.skipDeploy) {
            const contracts = await initialDeployGsContracts("GitSwarm", "GS", TestBase.fmSupply, TestBase.tokenBufferAmount, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY);

            this.delegatesContract = contracts.Delegates.proxy;
            this.fundsManagerContract = contracts.FundsManager.proxy;
            this.parametersContract = contracts.Parameters.proxy;
            this.proposalContract = contracts.Proposal.proxy;
            this.gasStationContract = contracts.GasStation.proxy;
            this.contractsManagerContract = contracts.ContractsManager.proxy;
            this.tokenContract = contracts.Token.proxy;

            const pId = await this.contractsManagerContract.nextProjectId();
            this.pId = pId.sub(1);

            assert.equal(await this.tokenContract.delegatesContract(), this.delegatesContract.address);
            assert.equal(await this.tokenContract.fundsManagerContract(), this.fundsManagerContract.address);
            assert.equal(await this.tokenContract.parametersContract(), this.parametersContract.address);
            assert.equal(await this.tokenContract.proposalContract(), this.proposalContract.address);
            assert.equal(await this.tokenContract.gasStationContract(), this.gasStationContract.address);
            assert.equal(await this.tokenContract.contractsManagerContract(), this.contractsManagerContract.address);
            assert.equal((await this.tokenContract.totalSupply()).toString(), TestBase.fmSupply.add(TestBase.tokenBufferAmount).toString());
            assert.equal((await this.tokenContract.balanceOf(this.ethAccount.address)).toString(), TestBase.tokenBufferAmount.toString());
            assert.equal((await this.tokenContract.balanceOf(this.fundsManagerContract.address)).toString(), TestBase.fmSupply.toString());
            assert.equal((await this.fundsManagerContract.balances(this.pId, this.tokenContract.address)).toString(), TestBase.fmSupply.toString());


            for (let i = 0; i < 4; i++) {
                await this.createTestAccount();
            }
            await this.createTestAccount({tokenAmount: BigNumber.from("10")});
        }
    }

    async createTestAccount({
                                tokenContract = null,
                                tokenAmount = BigNumber.from("10").pow(18),
                                ethAmount = BigNumber.from("10").pow(20)
                            } = {}) {
        if (tokenContract === null) {
            tokenContract = this.tokenContract;
        }
        const account = Wallet.createRandom().connect(provider);
        this.accounts.push(account);

        if (TestBase.tokenBufferAmount.lt(tokenAmount)) {
            throw new Error("Insufficient tokens!");
        }
        if (!ethAmount.isZero()) {
            await sendEth(ethAmount, account.address, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY);
        }
        if (!tokenAmount.isZero()) {
            tokenContract.connect(this.ethAccount)
            await tokenContract.transfer(account.address, tokenAmount);
            TestBase.tokenBufferAmount = TestBase.tokenBufferAmount.sub(tokenAmount);
        }

        console.log(`Created test account ${account.address} with ${tokenAmount.toString()} tokens and ${ethAmount.toString()} eth. Total accounts: ${this.accounts.length}`);
        return account;
    }

}

async function sendEth(amount, to, privateKey, unit = "wei") {
    const sender = new ethers.Wallet(privateKey, provider);
    const tx = {
        to: to,
        value: ethers.utils.parseUnits(amount.toString(), unit),
        gasLimit: MANUAL_GAS_LIMIT
    };
    const transaction = await sender.sendTransaction(tx);
    await transaction.wait();
}

describe("Delegates", function () {
    let testBase;

    before(async function () {
        // This runs once before the first test in this block
        this.testBase = new TestBase();
        await this.testBase.setup();
    });

    it("should handle delegate votes correctly", async function () {
        // Simulate delegating a vote
        await this.testBase.delegatesContract.connect(this.testBase.accounts[0]).delegate(this.testBase.pId, this.testBase.accounts[1].address);

        // Check delegation results
        const delegateOf = await this.testBase.delegatesContract.delegateOf(this.testBase.pId, this.testBase.accounts[0].address);
        assert.equal(delegateOf, this.testBase.accounts[1].address);

        const delegations = await this.testBase.delegatesContract.delegations(this.testBase.pId, this.testBase.accounts[1].address, 0);
        assert.equal(delegations, this.testBase.accounts[0].address);
    });

    it("test delegate vote with insufficient balance", async function () {
    try {
      await this.testBase.delegatesContract.connect(this.testBase.accounts[4]).delegate(this.testBase.pId, this.testBase.accounts[1].address);
      expect.fail("Should have thrown an error");
    } catch (error) {
      expect(error.message).to.include("Not enough voting power");
    }
  });

  it("test delegate vote to self", async function () {
    try {
      await this.testBase.delegatesContract.connect(this.testBase.accounts[0]).delegate(this.testBase.pId, this.testBase.accounts[0].address);
      expect.fail("Should have thrown an error");
    } catch (error) {
      expect(error.message).to.include("Can't delegate to yourself");
    }
  });

  it("test undelegate vote", async function () {
    await this.testBase.delegatesContract.connect(this.testBase.accounts[0]).delegate(this.testBase.pId, this.testBase.accounts[1].address);
    expect(await this.testBase.delegatesContract.delegateOf(this.testBase.pId, this.testBase.accounts[0].address)).to.equal(this.testBase.accounts[1].address);

    await this.testBase.delegatesContract.connect(this.testBase.accounts[0]).undelegate(this.testBase.pId);
    expect(await this.testBase.delegatesContract.delegateOf(this.testBase.pId, this.testBase.accounts[0].address)).to.equal(ethers.constants.AddressZero);
  });

  it("test delegate vote to an address and then to another", async function () {
    await this.testBase.delegatesContract.connect(this.testBase.accounts[0]).delegate(this.testBase.pId, this.testBase.accounts[1].address);
    expect(await this.testBase.delegatesContract.delegateOf(this.testBase.pId, this.testBase.accounts[0].address)).to.equal(this.testBase.accounts[1].address);

    await this.testBase.delegatesContract.connect(this.testBase.accounts[0]).delegate(this.testBase.pId, this.testBase.accounts[2].address);
    expect(await this.testBase.delegatesContract.delegateOf(this.testBase.pId, this.testBase.accounts[0].address)).to.equal(this.testBase.accounts[2].address);
  });
});
