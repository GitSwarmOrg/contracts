import {expect} from 'chai';
import hre from "hardhat";
import {GS_PROJECT_ID, increaseTime, TestBase} from "./testUtils";

const ethers = hre.ethers;


describe('GasStation', function () {
    let c: TestBase;

    before(async function () {
        c = new TestBase();
        await c.setup();
    });

    beforeEach(async function () {
        await c.resetProjectAndAccounts({createAccounts: true});
    });

    it('should fail due to 0 balance (needs to be first)', async function () {
        const amount = ethers.parseEther("1");
        const to = c.accounts[1].address;

        await c.gasStationContract.proposeTransferToGasAddress(amount, to);

        const proposalId = await c.proposalContract.nextProposalId(0) - 1n;
        await increaseTime(TestBase.VOTE_DURATION + 5);
        await c.proposalContract.lockVoteCount(0, proposalId)
        await increaseTime(TestBase.BUFFER_BETWEEN_END_OF_VOTING_AND_EXECUTE_PROPOSAL + 15);
        await expect(c.gasStationContract.executeProposal(proposalId))
            .to.be.revertedWith('Insufficient balance');
    });

    it('should fail to buy gas with zero value', async function () {
        const projectId = 1;
        const zeroValue = ethers.parseEther("0");

        await expect(c.gasStationContract.buyGasForProject(projectId, {value: zeroValue}))
            .to.be.revertedWith("Value must be greater than zero");
    });
    it("should prevent re-initialization", async function () {
        await expect(c.gasStationContract.initialize(
            ethers.ZeroAddress,
            ethers.ZeroAddress,
            ethers.ZeroAddress,
            ethers.ZeroAddress,
            ethers.ZeroAddress,
            ethers.ZeroAddress
        )).to.be.revertedWithCustomError(c.gasStationContract, "InvalidInitialization");
    });

    it("should fail with unexpected proposal type for GasStation", async function () {
        const proposalId = await c.proposalContract.nextProposalId(GS_PROJECT_ID);
        await c.parametersContract.proposeParameterChange(GS_PROJECT_ID, ethers.keccak256(ethers.toUtf8Bytes("VoteDuration")), 3600);
        await increaseTime(TestBase.VOTE_DURATION + 5);
        await c.proposalContract.lockVoteCount(GS_PROJECT_ID, proposalId);
        await increaseTime(TestBase.BUFFER_BETWEEN_END_OF_VOTING_AND_EXECUTE_PROPOSAL + 15);
        await expect(c.gasStationContract.executeProposal(proposalId))
            .to.be.revertedWith("Unexpected proposal type");
    });

    it('should buy gas for a project', async function () {
        const projectId = 1;
        const amount = ethers.parseEther("1");

        await expect(c.gasStationContract.buyGasForProject(projectId, {value: amount}))
            .to.emit(c.gasStationContract, 'BuyGasEvent')
            .withArgs(projectId, amount);
    });

    it('should propose transfer to gas address', async function () {
        const amount = ethers.parseEther("1");
        const to = c.accounts[1].address;

        await c.gasStationContract.proposeTransferToGasAddress(amount, to);

        const proposalId = await c.proposalContract.nextProposalId(0) - 1n;
        const proposal = await c.gasStationContract.transferToGasAddressProposals(proposalId);

        expect(proposal.amount).to.equal(amount);
        expect(proposal.to).to.equal(to);
    });

    it('should execute transfer to gas address proposal', async function () {
        const amount = ethers.parseEther("1");
        const to = c.accounts[1].address;

        await c.gasStationContract.buyGasForProject(0, {value: amount});
        await c.gasStationContract.proposeTransferToGasAddress(amount, to);

        const proposalId = await c.proposalContract.nextProposalId(0) - 1n;
        await increaseTime(TestBase.VOTE_DURATION + 5);
        await c.proposalContract.lockVoteCount(0, proposalId)
        await increaseTime(TestBase.BUFFER_BETWEEN_END_OF_VOTING_AND_EXECUTE_PROPOSAL + 15);

        await expect(c.gasStationContract.executeProposal(proposalId))
            .to.emit(c.gasStationContract, 'TransferredGas')
            .withArgs(to, amount);
    });


    it('should fail to execute non-existent proposal', async function () {
        const nonExistentProposalId = 999;

        await expect(c.gasStationContract.executeProposal(nonExistentProposalId))
            .to.be.revertedWith("Proposal does not exist");
    });

    it('should fail to execute proposal before buffer time ends', async function () {
        const amount = ethers.parseEther("1");
        const to = c.accounts[1].address;

        await c.gasStationContract.buyGasForProject(0, {value: amount});
        await c.gasStationContract.proposeTransferToGasAddress(amount, to);

        const proposalId = await c.proposalContract.nextProposalId(0) - 1n;

        await expect(c.gasStationContract.executeProposal(proposalId))
            .to.be.revertedWith("Can't execute proposal, buffer time did not end yet");
    });

    it('should fail to execute proposal after expiration period', async function () {
        const amount = ethers.parseEther("1");
        const to = c.accounts[1].address;

        await c.gasStationContract.buyGasForProject(0, {value: amount});
        await c.gasStationContract.proposeTransferToGasAddress(amount, to);

        const proposalId = await c.proposalContract.nextProposalId(0) - 1n;
        await increaseTime(TestBase.VOTE_DURATION + TestBase.EXPIRATION_PERIOD + 1);

        await expect(c.gasStationContract.executeProposal(proposalId))
            .to.be.revertedWith("Can't execute proposal, execute period has expired");
    });

    it('should fail to execute rejected proposal', async function () {
        const amount = ethers.parseEther("1");
        const to = c.accounts[1].address;

        await c.gasStationContract.buyGasForProject(0, {value: amount});
        await c.gasStationContract.proposeTransferToGasAddress(amount, to);

        const proposalId = await c.proposalContract.nextProposalId(0) - 1n;
        await increaseTime(TestBase.VOTE_DURATION + 5);

        await expect(c.gasStationContract.executeProposal(proposalId))
            .to.be.revertedWith("Can't execute, proposal was rejected or vote count was not locked");
    });
});
