import {deployContractAndWait, increaseTime, signer, TestBase} from "./testUtils";
import hre from "hardhat";
import {expect} from "chai";
import {ERC20Base} from "../../typechain-types/prod/1.1/base";
import {BigNumberish, NonceManager, Typed} from "ethers";

const ethers = hre.ethers;
describe("FundsManagerTests", function () {
    const DECIMALS = 10n ** 18n;
    let c: TestBase;
    let neptuneTokenContract: ERC20Base;
    let saturnTokenContract: ERC20Base;
    let failTransferContract: ERC20Base;
    let failTransferFromContract: ERC20Base;

    before(async function () {
        c = new TestBase();
        await c.setup();
    });

    beforeEach(async function () {
        await c.resetProjectAndAccounts({createAccounts: false});

        [neptuneTokenContract] = await deployContractAndWait({
                contractNameOrPath: "ExpandableSupplyToken",
                deployArgs: ["PROJ_DB_ID",
                    10000n * DECIMALS,
                    1000n * DECIMALS,
                    await c.contractsManagerContract.getAddress(),
                    await c.fundsManagerContract.getAddress(),
                    await c.proposalContract.getAddress(),
                    await c.parametersContract.getAddress(),
                    "Neptune",
                    "NP"]
            }
        );


        neptuneTokenContract = neptuneTokenContract.connect(new NonceManager(signer))

        let saturnDeployment = await deployContractAndWait({
                contractNameOrPath: "ExpandableSupplyToken",
                deployArgs: ["PROJ_DB_ID2",
                    10000n * DECIMALS,
                    1000n * DECIMALS,
                    await c.contractsManagerContract.getAddress(),
                    await c.fundsManagerContract.getAddress(),
                    await c.proposalContract.getAddress(),
                    await c.parametersContract.getAddress(),
                    "Saturn",
                    "ST"]
            }
        );
        saturnTokenContract = saturnDeployment[0].connect(new NonceManager(signer))

        await c.createTestAccount();
        await c.createTestAccount({tokenAmount: 75n * DECIMALS});
    });

    async function reclaimBase(depositEth: boolean) {
        await neptuneTokenContract.approve(await c.fundsManagerContract.getAddress(), 100n * DECIMALS);
        await c.fundsManagerContract.depositToken(c.pId, await neptuneTokenContract.getAddress(), 100n * DECIMALS);
        expect(await c.fundsManagerContract.balances(c.pId, await neptuneTokenContract.getAddress())).to.equal(100n * DECIMALS);

        await saturnTokenContract.approve(await c.fundsManagerContract.getAddress(), 200n * DECIMALS);
        await c.fundsManagerContract.depositToken(c.pId, await saturnTokenContract.getAddress(), 200n * DECIMALS);
        expect(await c.fundsManagerContract.balances(c.pId, await saturnTokenContract.getAddress())).to.equal(200n * DECIMALS);

        if (depositEth) {
            await c.fundsManagerContract.depositEth(c.pId, {value: ethers.parseEther("1")});
        }

        await c.tokenContract.connect(c.accounts[1]).approve(await c.fundsManagerContract.getAddress(), 50n * DECIMALS);

        const ethBalanceBefore = await ethers.provider.getBalance(c.accounts[1].address);
        const tokenContractsAddresses = [
            await neptuneTokenContract.getAddress(),
            await saturnTokenContract.getAddress(),
            await c.tokenContract.getAddress()
        ];
        const tx = await c.fundsManagerContract.connect(c.accounts[1]).reclaimFunds(c.pId, 50n * DECIMALS, tokenContractsAddresses);
        const receipt = await tx.wait();

        const ethBalanceAfter = await ethers.provider.getBalance(c.accounts[1].address);

        // @ts-ignore
        let gasCost = receipt.gasUsed * BigInt(receipt.effectiveGasPrice || receipt.gasPrice);
        if (depositEth) {
            expect(gasCost + ethBalanceAfter - ethBalanceBefore).to.equal(ethers.parseEther("0.5"));
        } else {
            expect(ethBalanceBefore).to.equal(ethBalanceAfter + gasCost);
        }
        expect(await ethers.provider.getBalance(await c.fundsManagerContract.getAddress())).to.equal(ethers.parseEther("0.5"));
        expect(await c.tokenContract.balanceOf(c.accounts[1].address)).to.equal(25n * DECIMALS);
        expect(await neptuneTokenContract.balanceOf(c.accounts[1].address)).to.equal(50n * DECIMALS);
        expect(await saturnTokenContract.balanceOf(c.accounts[1].address)).to.equal(100n * DECIMALS);
    }

    it("should prevent re-initialization", async function () {
        try {
            await c.fundsManagerContract.initialize(ethers.ZeroAddress, ethers.ZeroAddress, ethers.ZeroAddress, ethers.ZeroAddress, ethers.ZeroAddress, ethers.ZeroAddress);
            expect.fail("Should have thrown an error on second initialization");
        } catch (error) {
            expect((error as Error).message).to.include("InvalidInitialization");
        }
    });

    it("should fail with unexpected proposal type", async function () {
        const proposalId = await c.proposalContract.nextProposalId(c.pId);
        await c.parametersContract.proposeParameterChange(c.pId, ethers.keccak256(ethers.toUtf8Bytes("VoteDuration")), TestBase.VOTE_DURATION - 42);
        await increaseTime(TestBase.VOTE_DURATION + 5);
        await expect(c.processProposal(c.fundsManagerContract, proposalId, c.pId, true))
            .to.be.revertedWith("Unexpected proposal type");
    });

    it("should reclaim funds", async function () {
        await reclaimBase(true)
    });

    it("should reclaim funds without ether", async function () {
        await reclaimBase(false)
    });


    it("should fail to reclaim funds with insufficient balance", async function () {
        await c.tokenContract.connect(c.accounts[1]).transfer(await c.fundsManagerContract.getAddress(), 75n * DECIMALS);
        await c.tokenContract.connect(c.accounts[1]).approve(await c.fundsManagerContract.getAddress(), 20000n * DECIMALS);

        await expect(c.fundsManagerContract.connect(c.accounts[1]).reclaimFunds(c.pId, 5000n * DECIMALS, []))
            .to.be.revertedWith("insufficient balance");
    });

    it("should fail to reclaim funds for token contracts for which FM has no balance", async function () {
        await c.fundsManagerContract.depositEth(c.pId, {value: ethers.parseEther("1")});
        const tokenContractsAddresses = [await neptuneTokenContract.getAddress(), await saturnTokenContract.getAddress()];
        const ethBalanceBefore = await ethers.provider.getBalance(c.accounts[1].address);
        const fundsManagerBalance = await c.tokenContract.balanceOf(await c.fundsManagerContract.getAddress());

        await expect(c.fundsManagerContract.connect(c.accounts[1]).reclaimFunds(c.pId, 50n * DECIMALS, tokenContractsAddresses))
            .to.be.revertedWith("insufficient allowance");

        expect(await ethers.provider.getBalance(c.accounts[1].address)).to.be.lte(ethBalanceBefore);
        expect(await c.tokenContract.balanceOf(await c.fundsManagerContract.getAddress())).to.equal(fundsManagerBalance);
        expect(await c.tokenContract.balanceOf(c.accounts[1].address)).to.equal(75n * DECIMALS);
        expect(await neptuneTokenContract.balanceOf(c.accounts[1].address)).to.equal(0n);
        expect(await saturnTokenContract.balanceOf(c.accounts[1].address)).to.equal(0n);
    });

    it("should fail to reclaim funds with no approval", async function () {
        await neptuneTokenContract.transfer(await c.fundsManagerContract.getAddress(), 100n * DECIMALS);
        await saturnTokenContract.transfer(await c.fundsManagerContract.getAddress(), 200n * DECIMALS);
        await c.fundsManagerContract.depositEth(c.pId, {value: ethers.parseEther("1")});

        const ethBalanceBefore = await ethers.provider.getBalance(c.accounts[1].address);
        const fundsManagerBalance = await c.tokenContract.balanceOf(await c.fundsManagerContract.getAddress());
        const tokenContractsAddresses = [await neptuneTokenContract.getAddress(), await saturnTokenContract.getAddress()];

        await expect(c.fundsManagerContract.connect(c.accounts[1]).reclaimFunds(c.pId, 50n * DECIMALS, tokenContractsAddresses))
            .to.be.revertedWith("insufficient allowance");

        expect(await ethers.provider.getBalance(c.accounts[1].address)).to.be.lte(ethBalanceBefore);
        expect(await c.tokenContract.balanceOf(await c.fundsManagerContract.getAddress())).to.equal(fundsManagerBalance);
        expect(await c.tokenContract.balanceOf(c.accounts[1].address)).to.equal(75n * DECIMALS);
        expect(await neptuneTokenContract.balanceOf(c.accounts[1].address)).to.equal(0n);
        expect(await saturnTokenContract.balanceOf(c.accounts[1].address)).to.equal(0n);
    });

    it("should fail to reclaim funds after balance of reclaimer was changed", async function () {
        await neptuneTokenContract.transfer(await c.fundsManagerContract.getAddress(), 100n * DECIMALS);
        await saturnTokenContract.transfer(await c.fundsManagerContract.getAddress(), 200n * DECIMALS);
        await c.fundsManagerContract.depositEth(c.pId, {value: ethers.parseEther("1")});

        await c.tokenContract.connect(c.accounts[1]).approve(await c.fundsManagerContract.getAddress(), 50n * DECIMALS);
        await c.tokenContract.connect(c.accounts[1]).transfer(c.accounts[0].address, 50n * DECIMALS);

        const ethBalanceBefore = await ethers.provider.getBalance(c.accounts[1].address);
        const fundsManagerBalance = await c.tokenContract.balanceOf(await c.fundsManagerContract.getAddress());
        const tokenContractsAddresses = [await neptuneTokenContract.getAddress(), await saturnTokenContract.getAddress()];

        await expect(c.fundsManagerContract.connect(c.accounts[1]).reclaimFunds(c.pId, 50n * DECIMALS, tokenContractsAddresses))
            .to.be.revertedWith("insufficient balance");

        expect(await ethers.provider.getBalance(c.accounts[1].address)).to.be.lte(ethBalanceBefore);
        expect(await c.tokenContract.balanceOf(await c.fundsManagerContract.getAddress())).to.equal(fundsManagerBalance);
        expect(await c.tokenContract.balanceOf(c.accounts[1].address)).to.equal(25n * DECIMALS);
        expect(await neptuneTokenContract.balanceOf(c.accounts[1].address)).to.equal(0n);
        expect(await saturnTokenContract.balanceOf(c.accounts[1].address)).to.equal(0n);
    });

    it("should send orphan tokens to GitSwarm", async function () {
        const orphanTokenContract = await deployContractAndWait({
                contractNameOrPath: "ExpandableSupplyToken",
                deployArgs: [
                    "ORPHAN_TOKEN",
                    10000n * DECIMALS,
                    1000n * DECIMALS,
                    await c.contractsManagerContract.getAddress(),
                    await c.fundsManagerContract.getAddress(),
                    await c.proposalContract.getAddress(),
                    await c.parametersContract.getAddress(),
                    "Orphan",
                    "ORP"]
            }
        );

        await orphanTokenContract[0].transfer(await c.fundsManagerContract.getAddress(), 500n * DECIMALS);

        const gitSwarmBalanceBefore = await c.fundsManagerContract.balances(0, await orphanTokenContract[0].getAddress());
        await c.fundsManagerContract.sendOrphanTokensToGitSwarm(await orphanTokenContract[0].getAddress());
        const gitSwarmBalanceAfter = await c.fundsManagerContract.balances(0, await orphanTokenContract[0].getAddress());

        expect(gitSwarmBalanceAfter).to.equal(gitSwarmBalanceBefore + 500n * DECIMALS);
    });
    /////////////////////////////////////////////////
    it("should retrieve transaction proposal details", async function () {
        const tokenContractAddress = [await neptuneTokenContract.getAddress(), await saturnTokenContract.getAddress()];
        const amount = [100n * DECIMALS, 200n * DECIMALS];
        const to = [c.accounts[0].address, c.accounts[1].address];
        const depositToProjectId = [1, 2];

        await c.fundsManagerContract.proposeTransaction(c.pId, tokenContractAddress, amount, to, depositToProjectId);

        const proposalId = await c.proposalContract.nextProposalId(c.pId) - 1n;
        const [token, retrievedAmount, retrievedTo, retrievedDepositToProjectId] = await c.fundsManagerContract.transactionProposal(c.pId, proposalId);

        expect(token).to.deep.equal(tokenContractAddress);
        expect(retrievedAmount).to.deep.equal(amount);
        expect(retrievedTo).to.deep.equal(to);
        expect(retrievedDepositToProjectId).to.deep.equal(depositToProjectId);
    });

    it("should execute transaction proposal", async function () {
        const tokenContractAddress = [await neptuneTokenContract.getAddress(),
            await saturnTokenContract.getAddress(),
            ethers.ZeroAddress,
            ethers.ZeroAddress
        ];
        const amount = [100n * DECIMALS, 200n * DECIMALS, 1n * DECIMALS, 2n * DECIMALS];
        const to = [c.accounts[0].address,
            ethers.ZeroAddress,
            c.accounts[0].address,
            await c.gasStationContract.getAddress()];
        const depositToProjectId = [0, c.pId, 0, 0];

        await neptuneTokenContract.approve(await c.fundsManagerContract.getAddress(), amount[0])
        await saturnTokenContract.approve(await c.fundsManagerContract.getAddress(), amount[1])

        await c.fundsManagerContract.depositToken(c.pId, await neptuneTokenContract.getAddress(), amount[0]);
        await c.fundsManagerContract.depositToken(c.pId, await saturnTokenContract.getAddress(), amount[1]);
        await c.fundsManagerContract.depositEth(c.pId, {value: ethers.parseEther("11")});

        await c.fundsManagerContract.proposeTransaction(c.pId, tokenContractAddress, amount, to, depositToProjectId);

        const proposalId = await c.proposalContract.nextProposalId(c.pId) - 1n;


        const ethBalanceBefore = await ethers.provider.getBalance(c.accounts[0].address);
        await increaseTime(TestBase.VOTE_DURATION + 5);

        await c.proposalContract.lockVoteCount(c.pId, proposalId)
        await increaseTime(TestBase.BUFFER_BETWEEN_END_OF_VOTING_AND_EXECUTE_PROPOSAL + 15);
        await expect(await c.fundsManagerContract.executeProposal(c.pId, proposalId))
            .to.emit(c.gasStationContract, 'BuyGasEvent')
            .withArgs(c.pId, amount[3]);

        const ethBalanceAfter = await ethers.provider.getBalance(c.accounts[0].address);

        expect(await neptuneTokenContract.balanceOf(c.accounts[0].address)).to.equal(amount[0]);
        expect(await c.fundsManagerContract.balances(c.pId, tokenContractAddress[1])).to.equal(amount[1]);
        expect(ethBalanceAfter - ethBalanceBefore).to.equal(amount[2]);
    });

    it("should send tokens", async function () {
        await c.setTrustedAddress(signer.address)
        await neptuneTokenContract.approve(await c.fundsManagerContract.getAddress(), 500n * DECIMALS)
        await c.fundsManagerContract.depositToken(c.pId, await neptuneTokenContract.getAddress(), 100n * DECIMALS);

        await c.fundsManagerContract.sendToken(c.pId, await neptuneTokenContract.getAddress(), c.accounts[0].address, 50n * DECIMALS);

        expect(await neptuneTokenContract.balanceOf(c.accounts[0].address)).to.equal(50n * DECIMALS);
        expect(await c.fundsManagerContract.balances(c.pId, await neptuneTokenContract.getAddress())).to.equal(50n * DECIMALS);
    });

    it("should send ether", async function () {
        await c.setTrustedAddress(signer.address)
        await c.fundsManagerContract.depositEth(c.pId, {value: ethers.parseEther("1")});

        const ethBalanceBefore = await ethers.provider.getBalance(c.accounts[0].address);
        await c.fundsManagerContract.sendEther(c.pId, c.accounts[0].address, ethers.parseEther("0.5"));
        const ethBalanceAfter = await ethers.provider.getBalance(c.accounts[0].address);

        expect(ethBalanceAfter).to.equal(ethBalanceBefore + ethers.parseEther("0.5"));
        expect(await c.fundsManagerContract.balances(c.pId, ethers.ZeroAddress)).to.equal(ethers.parseEther("0.5"));
    });

    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////

    it("should fail to deposit tokens with insufficient allowance", async function () {
        await deployFailTransferFromContract()
        await failTransferFromContract.approve(await c.fundsManagerContract.getAddress(), 99999999999n * DECIMALS);
        await expect(c.fundsManagerContract.depositToken(c.pId, await failTransferFromContract.getAddress(), 100n * DECIMALS))
            .to.be.revertedWithCustomError(c.fundsManagerContract, "SafeERC20FailedOperation");
    });

    it("should fail to propose transaction with empty amount list", async function () {
        const tokenContractAddress = [await neptuneTokenContract.getAddress(), await saturnTokenContract.getAddress()];
        const amount: bigint[] = [];
        const to = [c.accounts[0].address, c.accounts[1].address];
        const depositToProjectId = [1, 2];

        await expect(c.fundsManagerContract.proposeTransaction(c.pId, tokenContractAddress, amount, to, depositToProjectId))
            .to.be.revertedWith("Amount can't be an empty list.");
    });

    it("should fail to propose transaction with mismatched array lengths", async function () {
        const tokenContractAddress = [await neptuneTokenContract.getAddress(), await saturnTokenContract.getAddress()];
        const amount = [100n * DECIMALS];
        const to = [c.accounts[0].address, c.accounts[1].address];
        const depositToProjectId = [1, 2];

        await expect(c.fundsManagerContract.proposeTransaction(c.pId, tokenContractAddress, amount, to, depositToProjectId))
            .to.be.revertedWith("'amount', 'to' and 'depositToProjectId' arrays must have equal length");
    });

    it("should fail to propose transaction with zero amount", async function () {
        const tokenContractAddress = [await neptuneTokenContract.getAddress(), await saturnTokenContract.getAddress()];
        const amount = [100n * DECIMALS, 0n];
        const to = [c.accounts[0].address, c.accounts[1].address];
        const depositToProjectId = [1, 2];

        await expect(c.fundsManagerContract.proposeTransaction(c.pId, tokenContractAddress, amount, to, depositToProjectId))
            .to.be.revertedWith("Amount must be greater than 0.");
    });

    it("should fail to execute non-existent proposal", async function () {
        const proposalId = 999;

        await expect(c.fundsManagerContract.executeProposal(c.pId, proposalId))
            .to.be.revertedWith("Proposal does not exist");
    });

    it("should fail to execute proposal before buffer time ends", async function () {
        const tokenContractAddress = [await neptuneTokenContract.getAddress(), await saturnTokenContract.getAddress()];
        const amount = [100n * DECIMALS, 200n * DECIMALS];
        const to = [c.accounts[0].address, c.accounts[1].address];
        const depositToProjectId = [1, 2];

        await c.fundsManagerContract.proposeTransaction(c.pId, tokenContractAddress, amount, to, depositToProjectId);

        const proposalId = await c.proposalContract.nextProposalId(c.pId) - 1n;

        await expect(c.fundsManagerContract.executeProposal(c.pId, proposalId))
            .to.be.revertedWith("Can't execute proposal, buffer time did not end yet");
    });

    it("should fail to execute proposal after expiration period", async function () {
        const tokenContractAddress = [await neptuneTokenContract.getAddress(), await saturnTokenContract.getAddress()];
        const amount = [100n * DECIMALS, 200n * DECIMALS];
        const to = [c.accounts[0].address, c.accounts[1].address];
        const depositToProjectId = [1, 2];

        await c.fundsManagerContract.proposeTransaction(c.pId, tokenContractAddress, amount, to, depositToProjectId);

        const proposalId = await c.proposalContract.nextProposalId(c.pId) - 1n;

        await increaseTime(TestBase.VOTE_DURATION + TestBase.EXPIRATION_PERIOD + 15);

        await expect(c.fundsManagerContract.executeProposal(c.pId, proposalId))
            .to.be.revertedWith("Can't execute proposal, execute period has expired");
    });

    it("should fail to execute rejected proposal", async function () {
        const tokenContractAddress = [await neptuneTokenContract.getAddress(), await saturnTokenContract.getAddress()];
        const amount = [100n * DECIMALS, 200n * DECIMALS];
        const to = [c.accounts[0].address, c.accounts[1].address];
        const depositToProjectId: BigNumberish[] = [0, 0];

        await c.fundsManagerContract.proposeTransaction(c.pId, tokenContractAddress, amount, to, depositToProjectId);

        const proposalId = await c.proposalContract.nextProposalId(c.pId) - 1n;

        await increaseTime(TestBase.VOTE_DURATION + 5);

        await expect(c.fundsManagerContract.executeProposal(c.pId, proposalId))
            .to.be.revertedWith("Can't execute, proposal was rejected or vote count was not locked");
    });

    it("should fail to reclaim funds with insufficient allowance", async function () {
        await expect(c.fundsManagerContract.reclaimFunds(c.pId, 100n * DECIMALS, [await neptuneTokenContract.getAddress()]))
            .to.be.revertedWith("insufficient allowance");
    });

    it("should fail to reclaim funds with insufficient balance", async function () {
        await c.tokenContract.connect(c.accounts[0]).approve(await c.fundsManagerContract.getAddress(), 100n * DECIMALS);

        await expect(c.fundsManagerContract.connect(c.accounts[0]).reclaimFunds(c.pId, 100n * DECIMALS, [await neptuneTokenContract.getAddress()]))
            .to.be.revertedWith("insufficient balance");
    });
    it("should fail with 'Token transfer from failed'", async function () {
        let projectId = await c.contractsManagerContract.nextProjectId();
        await deployFailTransferFromContract()
        await failTransferFromContract.approve(await c.fundsManagerContract.getAddress(), 9999999999n * DECIMALS)
        await expect(c.fundsManagerContract.reclaimFunds(projectId, 1n * DECIMALS, [ethers.ZeroAddress]))
            .to.be.revertedWithCustomError(c.fundsManagerContract, "SafeERC20FailedOperation");
    });

    async function deployFailTransferContract() {
        [failTransferContract] = await deployContractAndWait({
            contractNameOrPath: "contracts/test/ERC20FailTransfer",
            deployArgs: ["PROJ_DB_ID",
                10000n * DECIMALS,
                1000n * DECIMALS,
                await c.contractsManagerContract.getAddress(),
                await c.fundsManagerContract.getAddress(),
                await c.proposalContract.getAddress(),
                await c.parametersContract.getAddress(),
                "Fail32",
                "FFF"
            ]
        });
    }

    async function deployFailTransferFromContract() {
        [failTransferFromContract] = await deployContractAndWait({
            contractNameOrPath: "contracts/test/ERC20FailTransferFrom",
            deployArgs: [
                "PROJ_DB_ID",
                10000n * DECIMALS,
                1000n * DECIMALS,
                await c.contractsManagerContract.getAddress(),
                await c.fundsManagerContract.getAddress(),
                await c.proposalContract.getAddress(),
                await c.parametersContract.getAddress(),
                "Fail32",
                "FFF"
            ]
        });
    }

    it("should fail to reclaim funds with token transfer failure", async function () {
        await deployFailTransferContract();
        await failTransferContract.approve(await c.fundsManagerContract.getAddress(), 100n * DECIMALS);
        await c.fundsManagerContract.depositToken(c.pId, await failTransferContract.getAddress(), 100n * DECIMALS);

        await c.tokenContract.connect(c.accounts[0]).approve(await c.fundsManagerContract.getAddress(), 100n * DECIMALS);
        await expect(c.fundsManagerContract.connect(c.accounts[0]).reclaimFunds(c.pId, 1n * DECIMALS, [await failTransferContract.getAddress()]))
            .to.be.revertedWithCustomError(c.fundsManagerContract, "SafeERC20FailedOperation");
    });

    it("should fail to send tokens with insufficient balance", async function () {
        await c.setTrustedAddress(signer.address);

        await expect(c.fundsManagerContract.sendToken(c.pId, await neptuneTokenContract.getAddress(), c.accounts[0].address, 100n * DECIMALS))
            .to.be.revertedWith("Not enough tokens on FundsManager");
    });

    it("should fail to send tokens with token transfer failure", async function () {
        await deployFailTransferContract();
        await c.setTrustedAddress(signer.address);
        await failTransferContract.connect(new NonceManager(signer)).approve(await c.fundsManagerContract.getAddress(), 100n * DECIMALS);
        await c.fundsManagerContract.depositToken(c.pId, await failTransferContract.getAddress(), 100n * DECIMALS);

        await expect(c.fundsManagerContract.sendToken(c.pId, await failTransferContract.getAddress(), c.accounts[0].address, 100n * DECIMALS))
            .to.be.revertedWithCustomError(c.fundsManagerContract, "SafeERC20FailedOperation");
    });

    it("should fail to send ether with insufficient balance", async function () {
        await c.setTrustedAddress(signer.address);

        await expect(c.fundsManagerContract.sendEther(c.pId, c.accounts[0].address, ethers.parseEther("1")))
            .to.be.revertedWith("Not enough Ether on FundsManager");
    });

    it("should fail to update balance from non-trusted address", async function () {
        await expect(c.fundsManagerContract.connect(c.accounts[0]).sendToken(c.pId, ethers.ZeroAddress, ethers.ZeroAddress, 100n * DECIMALS))
            .to.be.revertedWith("Restricted function");
        await expect(c.fundsManagerContract.connect(c.accounts[0]).sendEther(c.pId, ethers.ZeroAddress, 100n * DECIMALS))
            .to.be.revertedWith("Restricted function");
        await expect(c.fundsManagerContract.connect(c.accounts[0]).updateBalance(c.pId, ethers.ZeroAddress, 100n * DECIMALS))
            .to.be.revertedWith("Restricted function");
    });
});
