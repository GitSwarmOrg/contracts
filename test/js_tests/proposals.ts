import {expect} from "chai";
import {ExpandableSupplyToken, Proposal} from "../../typechain-types";
import {GITSWARM_ACCOUNT, increaseTime, sendEth, signer, TestBase} from "./testUtils";

import hre from "hardhat";
import {NonceManager} from "ethers";

export const ethers = hre.ethers;
describe("Proposal", function () {
    let c: TestBase;
    let proposalContract: Proposal;

    before(async function () {
        c = new TestBase();
        await c.setup();
        proposalContract = c.proposalContract;
    });

    beforeEach(async function () {
        await c.resetProjectAndAccounts({tokenContract: 'ExpandableSupplyToken'});
    });

    async function makeAProposal() {
        await c.parametersContract.proposeParameterChange(c.pId, ethers.keccak256(ethers.toUtf8Bytes("VoteDuration")), TestBase.VOTE_DURATION - 42);
    }

    it("should set proposal active", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);
        await makeAProposal();

        const proposal = await proposalContract.proposals(c.pId, proposalId);
        expect(proposal.votingAllowed).to.be.true;
    });

    it("should check if an address has already voted", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);
        await makeAProposal();

        const hasVoted = await proposalContract.hasVotedAlready(c.pId, proposalId, signer.address);
        expect(hasVoted).to.be.true;
    });

    it("should vote on a proposal", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);
        await makeAProposal();

        await proposalContract.connect(c.accounts[1]).vote(c.pId, proposalId, true);
        const hasVoted = await proposalContract.hasVotedAlready(c.pId, proposalId, c.accounts[1].address);
        expect(hasVoted).to.be.true;
    });

    it("should contest a proposal", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);
        await makeAProposal();

        await increaseTime(TestBase.VOTE_DURATION + 5);
        await proposalContract.lockVoteCount(c.pId, proposalId);

        await proposalContract.connect(c.accounts[1]).contestProposal(c.pId, proposalId, true);
        const proposal = await proposalContract.proposals(c.pId, proposalId);
        expect(proposal.votingAllowed).to.be.false;
    });

    it("should remove spam voters", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);
        await sendEth(ethers.parseEther("1"), GITSWARM_ACCOUNT.address, signer);
        await c.parametersContract.connect(GITSWARM_ACCOUNT).proposeParameterChange(c.pId, ethers.keccak256(ethers.toUtf8Bytes("VoteDuration")), TestBase.VOTE_DURATION - 42);
        await proposalContract.connect(c.accounts[1]).vote(c.pId, proposalId, true);
        await proposalContract.connect(c.accounts[2]).vote(c.pId, proposalId, true);
        await proposalContract.connect(c.accounts[3]).vote(c.pId, proposalId, true);

        await c.tokenContract.connect(c.accounts[1]).transfer(c.accounts[4].address, 10n ** 18n);
        expect(await c.tokenContract.balanceOf(c.accounts[1].address)).to.equal(0n);

        await c.tokenContract.connect(c.accounts[2]).transfer(c.accounts[4].address, 10n ** 18n);
        expect(await c.tokenContract.balanceOf(c.accounts[2].address)).to.equal(0n);

        let spamVoters = await proposalContract.getSpamVoters(c.pId, proposalId);
        expect(spamVoters).to.deep.equal([1n, 2n]);

        expect(await proposalContract.getVoters(c.pId, proposalId)).to.deep.equal(
            [GITSWARM_ACCOUNT.address, c.accounts[1].address, c.accounts[2].address, c.accounts[3].address])

        await proposalContract.removeSpamVoters(c.pId, proposalId, [0n,...spamVoters]);

        const proposal = await proposalContract.proposals(c.pId, proposalId);
        expect(proposal.nrOfVoters).to.equal(2);

        expect(await proposalContract.getVoters(c.pId, proposalId)).to.deep.equal(
            [GITSWARM_ACCOUNT.address, c.accounts[3].address])

        spamVoters = await proposalContract.getSpamVoters(c.pId, proposalId);
        expect(spamVoters).to.deep.equal([]);

        expect(await proposalContract.hasVotedAlready(c.pId, proposalId, c.accounts[3].address)).to.be.true;
        expect(await proposalContract.hasVotedAlready(c.pId, proposalId, GITSWARM_ACCOUNT.address)).to.be.true;
    });

    it("should remove spam voters, variation 2", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);
        await sendEth(ethers.parseEther("1"), GITSWARM_ACCOUNT.address, signer);
        await c.parametersContract.connect(c.accounts[3]).proposeParameterChange(c.pId, ethers.keccak256(ethers.toUtf8Bytes("VoteDuration")), TestBase.VOTE_DURATION - 42);
        await proposalContract.connect(c.accounts[1]).vote(c.pId, proposalId, true);
        await proposalContract.connect(c.accounts[2]).vote(c.pId, proposalId, true);
        await proposalContract.connect(GITSWARM_ACCOUNT).vote(c.pId, proposalId, true);

        await c.tokenContract.connect(c.accounts[1]).transfer(c.accounts[4].address, 10n ** 18n);
        expect(await c.tokenContract.balanceOf(c.accounts[1].address)).to.equal(0n);

        await c.tokenContract.connect(c.accounts[2]).transfer(c.accounts[4].address, 10n ** 18n);
        expect(await c.tokenContract.balanceOf(c.accounts[2].address)).to.equal(0n);

        let spamVoters = await proposalContract.getSpamVoters(c.pId, proposalId);
        expect(spamVoters).to.deep.equal([1n, 2n]);

        expect(await proposalContract.getVoters(c.pId, proposalId)).to.deep.equal(
            [c.accounts[3].address, c.accounts[1].address, c.accounts[2].address, GITSWARM_ACCOUNT.address])

        await proposalContract.removeSpamVoters(c.pId, proposalId, [...spamVoters]);

        // const proposal = await proposalContract.proposals(c.pId, proposalId);
        // expect(proposal.nrOfVoters).to.equal(2);

        expect(await proposalContract.getVoters(c.pId, proposalId)).to.deep.equal(
            [c.accounts[3].address, GITSWARM_ACCOUNT.address])

        spamVoters = await proposalContract.getSpamVoters(c.pId, proposalId);
        expect(spamVoters).to.deep.equal([]);

        expect(await proposalContract.hasVotedAlready(c.pId, proposalId, c.accounts[1].address)).to.be.false;
        expect(await proposalContract.hasVotedAlready(c.pId, proposalId, c.accounts[2].address)).to.be.false;
        expect(await proposalContract.hasVotedAlready(c.pId, proposalId, c.accounts[3].address)).to.be.true;
        expect(await proposalContract.hasVotedAlready(c.pId, proposalId, GITSWARM_ACCOUNT.address)).to.be.true;
    });

    it("should remove spam voters, variation 3", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);
        await sendEth(ethers.parseEther("1"), GITSWARM_ACCOUNT.address, signer);
        await c.parametersContract.connect(GITSWARM_ACCOUNT).proposeParameterChange(c.pId, ethers.keccak256(ethers.toUtf8Bytes("VoteDuration")), TestBase.VOTE_DURATION - 42);
        await proposalContract.connect(c.accounts[3]).vote(c.pId, proposalId, true);
        await proposalContract.connect(c.accounts[1]).vote(c.pId, proposalId, true);
        await proposalContract.connect(c.accounts[2]).vote(c.pId, proposalId, true);

        await c.tokenContract.connect(c.accounts[1]).transfer(c.accounts[4].address, 10n ** 18n);
        expect(await c.tokenContract.balanceOf(c.accounts[1].address)).to.equal(0n);

        await c.tokenContract.connect(c.accounts[2]).transfer(c.accounts[4].address, 10n ** 18n);
        expect(await c.tokenContract.balanceOf(c.accounts[2].address)).to.equal(0n);

        let spamVoters = await proposalContract.getSpamVoters(c.pId, proposalId);
        expect(spamVoters).to.deep.equal([2n, 3n]);

        expect(await proposalContract.getVoters(c.pId, proposalId)).to.deep.equal(
            [GITSWARM_ACCOUNT.address, c.accounts[3].address, c.accounts[1].address, c.accounts[2].address])

        await proposalContract.removeSpamVoters(c.pId, proposalId, [...spamVoters]);

        const proposal = await proposalContract.proposals(c.pId, proposalId);
        expect(proposal.nrOfVoters).to.equal(2);

        expect(await proposalContract.getVoters(c.pId, proposalId)).to.deep.equal(
            [GITSWARM_ACCOUNT.address, c.accounts[3].address])

        spamVoters = await proposalContract.getSpamVoters(c.pId, proposalId);
        expect(spamVoters).to.deep.equal([]);

        expect(await proposalContract.hasVotedAlready(c.pId, proposalId, c.accounts[1].address)).to.be.false;
        expect(await proposalContract.hasVotedAlready(c.pId, proposalId, c.accounts[2].address)).to.be.false;
        expect(await proposalContract.hasVotedAlready(c.pId, proposalId, c.accounts[3].address)).to.be.true;
        expect(await proposalContract.hasVotedAlready(c.pId, proposalId, GITSWARM_ACCOUNT.address)).to.be.true;
    });

    it("should revert due to unsorted indexes", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);
        await sendEth(ethers.parseEther("1"), GITSWARM_ACCOUNT.address, signer);
        await c.parametersContract.connect(GITSWARM_ACCOUNT).proposeParameterChange(c.pId, ethers.keccak256(ethers.toUtf8Bytes("VoteDuration")), TestBase.VOTE_DURATION - 42);
        await proposalContract.connect(c.accounts[3]).vote(c.pId, proposalId, true);
        await proposalContract.connect(c.accounts[1]).vote(c.pId, proposalId, true);
        await proposalContract.connect(c.accounts[2]).vote(c.pId, proposalId, true);

        await expect(proposalContract.removeSpamVoters(c.pId, proposalId, [0n, 3n, 2n]))
            .to.be.revertedWith('Unsorted indexes');
    });


    it("should get votes for an address", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);
        await makeAProposal();

        const [hasVoted, votedYes] = await proposalContract.getVotes(c.pId, proposalId, signer.address);
        expect(hasVoted).to.be.true;
        expect(votedYes).to.be.true;
    });

    it("should get vote count", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);
        await makeAProposal();

        await proposalContract.connect(c.accounts[1]).vote(c.pId, proposalId, true);
        await proposalContract.connect(c.accounts[2]).vote(c.pId, proposalId, false);

        const [yesVotes, noVotes] = await proposalContract.getVoteCount(c.pId, proposalId);
        expect(yesVotes).to.be.gt(0);
        expect(noVotes).to.be.gt(0);
    });

    it("should check vote count with tie-breaker", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);
        await c.parametersContract.connect(c.accounts[1]).proposeParameterChange(c.pId, ethers.keccak256(ethers.toUtf8Bytes("VoteDuration")), TestBase.VOTE_DURATION - 42);

        await proposalContract.connect(c.accounts[2]).vote(c.pId, proposalId, false);
        await sendEth(ethers.parseEther("100"), GITSWARM_ACCOUNT.address, signer);
        await proposalContract.connect(GITSWARM_ACCOUNT).vote(c.pId, proposalId, true);

        const [yesVotes, noVotes, passed] = await proposalContract.checkVoteCount(c.pId, proposalId, 50);
        expect(yesVotes).to.equal(noVotes);
        expect(passed).to.be.true;
    });

    it("should not lock vote count if proposal does not exist or is inactive", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);

        await expect(proposalContract.lockVoteCount(c.pId, proposalId))
            .to.be.revertedWith("Proposal does not exist or is inactive");
    });

    it("should not lock vote count if voting is ongoing", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);
        await makeAProposal();

        await expect(proposalContract.lockVoteCount(c.pId, proposalId))
            .to.be.revertedWith("Voting is ongoing");
    });

    it("should not lock vote count if proposal has expired", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);
        await makeAProposal();

        await increaseTime(TestBase.VOTE_DURATION + TestBase.EXPIRATION_PERIOD + 1);

        await expect(proposalContract.lockVoteCount(c.pId, proposalId))
            .to.be.revertedWith("Proposal expired");
    });

    it("should delete proposal if not enough votes to execute", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);
        await makeAProposal();
        await c.proposalContract.vote(c.pId, proposalId, false)
        await increaseTime(TestBase.VOTE_DURATION + 5);
        await proposalContract.lockVoteCount(c.pId, proposalId);

        const proposal = await proposalContract.proposals(c.pId, proposalId);
        expect(proposal.votingAllowed).to.be.false;
        expect(proposal.willExecute).to.be.false;
    });

    it("should fail due to minBalance", async function () {
        let acc = await c.createTestAccount({tokenAmount: 1n})
        await expect(c.parametersContract.connect(new NonceManager(acc))
            .proposeParameterChange(c.pId, ethers.keccak256(ethers.toUtf8Bytes("VoteDuration")), TestBase.VOTE_DURATION - 42))
            .to.be.revertedWith("Not enough voting power.");
        await expect(c.proposalContract.connect(new NonceManager(acc)).vote(c.pId, 0, false))
            .to.be.revertedWith("Not enough voting power.");
        await expect(c.proposalContract.connect(new NonceManager(acc)).vote(c.pId, 0, false))
            .to.be.revertedWith("Not enough voting power.");
    });
    it("should fail due to restricted", async function () {
        await expect(c.proposalContract.setActive(c.pId, 0, false))
            .to.be.revertedWith("Restricted function");
        await expect(c.proposalContract.deleteProposal(c.pId, 0))
            .to.be.revertedWith("Restricted function");
        await expect(c.proposalContract.setWillExecute(c.pId, 0, false))
            .to.be.revertedWith("Restricted function");
        await expect(c.proposalContract.createProposal(c.pId, 0, ethers.ZeroAddress))
            .to.be.revertedWith("Restricted function");
    });


    it("should prevent re-initialization", async function () {
        await expect(c.proposalContract.initialize(ethers.ZeroAddress, ethers.ZeroAddress, ethers.ZeroAddress, ethers.ZeroAddress, ethers.ZeroAddress, ethers.ZeroAddress))
            .to.be.revertedWithCustomError(proposalContract, 'InvalidInitialization');
    });


    it("should fail to vote if proposal does not exist or is inactive", async function () {
        const nonExistentProposalId = 999n;
        await expect(proposalContract.connect(c.accounts[1]).vote(c.pId, nonExistentProposalId, true))
            .to.be.revertedWith("Proposal does not exist or is inactive");
    });

    it("should fail to vote if voting period has ended", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);
        await makeAProposal();

        await increaseTime(TestBase.VOTE_DURATION + 5);

        await expect(proposalContract.connect(c.accounts[1]).vote(c.pId, proposalId, true))
            .to.be.revertedWith("Proposal voting period has ended");
    });

    it("should fail to contest proposal if not enough voting power", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);
        await makeAProposal();

        await increaseTime(TestBase.VOTE_DURATION + 5);
        await proposalContract.lockVoteCount(c.pId, proposalId);

        await expect(proposalContract.connect(c.accounts[4]).contestProposal(c.pId, proposalId, true))
            .to.be.revertedWith("Not enough voting power.");
    });

    it("should fail to contest proposal if not in contesting phase", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);
        await makeAProposal();

        await expect(proposalContract.connect(c.accounts[1]).contestProposal(c.pId, proposalId, true))
            .to.be.revertedWith("Can not contest this proposal, it is not in the phase of contesting");
    });

    it("should process contested proposal if enough no votes", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);
        await makeAProposal();

        await increaseTime(TestBase.VOTE_DURATION + 5);
        await proposalContract.lockVoteCount(c.pId, proposalId);

        await proposalContract.connect(c.accounts[1]).contestProposal(c.pId, proposalId, false);
        await proposalContract.connect(c.accounts[2]).contestProposal(c.pId, proposalId, true);

        await expect(proposalContract.contestProposal(c.pId, proposalId, true))
            .to.emit(proposalContract, 'ContestedProposal')
            .withArgs(c.pId, proposalId, 0n, 97999999999999999990n);

        const proposal = await proposalContract.proposals(c.pId, proposalId);
        expect(proposal.votingAllowed).to.be.false;
        expect(proposal.willExecute).to.be.false;
    });

    it("should process contested proposal if no votes greater than yes votes", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);
        await c.parametersContract.connect(c.accounts[1]).proposeParameterChange(c.pId, ethers.keccak256(ethers.toUtf8Bytes("VoteDuration")), TestBase.VOTE_DURATION - 42);

        await increaseTime(TestBase.VOTE_DURATION + 5);
        await proposalContract.lockVoteCount(c.pId, proposalId);

        await proposalContract.connect(c.accounts[2]).contestProposal(c.pId, proposalId, false);
        await proposalContract.connect(c.accounts[3]).contestProposal(c.pId, proposalId, true);

        const proposal = await proposalContract.proposals(c.pId, proposalId);
        expect(proposal.votingAllowed).to.be.false;
        expect(proposal.willExecute).to.be.false;
    });

    it("should not remove spam voters if they have enough voting power", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);
        await makeAProposal();

        await proposalContract.connect(c.accounts[1]).vote(c.pId, proposalId, true);
        await proposalContract.connect(c.accounts[2]).vote(c.pId, proposalId, true);


        let proposal = await proposalContract.proposals(c.pId, proposalId);
        expect(proposal.nrOfVoters).to.equal(3);

        const spamVoters = await proposalContract.getSpamVoters(c.pId, proposalId);
        expect(spamVoters).to.have.lengthOf(0);

        await proposalContract.removeSpamVoters(c.pId, proposalId, [0, 1, 2]);
        proposal = await proposalContract.proposals(c.pId, proposalId);
        expect(proposal.nrOfVoters).to.equal(3);

        await expect(proposalContract.removeSpamVoters(c.pId, proposalId, [3])).to.be.revertedWith("Index out of bounds");
    });

    it("should get delegated voting power excluding voters", async function () {
        let proposalId = await proposalContract.nextProposalId(c.pId);
        await makeAProposal();

        await c.delegatesContract.delegate(c.pId, c.accounts[1].address);
        await c.delegatesContract.connect(c.accounts[0]).delegate(c.pId, c.accounts[1].address);

        const delegatedVotingPower = await proposalContract.getDelegatedVotingPowerExcludingVoters(
            c.pId,
            c.accounts[1].address,
            proposalId,
            c.tokenContract
        );
        expect(delegatedVotingPower).to.equal(TestBase.TEST_ACCOUNT_DEFAULT_TOKEN_AMOUNT);
    });

    it("should not count votes from addresses that have not voted", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);
        await makeAProposal();

        await proposalContract.connect(c.accounts[1]).vote(c.pId, proposalId, true);

        const [yesVotes, noVotes] = await proposalContract.getVoteCount(c.pId, proposalId);
        expect(yesVotes).to.be.gt(0);
        expect(noVotes).to.equal(0);
    });

    it("should set active false on proposal", async function () {
        const proposalId = await proposalContract.nextProposalId(c.pId);
        await c.setTrustedAddress(signer.address);
        await makeAProposal();

        await expect(proposalContract.setActive(c.pId, proposalId, false))
            .to.emit(proposalContract, 'ProposalSetActive')
            .withArgs(c.pId, proposalId, false);

        let val = await proposalContract.proposals(c.pId, proposalId);
        expect(val.votingAllowed).to.be.false;
    });

});
