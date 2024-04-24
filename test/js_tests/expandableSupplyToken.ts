import {expect} from "chai";
import {ExpandableSupplyToken, Proposal} from "../../typechain-types";
import {
    deployContractAndWait,
    GITSWARM_ACCOUNT,
    GS_PROJECT_ID,
    increaseTime,
    sendEth,
    signer,
    TestBase
} from "./testUtils";

import hre from "hardhat";
import {NonceManager} from "ethers";

export const ethers = hre.ethers;
describe("expandable supply token", function () {
    let c: TestBase;
    let tokenContract: ExpandableSupplyToken;

    before(async function () {
        c = new TestBase();
        await c.setup();
    });

    beforeEach(async function () {
        await c.resetProjectAndAccounts({tokenContract: 'ExpandableSupplyToken'});
        tokenContract = (c.tokenContract as ExpandableSupplyToken).connect(new NonceManager(signer))
        c.pId = tokenContract.projectId()
    });

    async function makeAProposal() {
        await c.parametersContract.proposeParameterChange(c.pId, ethers.keccak256(ethers.toUtf8Bytes("VoteDuration")), 3600);
    }

    it("should create non-zero supply with failure", async function () {
        await expect(deployContractAndWait("contracts/test/ExpandableSupplyTokenNonZeroBase")).to.be.reverted;
    });

    it("should test CREATE_TOKENS proposal", async function () {
        const proposalId = await c.proposalContract.nextProposalId(c.pId);
        let amount = 999n * 10n ** 18n;
        await tokenContract.connect(new NonceManager(signer)).proposeCreateTokens(amount);

        let balanceBefore = await c.fundsManagerContract.balances(c.pId, await tokenContract.getAddress())
        await increaseTime(TestBase.VOTE_DURATION + 5);
        await c.processProposal(tokenContract.connect(new NonceManager(signer)), proposalId, c.pId, true);
        let balanceAfter = await c.fundsManagerContract.balances(c.pId, await tokenContract.getAddress())

        expect(balanceAfter - balanceBefore).to.equal(amount);
    });

    it("should fail with unexpected proposal type for ExpandableSupplyToken", async function () {
        const proposalId = await c.proposalContract.nextProposalId(c.pId);
        await c.parametersContract.proposeParameterChange(c.pId, ethers.keccak256(ethers.toUtf8Bytes("VoteDuration")), 3600);
        await increaseTime(TestBase.VOTE_DURATION + 5);
        await c.proposalContract.lockVoteCount(c.pId, proposalId);
        await increaseTime(TestBase.BUFFER_BETWEEN_END_OF_VOTING_AND_EXECUTE_PROPOSAL + 15);
        await expect(tokenContract.executeProposal(proposalId))
            .to.be.revertedWith("Unexpected proposal type");
    });

    it('should fail if the proposal does not exist', async function () {
        const nonExistingProposalId = await c.proposalContract.nextProposalId(c.pId);

        await expect(tokenContract.executeProposal(nonExistingProposalId))
            .to.be.revertedWith("Proposal does not exist");
    });

    it('should fail if the buffer time has not ended', async function () {
        const proposalId = await c.proposalContract.nextProposalId(c.pId);

        await tokenContract.proposeCreateTokens(10n);

        // Assuming the buffer time is not passed yet
        await expect(tokenContract.executeProposal(proposalId))
            .to.be.revertedWith("Can't execute proposal, buffer time did not end yet");
    });

    it('should fail if the execution period has expired', async function () {
        const proposalId = await c.proposalContract.nextProposalId(c.pId);

        await tokenContract.proposeCreateTokens(10n);

        // Simulate time past the expiration period
        await increaseTime(TestBase.VOTE_DURATION + TestBase.EXPIRATION_PERIOD + 1);

        await expect(tokenContract.executeProposal(proposalId))
            .to.be.revertedWith("Can't execute proposal, execute period has expired");
    });

    it('executes a disable token creation proposal', async function () {
        const proposalId = await c.proposalContract.nextProposalId(c.pId);
        await tokenContract.proposeDisableTokenCreation();
        await increaseTime(TestBase.VOTE_DURATION + 5);
        await c.processProposal(tokenContract.connect(new NonceManager(signer)), proposalId, c.pId, true);
        await expect(tokenContract.proposeCreateTokens(10n)).to.be.revertedWith('Increasing token supply is permanently disabled');
    });

    it('should fail to execute rejected proposal', async function () {
        await tokenContract.proposeDisableTokenCreation();

        const proposalId = await c.proposalContract.nextProposalId(c.pId) - 1n;
        await increaseTime(TestBase.VOTE_DURATION + 5);
        await expect(tokenContract.executeProposal(proposalId))
            .to.be.revertedWith("Can't execute, proposal was rejected or vote count was not locked");
    });

    it('should fail when RequiredVotingPowerPercentageToCreateTokens not met', async function () {
        const proposalId = await c.proposalContract.nextProposalId(c.pId);
        let amount = 999n * 10n ** 18n;
        await tokenContract.connect(c.accounts[0]).proposeCreateTokens(amount);
        await c.proposalContract.connect(c.accounts[1]).vote(c.pId, proposalId, true)

        await increaseTime(TestBase.VOTE_DURATION + 5);
        await c.proposalContract.lockVoteCount(c.pId, proposalId)
        await c.proposalContract.connect(c.accounts[2]).contestProposal(c.pId, proposalId, false)

        let voteCount = await c.proposalContract.checkVoteCount(c.pId, proposalId, 80);
        expect(voteCount[0]).to.equal(2n * TestBase.DECIMALS)
        expect(voteCount[1]).to.equal(TestBase.DECIMALS)
        expect(voteCount[2]).to.equal(false)

        await increaseTime(TestBase.BUFFER_BETWEEN_END_OF_VOTING_AND_EXECUTE_PROPOSAL + 5);
        await expect(tokenContract.executeProposal(proposalId))
            .to.be.revertedWith("RequiredVotingPowerPercentageToCreateTokens not met");

    });

    it('should fail when transferring to the zero address', async function () {
        await expect(tokenContract.transfer(ethers.ZeroAddress, 100n))
            .to.be.revertedWith('Token: sending to null is forbidden');
    });

    it('should fail when transferring with insufficient balance', async function () {
        await expect(tokenContract.connect(c.accounts[0]).transfer(c.accounts[1].address, 100n * TestBase.DECIMALS))
            .to.be.revertedWith('Token: insufficient balance');
    });

    it('should transfer tokens successfully', async function () {
        const initialBalance = await tokenContract.balanceOf(c.accounts[0].address);
        const transferAmount = TestBase.DECIMALS;

        await tokenContract.connect(c.accounts[0]).transfer(c.accounts[1].address, transferAmount);

        expect(await tokenContract.balanceOf(c.accounts[0].address)).to.equal(initialBalance - transferAmount);
        expect(await tokenContract.balanceOf(c.accounts[1].address)).to.equal(TestBase.DECIMALS * 2n);
    });

    it('should fail when transferring from with insufficient allowance', async function () {
        await expect(tokenContract.transferFrom(c.accounts[1].address, c.accounts[2].address, 100n))
            .to.be.revertedWith('Token: insufficient allowance');
    });

    it('should fail when transferring from to the zero address', async function () {
        await tokenContract.connect(c.accounts[0]).approve(c.accounts[1].address, 100n);

        await expect(tokenContract.connect(c.accounts[1]).transferFrom(c.accounts[0].address, ethers.ZeroAddress, 100n))
            .to.be.revertedWith('Token: sending to null is forbidden');
    });

    it('should fail when transferring from with insufficient balance', async function () {
        await tokenContract.connect(c.accounts[0]).approve(c.accounts[1].address, 100n * TestBase.DECIMALS);

        await expect(tokenContract.connect(c.accounts[1]).transferFrom(c.accounts[0].address, c.accounts[2].address, 100n * TestBase.DECIMALS))
            .to.be.revertedWith('Token: insufficient balance');
    });
});
