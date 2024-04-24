import {
    deployContractAndWait,
    GITSWARM_ACCOUNT_ADDRESS,
    GS_PROJECT_ID,
    increaseTime, sendEth,
    signer,
    TestBase
} from "./testUtils";
import hre from "hardhat";
import {expect} from "chai";
import {Contract} from "ethers";

const ethers = hre.ethers;
const burnAddress = ethers.Wallet.createRandom().address;

describe("ContractsManager", function () {
    let c: TestBase;
    before(async function () {
        c = new TestBase();
        await c.setup();
    });

    beforeEach(async function () {
        await c.resetProjectAndAccounts();
    });

    it("should revert on fallback function", async function () {
        const tx = {
            to: await c.contractsManagerContract.getAddress(),
            value: ethers.parseEther("1"),
            data: "0x1234",
        };
        await expect(c.accounts[0].sendTransaction(tx)).to.be.revertedWith("Fallback function is not supported");
    });

    it("should revert on receive function", async function () {
        const tx = {
            to: await c.contractsManagerContract.getAddress(),
            value: ethers.parseEther("1"),
            data: "",
        };
        await expect(c.accounts[0].sendTransaction(tx)).to.be.revertedWith("Receive function is not supported");
    });

    it("should prevent re-initialization", async function () {
        try {
            await c.contractsManagerContract.initialize(
                ethers.ZeroAddress,
                ethers.ZeroAddress,
                ethers.ZeroAddress,
                ethers.ZeroAddress,
                ethers.ZeroAddress,
                ethers.ZeroAddress
            );
            expect.fail("Should have thrown an error on second initialization");
        } catch (error) {
            expect((error as Error).message).to.include("InvalidInitialization");
        }
    });

    it("should prevent gs-token re-initialization", async function () {
        try {
            await c.UpgradableTokenContract.initialize(
                '',
                '',
                '',
                0,
                0,
                ethers.ZeroAddress,
                ethers.ZeroAddress,
                ethers.ZeroAddress,
                ethers.ZeroAddress,
                ethers.ZeroAddress,
                ethers.ZeroAddress
            );
            expect.fail("Should have thrown an error on second initialization");
        } catch (error) {
            expect((error as Error).message).to.include("InvalidInitialization");
        }
    });

    it("should create a new project", async function () {
        const tokenAddress = await c.tokenContract.getAddress();
        const projectId = await c.contractsManagerContract.nextProjectId();

        // @ts-ignore
        await c.contractsManagerContract.createProject("test_project", tokenAddress);

        const newProjectId = await c.contractsManagerContract.nextProjectId();
        expect(newProjectId).to.equal(projectId + 1n);

        const votingTokenContract = await c.contractsManagerContract.votingTokenContracts(projectId);
        expect(votingTokenContract).to.equal(tokenAddress);
    });

    it("project token contract address is 0x", async function () {
        // @ts-ignore
        await expect(c.contractsManagerContract.createProject("test_project_0", ethers.ZeroAddress))
            .to.be.revertedWith("Contract address can't be 0x0");
    });

    it("project token contract address not a valid token", async function () {
        // @ts-ignore
        await expect(c.contractsManagerContract.createProject("test_project_0", ethers.ZeroAddress.replace(/.$/, "1")))
            .to.be.revertedWith("Address is not an ERC20 token contract");
    });

    it("project token contract address is 0x", async function () {
        await expect(c.contractsManagerContract.proposeChangeVotingToken(c.pId, ethers.ZeroAddress))
            .to.be.revertedWith("Contract address can't be 0x0");
    });

    it("project token contract address not a valid token", async function () {
        await expect(c.contractsManagerContract.proposeChangeVotingToken(c.pId, ethers.ZeroAddress.replace(/.$/, "1")))
            .to.be.revertedWith("Address is not an ERC20 token contract");
    });

    it("should fail with unexpected proposal type", async function () {
        const proposalId = await c.proposalContract.nextProposalId(c.pId);
        await c.parametersContract.proposeParameterChange(c.pId, ethers.keccak256(ethers.toUtf8Bytes("VoteDuration")), 3600);
        await increaseTime(TestBase.VOTE_DURATION + 5);
        await expect(c.processProposal(c.contractsManagerContract, proposalId, c.pId, true))
            .to.be.revertedWith("Unexpected proposal type");
    });


    it("should upgrade contracts", async function () {
        const parametersLogicContract = await deployContractAndWait("contracts/test/Parameters2");
        const contractsManagerLogicContract = await deployContractAndWait("contracts/test/ContractsManager2");
        await c.contractsManagerContract.proposeUpgradeContracts(
            ethers.ZeroAddress,
            ethers.ZeroAddress,
            await parametersLogicContract[0].getAddress(),
            ethers.ZeroAddress,
            ethers.ZeroAddress,
            await contractsManagerLogicContract[0].getAddress()
        );

        await increaseTime(TestBase.VOTE_DURATION);

        const proposalId = await c.proposalContract.nextProposalId(GS_PROJECT_ID);
        await c.processProposal(c.contractsManagerContract, proposalId - 1n, GS_PROJECT_ID, true);

        let newParametersContract = new Contract(
            await c.parametersContract.getAddress(),
            parametersLogicContract[1].abi,
            signer
        );

        await newParametersContract.changeVoteDuration(GS_PROJECT_ID);

        const voteDurationKey = ethers.keccak256(ethers.toUtf8Bytes("VoteDuration"));
        const updatedVoteDuration = await newParametersContract.parameters(GS_PROJECT_ID, voteDurationKey);
        expect(updatedVoteDuration).to.equal(5 * 60 * 60 * 24);

        let newContractsManagerContract = new Contract(
            await c.contractsManagerContract.getAddress(),
            contractsManagerLogicContract[1].abi,
            signer
        );
        await newContractsManagerContract.changeNextProjectId(1000);

        const updatedNextProjectId = await c.contractsManagerContract.nextProjectId();
        expect(updatedNextProjectId).to.equal(1000);
    });

    it("should check if an address is an ERC20 token", async function () {
        const tokenAddress = await c.tokenContract.getAddress();
        const isERC20 = await c.contractsManagerContract.isERC20Token(tokenAddress);
        expect(isERC20).to.be.true;
    });

    it("should propose changing the voting token", async function () {
        const newTokenAddress = await c.tokenContract.getAddress();

        await c.contractsManagerContract.proposeChangeVotingToken(c.pId, newTokenAddress);

        const proposalId = await c.proposalContract.nextProposalId(c.pId);
        const storedProposal = await c.contractsManagerContract.changeVotingTokenProposals(
            c.pId,
            proposalId - 1n
        );

        expect(storedProposal).to.equal(newTokenAddress);
    });

    it("should propose adding a burn address", async function () {
        const burnAddress = ethers.Wallet.createRandom().address;

        await c.contractsManagerContract.proposeAddBurnAddress(c.pId, burnAddress);

        const proposalId = await c.proposalContract.nextProposalId(c.pId);
        const storedProposal = await c.contractsManagerContract.addBurnAddressProposals(
            c.pId,
            proposalId - 1n
        );
        expect(storedProposal).to.equal(burnAddress);
    });

    it("should execute a proposal to change the voting token", async function () {
        const newTokenAddress = await c.tokenContract.getAddress();

        await c.contractsManagerContract.proposeChangeVotingToken(c.pId, newTokenAddress);

        const proposalId = await c.proposalContract.nextProposalId(c.pId);

        await increaseTime(TestBase.VOTE_DURATION + 5);
        await c.processProposal(c.contractsManagerContract, proposalId - 1n, c.pId, true);

        const updatedTokenAddress = await c.contractsManagerContract.votingTokenContracts(c.pId);
        expect(updatedTokenAddress).to.equal(newTokenAddress);
    });

    it("should execute a proposal to add a burn address", async function () {
        const burnAddress = ethers.Wallet.createRandom().address;

        await c.contractsManagerContract.proposeAddBurnAddress(c.pId, burnAddress);

        const proposalId = await c.proposalContract.nextProposalId(c.pId);

        await increaseTime(TestBase.VOTE_DURATION + 5);
        await c.processProposal(c.contractsManagerContract, proposalId - 1n, c.pId, true);

        const burnAddresses = await c.contractsManagerContract.getBurnAddresses(c.pId);
        expect(burnAddresses).to.include(burnAddress);
    });

    it("hasMinBalance should return true for gitswarmAddress", async function () {
        expect(await c.contractsManagerContract.hasMinBalance(c.pId, GITSWARM_ACCOUNT_ADDRESS)).to.be.true;
    });

    it("isERC20Token should return false for regular address", async function () {
        expect(await c.contractsManagerContract.isERC20Token(GITSWARM_ACCOUNT_ADDRESS)).to.be.false;
    })

    it("should fail if the proposal does not exist", async function () {
        const nonExistingProposalId = await c.proposalContract.nextProposalId(c.pId);
        await expect(c.contractsManagerContract.executeProposal(c.pId, nonExistingProposalId))
            .to.be.revertedWith("Proposal does not exist");
    });

    it("should fail if the buffer time has not ended", async function () {
        const proposalId = await c.proposalContract.nextProposalId(c.pId);
        await c.contractsManagerContract.proposeAddBurnAddress(c.pId, burnAddress);

        // Assuming the buffer time is not passed yet
        await expect(c.contractsManagerContract.executeProposal(c.pId, proposalId))
            .to.be.revertedWith("Can't execute proposal, buffer time did not end yet");
    });

    it("should fail if the execution period has expired", async function () {

        const proposalId = await c.proposalContract.nextProposalId(c.pId);
        await c.contractsManagerContract.proposeAddBurnAddress(c.pId, burnAddress);

        // Simulate time past the expiration period
        await increaseTime(TestBase.VOTE_DURATION + TestBase.EXPIRATION_PERIOD + 1);
        await expect(c.contractsManagerContract.executeProposal(c.pId, proposalId))
            .to.be.revertedWith("Can't execute proposal, execute period has expired");
    });

    it("should fail if the proposal is set not to execute", async function () {

        const proposalId = await c.proposalContract.nextProposalId(c.pId);
        await c.contractsManagerContract.proposeAddBurnAddress(c.pId, burnAddress);
        await increaseTime(TestBase.VOTE_DURATION + 5);
        await expect(c.contractsManagerContract.executeProposal(c.pId, proposalId))
            .to.be.revertedWith("Can't execute, proposal was rejected or vote count was not locked");
    });

    it("should fail if adding a duplicate burn address", async function () {
        const burnAddress = ethers.Wallet.createRandom().address;
        await c.contractsManagerContract.proposeAddBurnAddress(c.pId, burnAddress);
        const proposalId = await c.proposalContract.nextProposalId(c.pId) - 1n;
        await increaseTime(TestBase.VOTE_DURATION + 5);
        await c.processProposal(c.contractsManagerContract, proposalId, c.pId, true);

        // Propose the same burn address again
        await c.contractsManagerContract.proposeAddBurnAddress(c.pId, burnAddress);
        const duplicateProposalId = await c.proposalContract.nextProposalId(c.pId) - 1n;

        await increaseTime(TestBase.VOTE_DURATION + 5);
        await expect(c.processProposal(c.contractsManagerContract, duplicateProposalId, c.pId, true))
            .to.be.revertedWith("Duplicate burn address not allowed");
    });

    it("should cover isERC20Token", async function () {
        let [Broken_ERC20_Missing_name] = await deployContractAndWait('artifacts/contracts/test/BrokenERC20.sol/Broken_ERC20_Missing_name.json')
        let [Broken_ERC20_Missing_symbol] = await deployContractAndWait('artifacts/contracts/test/BrokenERC20.sol/Broken_ERC20_Missing_symbol.json')
        let [Broken_ERC20_Missing_decimals] = await deployContractAndWait('artifacts/contracts/test/BrokenERC20.sol/Broken_ERC20_Missing_decimals.json')
        let [Broken_ERC20_Missing_totalSupply] = await deployContractAndWait('artifacts/contracts/test/BrokenERC20.sol/Broken_ERC20_Missing_totalSupply.json')
        let [Broken_ERC20_Missing_balanceOf] = await deployContractAndWait('artifacts/contracts/test/BrokenERC20.sol/Broken_ERC20_Missing_balanceOf.json')
        let [Broken_ERC20_Missing_allowance] = await deployContractAndWait('artifacts/contracts/test/BrokenERC20.sol/Broken_ERC20_Missing_allowance.json')

        expect(await c.contractsManagerContract.isERC20Token(Broken_ERC20_Missing_name)).to.be.false;
        expect(await c.contractsManagerContract.isERC20Token(Broken_ERC20_Missing_symbol)).to.be.false;
        expect(await c.contractsManagerContract.isERC20Token(Broken_ERC20_Missing_decimals)).to.be.false;
        expect(await c.contractsManagerContract.isERC20Token(Broken_ERC20_Missing_totalSupply)).to.be.false;
        expect(await c.contractsManagerContract.isERC20Token(Broken_ERC20_Missing_balanceOf)).to.be.false;
        expect(await c.contractsManagerContract.isERC20Token(Broken_ERC20_Missing_allowance)).to.be.false;

    });

});
