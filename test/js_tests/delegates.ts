import * as assert from "node:assert";
import {TestBase} from "./testUtils";
import hre from "hardhat";
import {expect} from "chai";

const ethers = hre.ethers;

describe("Delegates", function () {
    let c: TestBase;

    before(async function () {
        // This runs once before the first test in this block
        c = new TestBase();
        await c.setup();
    });

    beforeEach(async function () {
        await c.resetProjectAndAccounts()
    })

    it("should prevent re-initialization", async function () {
        try {
            await c.delegatesContract.initialize(ethers.ZeroAddress, ethers.ZeroAddress, ethers.ZeroAddress, ethers.ZeroAddress, ethers.ZeroAddress, ethers.ZeroAddress);
            expect.fail("Should have thrown an error on second initialization");
        } catch (error) {
            expect((error as Error).message).to.include("InvalidInitialization");
        }
    });

    it("should handle delegate votes correctly", async function () {
        // Simulate delegating a vote
        await c.delegatesContract.connect(c.accounts[0]).delegate(c.pId, c.accounts[1].address);

        // Check delegation results
        const delegateOf = await c.delegatesContract.delegateOf(c.pId, c.accounts[0].address);
        assert.equal(delegateOf, c.accounts[1].address);

        const delegations = await c.delegatesContract.delegations(c.pId, c.accounts[1].address, 0);
        assert.equal(delegations, c.accounts[0].address);
    });

    it("test delegate vote with insufficient balance", async function () {
        try {
            await c.delegatesContract.connect(c.accounts[4]).delegate(c.pId, c.accounts[1].address);
            expect.fail("Should have thrown an error");
        } catch (error) {
            expect((error as Error).message).to.include("Not enough direct voting power");
        }
    });

    it("test delegate vote to self", async function () {
        try {
            await c.delegatesContract.connect(c.accounts[0]).delegate(c.pId, c.accounts[0].address);
            expect.fail("Should have thrown an error");
        } catch (error) {
            expect((error as Error).message).to.include("Can't delegate to yourself");
        }
    });

    it("test undelegate vote", async function () {
        await c.delegatesContract.connect(c.accounts[0]).delegate(c.pId, c.accounts[1].address);
        expect(await c.delegatesContract.delegateOf(c.pId, c.accounts[0].address)).to.equal(c.accounts[1].address);

        await c.delegatesContract.connect(c.accounts[0]).undelegate(c.pId);
        expect(await c.delegatesContract.delegateOf(c.pId, c.accounts[0].address)).to.equal(ethers.ZeroAddress);
    });

    it("test delegate vote to an address and then to another", async function () {
        await c.delegatesContract.connect(c.accounts[0]).delegate(c.pId, c.accounts[1].address);
        expect(await c.delegatesContract.delegateOf(c.pId, c.accounts[0].address)).to.equal(c.accounts[1].address);

        await c.delegatesContract.connect(c.accounts[0]).delegate(c.pId, c.accounts[2].address);
        expect(await c.delegatesContract.delegateOf(c.pId, c.accounts[0].address)).to.equal(c.accounts[2].address);
    });

    it("should handle delegate vote to an address that already delegated to another", async function () {
        await c.delegatesContract.connect(c.accounts[1]).delegate(c.pId, c.accounts[2].address);
        await c.delegatesContract.connect(c.accounts[0]).delegate(c.pId, c.accounts[1].address);

        expect(await c.delegatesContract.delegateOf(c.pId, c.accounts[0].address)).to.equal(c.accounts[1].address);
        expect(await c.delegatesContract.delegateOf(c.pId, c.accounts[1].address)).to.equal(c.accounts[2].address);
        expect(await c.delegatesContract.delegations(c.pId, c.accounts[1].address, 0)).to.equal(c.accounts[0].address);
        expect(await c.delegatesContract.delegations(c.pId, c.accounts[2].address, 0)).to.equal(c.accounts[1].address);
    });

    it("should handle delegate addresses undelegate one of them and delegate back", async function () {
        console.log(`delegator address: ${c.accounts[0].address}`);

        await c.delegatesContract.connect(c.accounts[0]).delegate(c.pId, c.accounts[3].address);
        await c.delegatesContract.connect(c.accounts[1]).delegate(c.pId, c.accounts[3].address);
        await c.delegatesContract.connect(c.accounts[2]).delegate(c.pId, c.accounts[3].address);

        expect(await c.delegatesContract.delegations(c.pId, c.accounts[3].address, 0)).to.equal(c.accounts[0].address);
        expect(await c.delegatesContract.delegations(c.pId, c.accounts[3].address, 1)).to.equal(c.accounts[1].address);
        expect(await c.delegatesContract.delegations(c.pId, c.accounts[3].address, 2)).to.equal(c.accounts[2].address);

        await c.delegatesContract.connect(c.accounts[1]).undelegate(c.pId);
        await c.delegatesContract.connect(c.accounts[1]).delegate(c.pId, c.accounts[3].address);

        expect(await c.delegatesContract.delegations(c.pId, c.accounts[3].address, 0)).to.equal(c.accounts[0].address);
        expect(await c.delegatesContract.delegations(c.pId, c.accounts[3].address, 1)).to.equal(c.accounts[2].address);
        expect(await c.delegatesContract.delegations(c.pId, c.accounts[3].address, 2)).to.equal(c.accounts[1].address);
    });

    it("should handle undelegate all from address", async function () {
        await c.delegatesContract.connect(c.accounts[0]).delegate(c.pId, c.accounts[3].address);
        await c.delegatesContract.connect(c.accounts[1]).delegate(c.pId, c.accounts[3].address);
        await c.delegatesContract.connect(c.accounts[2]).delegate(c.pId, c.accounts[3].address);

        await c.delegatesContract.connect(c.accounts[3]).undelegateAllFromAddress(c.pId);

        expect(await c.delegatesContract.delegateOf(c.pId, c.accounts[0].address)).to.equal(ethers.ZeroAddress);
        expect(await c.delegatesContract.delegateOf(c.pId, c.accounts[1].address)).to.equal(ethers.ZeroAddress);
        expect(await c.delegatesContract.delegateOf(c.pId, c.accounts[2].address)).to.equal(ethers.ZeroAddress);

        try {
            await c.delegatesContract.delegations(c.pId, c.accounts[3].address, 0);
            expect.fail("Should have thrown an error");
        } catch (error) {
            expect((error as Error).message).to.include("Transaction reverted");
        }
    });

    it("should handle undelegate all from address and delegate back", async function () {
        await c.delegatesContract.connect(c.accounts[0]).delegate(c.pId, c.accounts[3].address);
        await c.delegatesContract.connect(c.accounts[1]).delegate(c.pId, c.accounts[3].address);
        await c.delegatesContract.connect(c.accounts[2]).delegate(c.pId, c.accounts[3].address);

        await c.delegatesContract.connect(c.accounts[3]).undelegateAllFromAddress(c.pId);

        await c.delegatesContract.connect(c.accounts[0]).delegate(c.pId, c.accounts[3].address);
        await c.delegatesContract.connect(c.accounts[1]).delegate(c.pId, c.accounts[3].address);
        await c.delegatesContract.connect(c.accounts[2]).delegate(c.pId, c.accounts[3].address);

        expect(await c.delegatesContract.delegateOf(c.pId, c.accounts[0].address)).to.equal(c.accounts[3].address);
        expect(await c.delegatesContract.delegateOf(c.pId, c.accounts[1].address)).to.equal(c.accounts[3].address);
        expect(await c.delegatesContract.delegateOf(c.pId, c.accounts[2].address)).to.equal(c.accounts[3].address);

        expect(await c.delegatesContract.delegations(c.pId, c.accounts[3].address, 0)).to.equal(c.accounts[0].address);
        expect(await c.delegatesContract.delegations(c.pId, c.accounts[3].address, 1)).to.equal(c.accounts[1].address);
        expect(await c.delegatesContract.delegations(c.pId, c.accounts[3].address, 2)).to.equal(c.accounts[2].address);
    });

    it("should not allow delegating a delegated address to one of its delegators", async function () {
        await c.delegatesContract.connect(c.accounts[0]).delegate(c.pId, c.accounts[3].address);
        await c.delegatesContract.connect(c.accounts[1]).delegate(c.pId, c.accounts[3].address);

        try {
            await c.delegatesContract.connect(c.accounts[3]).delegate(c.pId, c.accounts[0].address);
            expect.fail("Should have thrown an error");
        } catch (error) {
            expect((error as Error).message).to.include("Can't delegate to yourself");
        }
    });


    it("should return the delegators of a delegated address", async function () {
        await c.delegatesContract.connect(c.accounts[0]).delegate(c.pId, c.accounts[1].address);
        const delegators = await c.delegatesContract.getDelegatorsOf(c.pId, c.accounts[1].address);
        expect(delegators).to.include(c.accounts[0].address);
    });

    it("should accumulate voting power across delegations to meet minimum", async function () {
        await c.delegatesContract.connect(c.accounts[0]).delegate(c.pId, c.accounts[2].address);
        await c.delegatesContract.connect(c.accounts[1]).delegate(c.pId, c.accounts[2].address);
        await c.tokenContract.connect(c.accounts[0]).transfer(c.accounts[4].address, 10n ** 18n);
        await c.tokenContract.connect(c.accounts[2]).transfer(c.accounts[4].address, 10n ** 18n);
        expect(await c.tokenContract.balanceOf(c.accounts[0].address)).to.equal(0n)
        expect(await c.tokenContract.balanceOf(c.accounts[2].address)).to.equal(0n)
        const hasEnoughPower = await c.delegatesContract.checkVotingPower(c.pId, c.accounts[2].address, 10n ** 18n);
        expect(hasEnoughPower).to.be.true;
    });

    it("should calculate the delegated voting power correctly", async function () {
        await c.delegatesContract.connect(c.accounts[0]).delegate(c.pId, c.accounts[1].address);
        const delegatedVotingPower = await c.delegatesContract.getDelegatedVotingPower(c.pId, c.accounts[1].address);
        expect(delegatedVotingPower).to.equal(10n ** 18n);
    });

    it("should check voting power correctly", async function () {
        await c.delegatesContract.connect(c.accounts[0]).delegate(c.pId, c.accounts[1].address);
        const hasVotingPower = await c.delegatesContract.checkVotingPower(c.pId, c.accounts[1].address, 100);
        expect(hasVotingPower).to.be.true;
    });

    it("should remove spam delegates correctly", async function () {
        await c.tokenContract.connect(c.accounts[1]).transfer(c.accounts[4].address, 10n ** 18n);
        expect(await c.tokenContract.balanceOf(c.accounts[1].address)).to.equal(0n)

        await c.delegatesContract.connect(c.accounts[0]).delegate(c.pId, c.accounts[1].address);
        await c.delegatesContract.connect(c.accounts[2]).delegate(c.pId, c.accounts[1].address);

        await c.tokenContract.connect(c.accounts[2]).transfer(c.accounts[4].address, 10n ** 18n);
        expect(await c.tokenContract.balanceOf(c.accounts[2].address)).to.equal(0n)
        let spamDelegates = await c.delegatesContract.getSpamDelegates(c.pId, c.accounts[1].address);
        expect(spamDelegates[0]).to.have.lengthOf(1);
        expect(spamDelegates[0][0]).to.equal(c.accounts[2].address);
        expect(spamDelegates[1]).to.have.lengthOf(1);

        try {
            await c.delegatesContract.removeSpamDelegates(c.pId,
                [c.accounts[2].address, c.accounts[3].address], [0, 0]);
            expect.fail("Should have thrown an error for incorrect indexes");
        } catch (error) {
            expect((error as Error).message).to.include("Wrong index for address.");
        }

        try {
            await c.delegatesContract.removeSpamDelegates(c.pId, [c.accounts[2].address], []);
            expect.fail("Should have thrown an error for different lengths");
        } catch (error) {
            expect((error as Error).message).to.include("addresses and indexes must have same length");
        }

        await c.delegatesContract.removeSpamDelegates(c.pId, [...spamDelegates[0]], [...spamDelegates[1]]);
        spamDelegates = await c.delegatesContract.getSpamDelegates(c.pId, c.accounts[1].address);
        expect(spamDelegates[0]).to.have.lengthOf(0);
        expect(spamDelegates[1]).to.have.lengthOf(0);

        const delegators = await c.delegatesContract.getDelegatorsOf(c.pId, c.accounts[1].address);
        expect(delegators).to.deep.equal([c.accounts[0].address]);

        expect(await c.delegatesContract.checkVotingPower(c.pId, c.accounts[1].address, 10n ** 18n)).to.be.true;
    });
});

