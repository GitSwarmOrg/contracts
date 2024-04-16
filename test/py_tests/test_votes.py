from contract_proposals_data_structs import CreateTokensProposal, Proposals
from test.py_tests.tests import EthBaseTest
from utils import increase_time, VOTE_DURATION


class VotesTests(EthBaseTest):

    def setUp(self):
        super().setUp()
        self.create_test_account()
        self.create_test_account()
        self.create_test_account()
        self.create_test_account()

    def test_vote_proposed_token_transaction_with_true(self):
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].private_key)

        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[1].private_key)

        increase_time(VOTE_DURATION)

        balance_before = self.tokenContract.balanceOf(self.accounts[1].address)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].private_key,
                                                  contract_project_id=self.p_id)

        self.assertEqual(self.tokenContract.balanceOf(self.accounts[1].address), balance_before + 100)

    def test_vote_proposed_token_transaction_with_insufficient_balance(self):
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].private_key)
        # get rid of tokens from the proposing address to not influence the voting
        self.tokenContract.transfer('0x1111111111111111111111111111111111111111', 10 ** 18,
                                    private_key=self.accounts[0].private_key)

        try:
            self.proposalContract.vote(self.p_id, proposal_id, True,
                                       private_key=self.accounts[0].private_key)
            self.fail()
        except Exception as e:
            self.assertIn("Not enough voting power.", str(e))

    def test_vote_proposed_token_transaction_with_false(self):
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].private_key)

        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[1].private_key)

        increase_time(VOTE_DURATION)

        balance_before = self.tokenContract.balanceOf(self.accounts[1].address)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].private_key,
                                                  contract_project_id=self.p_id,
                                                  expect_to_not_execute=True)

        self.assertEqual(self.tokenContract.balanceOf(self.accounts[1].address), balance_before)

    def test_change_vote_for_proposed_token_transaction(self):
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].private_key)
        # get rid of tokens from the proposing address to not influence the voting
        self.tokenContract.transfer('0x1111111111111111111111111111111111111111', 10 ** 18,
                                    private_key=self.accounts[0].private_key)

        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[1].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[2].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[1].private_key)

        increase_time(VOTE_DURATION)

        balance_before = self.tokenContract.balanceOf(self.accounts[1].address)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].private_key,
                                                  contract_project_id=self.p_id,
                                                  expect_to_not_execute=True)

        self.assertEqual(self.tokenContract.balanceOf(self.accounts[1].address), balance_before)

    def test_vote_inactive_proposed_token_transaction(self):
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].private_key)

        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[1].private_key)

        increase_time(VOTE_DURATION)

        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].private_key,
                                                  contract_project_id=self.p_id,
                                                  expect_to_execute=True)
        try:
            self.proposalContract.vote(self.p_id, proposal_id, True,
                                       private_key=self.accounts[2].private_key)
            self.fail()
        except Exception as e:
            self.assertIn("Proposal does not exist or is inactive", str(e))

    def test_vote_an_invalid_proposed_transaction_id(self):
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].private_key)
        try:
            self.proposalContract.vote(self.p_id, 15, True,
                                       private_key=self.accounts[2].private_key)
            self.fail()
        except Exception as e:
            self.assertIn("Proposal does not exist or is inactive", str(e))

    def test_vote_using_80_percent_required_voting_power_pass(self):
        self.create_test_account()
        self.create_test_account()

        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.tokenContract.proposeCreateTokens(100 * 10 ** 18,
                                               private_key=self.accounts[0].private_key)

        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[1].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[2].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[3].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[4].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[5].private_key)

        increase_time(VOTE_DURATION)

        p = CreateTokensProposal(self.tokenContract, self.p_id, proposal_id)

        self.assertEqual(p.amount, 100)

        total_supply_before = self.tokenContract.totalSupply()
        self.tokenContract.processProposal(proposal_id,
                                           private_key=self.accounts[0].private_key,
                                           contract_project_id=self.p_id,
                                           expect_to_execute=True)
        total_supply_after = self.tokenContract.totalSupply()

        self.assertEqual(total_supply_before + p.amount * 10 ** 18, total_supply_after)

    def test_vote_using_80_percent_required_voting_power_fail(self):
        self.create_test_account()
        self.create_test_account()

        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.tokenContract.proposeCreateTokens(100 * 10 ** 18,
                                               private_key=self.accounts[1].private_key)

        self.tokenContract.transfer(self.accounts[5].address, 1, private_key=self.accounts[4].private_key)

        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[1].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[2].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[3].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[4].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[5].private_key)

        increase_time(VOTE_DURATION)

        total_supply_before = self.tokenContract.totalSupply()
        self.tokenContract.processProposal(proposal_id,
                                           private_key=self.accounts[0].private_key,
                                           contract_project_id=self.p_id,
                                           expect_to_not_execute=True)
        total_supply_after = self.tokenContract.totalSupply()

        self.assertEqual(total_supply_before, total_supply_after)
