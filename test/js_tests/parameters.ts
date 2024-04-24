import {expect} from 'chai';
import hre from "hardhat";
import {Signer} from 'ethers';
import {GITSWARM_ACCOUNT, GITSWARM_ACCOUNT_ADDRESS, increaseTime, sendEth, signer, TestBase} from "./testUtils";

const ethers = hre.ethers;



describe('Parameters', function () {
    let owner: Signer;
    let c: TestBase;

    before(async function () {
        c = new TestBase();
        await c.setup();
    });

    beforeEach(async function () {
        await c.resetProjectAndAccounts({createAccounts: true});
    });

    it("should prevent re-initialization", async function () {
        try {
            await c.parametersContract.initialize(ethers.ZeroAddress,
                ethers.ZeroAddress,
                ethers.ZeroAddress,
                ethers.ZeroAddress,
                ethers.ZeroAddress,
                ethers.ZeroAddress,
                ethers.ZeroAddress);
            expect.fail("Should have thrown an error on second initialization");
        } catch (error) {
            expect((error as Error).message).to.include("InvalidInitialization");
        }

        await expect(c.parametersContract.initialize(ethers.ZeroAddress,
            ethers.ZeroAddress,
            ethers.ZeroAddress,
            ethers.ZeroAddress,
            ethers.ZeroAddress,
            ethers.ZeroAddress,
            ethers.ZeroAddress))
            .to.be.revertedWithCustomError(c.parametersContract, "InvalidInitialization")
    });

    it("should fail with unexpected proposal type", async function () {
        const proposalId = await c.proposalContract.nextProposalId(c.pId);
        const tokenContractAddress = [ethers.ZeroAddress, ethers.ZeroAddress];
        const amount = [100n, 200n];
        const to = [c.accounts[0].address, c.accounts[1].address];
        const depositToProjectId = [1, 2];
        await c.fundsManagerContract.proposeTransaction(c.pId, tokenContractAddress, amount, to, depositToProjectId);
        await increaseTime(TestBase.VOTE_DURATION + 5);
        await expect(c.processProposal(c.parametersContract, proposalId, c.pId, true))
            .to.be.revertedWith("Unexpected proposal type");
    });

    it('should initialize parameters correctly', async function () {
        expect(await c.parametersContract.gitswarmAddress()).to.equal(GITSWARM_ACCOUNT_ADDRESS);
    });

    it('should be restricted', async function () {
        await expect(c.parametersContract.initializeParameters(0))
            .to.be.revertedWith("Restricted function");
    });

    it('should propose parameter change', async function () {
        const parameterName = ethers.keccak256(ethers.toUtf8Bytes('VoteDuration'));
        const value = 3600; // 1 hour

        await c.parametersContract.proposeParameterChange(0, parameterName, value);

        const proposalId = 0;
        const proposal = await c.parametersContract.changeParameterProposals(0, proposalId);
        expect(proposal.parameterName).to.equal(parameterName);
        expect(proposal.value).to.equal(value);
    });

    it('should execute proposal', async function () {
        const parameterName = ethers.keccak256(ethers.toUtf8Bytes('VoteDuration'));
        const value = 3600; // 1 hour

        const proposalId = await c.proposalContract.nextProposalId(c.pId);
        await c.parametersContract.proposeParameterChange(c.pId, parameterName, value);

        await increaseTime(TestBase.VOTE_DURATION + 5);
        await c.processProposal(c.parametersContract, proposalId, c.pId, true);

        const updatedValue = await c.parametersContract.parameters(c.pId, parameterName);
        expect(updatedValue).to.equal(value);
    });

    it('should remove GitSwarm address', async function () {
        sendEth(ethers.parseEther("1"), GITSWARM_ACCOUNT_ADDRESS, signer);
        await c.parametersContract.connect(GITSWARM_ACCOUNT).removeGitSwarmAddress();

        expect(await c.parametersContract.gitswarmAddress()).to.equal(ethers.ZeroAddress);
    });

    it('should check if an address is trusted', async function () {
        expect(await c.parametersContract.isTrustedAddress(0, c.accounts[2].address)).to.be.false;

        const proposalId = await c.proposalContract.nextProposalId(c.pId);
        await c.parametersContract.proposeChangeTrustedAddress(c.pId, 0, c.accounts[2].address);
        await increaseTime(TestBase.VOTE_DURATION + 5);
        await c.processProposal(c.parametersContract, proposalId, c.pId, true);

        expect(await c.parametersContract.isTrustedAddress(c.pId, c.accounts[2].address)).to.be.true;
        expect(await c.parametersContract.isTrustedAddress(c.pId, c.accounts[1].address)).to.be.false;
    });
    it('tests trusted contracts', async function () {
        expect(await c.parametersContract.isTrustedAddress(c.pId, c.tokenContract)).to.be.true;
        expect(await c.parametersContract.isTrustedAddress(c.pId, c.proposalContract)).to.be.true;
        expect(await c.parametersContract.isTrustedAddress(c.pId, c.parametersContract)).to.be.true;
        expect(await c.parametersContract.isTrustedAddress(c.pId, c.fundsManagerContract)).to.be.true;
        expect(await c.parametersContract.isTrustedAddress(c.pId, c.gasStationContract)).to.be.true;
        expect(await c.parametersContract.isTrustedAddress(c.pId, c.delegatesContract)).to.be.true;
    });

    it('should fail if proposed parameter value is out of range', async function () {
        const parameterName = ethers.keccak256(ethers.toUtf8Bytes('VoteDuration'));
        const minValue = await c.parametersContract.parameterMinValues(parameterName);
        const maxValue = await c.parametersContract.parameterMaxValues(parameterName);

        await expect(c.parametersContract.proposeParameterChange(c.pId, parameterName, minValue - 1n))
            .to.be.revertedWith("Value out of range");

        await expect(c.parametersContract.proposeParameterChange(c.pId, parameterName, maxValue + 1n))
            .to.be.revertedWith("Value out of range");
    });

    it('should fail if the proposal does not exist', async function () {
        const nonExistingProposalId = await c.proposalContract.nextProposalId(c.pId);

        await expect(c.parametersContract.executeProposal(c.pId, nonExistingProposalId))
            .to.be.revertedWith("Proposal does not exist");
    });

    it('should fail if the buffer time has not ended', async function () {
        const proposalId = await c.proposalContract.nextProposalId(c.pId);
        const parameterName = ethers.keccak256(ethers.toUtf8Bytes('VoteDuration'));
        const value = 3600; // 1 hour

        await c.parametersContract.proposeParameterChange(c.pId, parameterName, value);

        // Assuming the buffer time is not passed yet
        await expect(c.parametersContract.executeProposal(c.pId, proposalId))
            .to.be.revertedWith("Buffer time did not end yet");
    });

    it('should fail if the execution period has expired', async function () {
        const proposalId = await c.proposalContract.nextProposalId(c.pId);
        const parameterName = ethers.keccak256(ethers.toUtf8Bytes('VoteDuration'));
        const value = 3600; // 1 hour

        await c.parametersContract.proposeParameterChange(c.pId, parameterName, value);

        // Simulate time past the expiration period
        await increaseTime(TestBase.VOTE_DURATION + TestBase.EXPIRATION_PERIOD + 1);

        await expect(c.parametersContract.executeProposal(c.pId, proposalId))
            .to.be.revertedWith("Proposal has expired");
    });

    it('should fail if the proposal is set not to execute', async function () {
        const proposalId = await c.proposalContract.nextProposalId(c.pId);
        const parameterName = ethers.keccak256(ethers.toUtf8Bytes('VoteDuration'));
        const value = 3600; // 1 hour

        await c.parametersContract.proposeParameterChange(c.pId, parameterName, value);

        await increaseTime(TestBase.VOTE_DURATION + 5);

        await expect(c.parametersContract.executeProposal(c.pId, proposalId))
            .to.be.revertedWith("Proposal was rejected or vote count was not locked");
    });

    it('should execute a change trusted address proposal', async function () {
        await c.setTrustedAddress(c.accounts[2].address)
    });

    it('should execute a change parameter proposal', async function () {
        const proposalId = await c.proposalContract.nextProposalId(c.pId);
        const parameterName = ethers.keccak256(ethers.toUtf8Bytes('VoteDuration'));
        const value = 3600; // 1 hour

        await c.parametersContract.proposeParameterChange(c.pId, parameterName, value);

        await increaseTime(TestBase.VOTE_DURATION + 5);
        await c.processProposal(c.parametersContract, proposalId, c.pId, true);

        const updatedValue = await c.parametersContract.parameters(c.pId, parameterName);
        expect(updatedValue).to.equal(value);
    });
    it('should add a new trusted address at the end of the array', async function () {
        const proposalId = await c.proposalContract.nextProposalId(c.pId);
        const trustedAddress = c.accounts[2].address;

        await c.parametersContract.proposeChangeTrustedAddress(c.pId, 0, trustedAddress);

        await increaseTime(TestBase.VOTE_DURATION + 5);
        await c.processProposal(c.parametersContract, proposalId, c.pId, true);

        const trustedAddresses = await c.parametersContract.trustedAddresses(c.pId, 0);
        expect(trustedAddresses).to.equal(trustedAddress);
    });

    it('should update an existing trusted address at the specified index', async function () {
        const proposalId = await c.proposalContract.nextProposalId(c.pId);
        const trustedAddress1 = c.accounts[2].address;
        const trustedAddress2 = c.accounts[3].address;

        await c.parametersContract.proposeChangeTrustedAddress(c.pId, 0, trustedAddress1);
        await increaseTime(TestBase.VOTE_DURATION + 5);
        await c.processProposal(c.parametersContract, proposalId, c.pId, true);

        const updateProposalId = await c.proposalContract.nextProposalId(c.pId);
        await c.parametersContract.proposeChangeTrustedAddress(c.pId, 0, trustedAddress2);
        await increaseTime(TestBase.VOTE_DURATION + 5);
        await c.processProposal(c.parametersContract, updateProposalId, c.pId, true);

        const trustedAddresses = await c.parametersContract.trustedAddresses(c.pId, 0);
        expect(trustedAddresses).to.equal(trustedAddress2);
    });

    it('should remove a trusted address and replace it with the last element', async function () {
        const proposalId1 = await c.proposalContract.nextProposalId(c.pId);
        const proposalId2 = proposalId1 + 1n;
        const trustedAddress1 = c.accounts[2].address;
        const trustedAddress2 = c.accounts[3].address;

        await c.parametersContract.proposeChangeTrustedAddress(c.pId, 0, trustedAddress1);
        await increaseTime(TestBase.VOTE_DURATION + 5);
        await c.processProposal(c.parametersContract, proposalId1, c.pId, true);

        await c.parametersContract.proposeChangeTrustedAddress(c.pId, 1, trustedAddress2);
        await increaseTime(TestBase.VOTE_DURATION + 5);
        await c.processProposal(c.parametersContract, proposalId2, c.pId, true);

        const removeProposalId = await c.proposalContract.nextProposalId(c.pId);
        await c.parametersContract.proposeChangeTrustedAddress(c.pId, 0, ethers.ZeroAddress);
        await increaseTime(TestBase.VOTE_DURATION + 5);
        await c.processProposal(c.parametersContract, removeProposalId, c.pId, true);

        const trustedAddresses = await c.parametersContract.trustedAddresses(c.pId, 0);
        expect(trustedAddresses).to.equal(trustedAddress2);
    });

    it('should fail if removing a trusted address from an empty array', async function () {
        const proposalId = await c.proposalContract.nextProposalId(c.pId);

        await c.parametersContract.proposeChangeTrustedAddress(c.pId, 0, ethers.ZeroAddress);
        await increaseTime(TestBase.VOTE_DURATION + 5);

        await expect(c.processProposal(c.parametersContract, proposalId, c.pId, true))
            .to.be.revertedWith("No element in trustedAddress array.");
    });
    it('should fail with index out of bounds', async function () {
        await expect(c.parametersContract.proposeChangeTrustedAddress(c.pId, 99, ethers.ZeroAddress))
            .to.be.revertedWith("index out of bounds");
    });

    it("tests neededToContest", async function () {
        expect(await c.parametersContract.neededToContest(c.pId)).to.equal(30n * TestBase.DECIMALS);
    })
});
