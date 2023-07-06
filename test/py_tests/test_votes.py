from contract_proposals_data_structs import CreateTokensProposal
from test.py_tests.tests import EthBaseTest
from utils import increase_time, VOTE_DURATION, GS_PROJECT_ID


class VotesTests(EthBaseTest):

    def setUp(self):
        super().setUp()
        self.create_test_account(token_contract=self.tokenContract)
        self.create_test_account(token_contract=self.tokenContract)
        self.create_test_account(token_contract=self.tokenContract)
        self.create_test_account(token_contract=self.tokenContract)

    def test_vote_proposed_token_transaction_with_true(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].key)

        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[1].key)

        increase_time(VOTE_DURATION + 15)

        balance_before = self.tokenContract.balanceOf(self.accounts[1].address)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID)

        self.assertEqual(self.tokenContract.balanceOf(self.accounts[1].address), balance_before + 100)

    def test_vote_proposed_token_transaction_with_insufficient_balance(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].key)
        # get rid of tokens from the proposing address to not influence the voting
        self.tokenContract.transfer('0x1111111111111111111111111111111111111111', 10 ** 18,
                                    private_key=self.accounts[0].key)

        try:
            self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                                 private_key=self.accounts[0].key)
            self.fail()
        except Exception as e:
            self.assertIn("Not enough voting power.", str(e))

    def test_vote_with_amount_proposed_token_transaction_with_insufficient_balance(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].key)
        # get rid of tokens from the proposing address to not influence the voting
        self.tokenContract.transfer('0x1111111111111111111111111111111111111111', 10 ** 18,
                                    private_key=self.accounts[0].key)

        try:
            self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 200, 100,
                                                 private_key=self.accounts[0].key)
            self.fail()
        except Exception as e:
            self.assertIn("Not enough voting power.", str(e))

    def test_vote_proposed_token_transaction_with_false(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].key)

        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[1].key)

        increase_time(VOTE_DURATION + 15)

        balance_before = self.tokenContract.balanceOf(self.accounts[1].address)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID,
                                                  expect_to_not_execute=True)

        self.assertEqual(self.tokenContract.balanceOf(self.accounts[1].address), balance_before)

    def test_vote_with_amount_adding_more_to_amount_yes(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].key)

        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 200, 100,
                                             private_key=self.accounts[1].key)

        increase_time(VOTE_DURATION + 15)

        balance_before = self.tokenContract.balanceOf(self.accounts[1].address)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID)

        self.assertEqual(self.tokenContract.balanceOf(self.accounts[1].address), balance_before + 100)

    def test_vote_with_amount_adding_more_to_amount_no(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].key)
        # get rid of tokens from the proposing address to not influence the voting
        self.tokenContract.transfer('0x1111111111111111111111111111111111111111', 10 ** 18,
                                    private_key=self.accounts[0].key)

        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 200, 300,
                                             private_key=self.accounts[1].key)

        increase_time(VOTE_DURATION + 15)

        balance_before = self.tokenContract.balanceOf(self.accounts[1].address)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID,
                                                  expect_to_not_execute=True)

        self.assertEqual(self.tokenContract.balanceOf(self.accounts[1].address), balance_before)

    def test_vote_with_amount_adding_0_to_both_amounts(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].key)
        # get rid of tokens from the proposing address to not influence the voting
        self.tokenContract.transfer('0x1111111111111111111111111111111111111111', 10 ** 18,
                                    private_key=self.accounts[0].key)

        try:
            self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 0, 0,
                                                 private_key=self.accounts[1].key)
        except Exception as e:
            self.assertIn("Can't vote with 0 amounts", str(e))

    def test_vote_with_amount_adding_0_to_amount_yes(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].key)
        # get rid of tokens from the proposing address to not influence the voting
        self.tokenContract.transfer('0x1111111111111111111111111111111111111111', 10 ** 18,
                                    private_key=self.accounts[0].key)

        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 0, 100,
                                             private_key=self.accounts[1].key)

        increase_time(VOTE_DURATION + 15)

        balance_before = self.tokenContract.balanceOf(self.accounts[1].address)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID,
                                                  expect_to_not_execute=True)

        self.assertEqual(self.tokenContract.balanceOf(self.accounts[1].address), balance_before)

    def test_vote_with_amount_adding_0_to_amount_no(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].key)

        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 200, 0,
                                             private_key=self.accounts[1].key)

        increase_time(VOTE_DURATION + 15)

        balance_before = self.tokenContract.balanceOf(self.accounts[1].address)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID)

        self.assertEqual(self.tokenContract.balanceOf(self.accounts[1].address), balance_before + 100)

    def test_change_vote_for_proposed_token_transaction(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].key)
        # get rid of tokens from the proposing address to not influence the voting
        self.tokenContract.transfer('0x1111111111111111111111111111111111111111', 10 ** 18,
                                    private_key=self.accounts[0].key)

        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[1].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[2].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[1].key)

        increase_time(VOTE_DURATION + 15)

        balance_before = self.tokenContract.balanceOf(self.accounts[1].address)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID,
                                                  expect_to_not_execute=True)

        self.assertEqual(self.tokenContract.balanceOf(self.accounts[1].address), balance_before)

    def test_vote_inactive_proposed_token_transaction(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].key)

        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[1].key)

        increase_time(VOTE_DURATION + 15)

        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID)
        try:
            self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                                 private_key=self.accounts[2].key)
            self.fail()
        except Exception as e:
            self.assertIn("Proposal does not exist or is inactive", str(e))

    def test_vote_with_amount_inactive_proposed_token_transaction(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].key)

        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[1].key)

        increase_time(VOTE_DURATION + 15)

        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID)
        try:
            self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 200, 100,
                                                 private_key=self.accounts[2].key)
            self.fail()
        except Exception as e:
            self.assertIn("Proposal does not exist or is inactive", str(e))

    def test_vote_an_invalid_proposed_transaction_id(self):
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].key)
        try:
            self.proposalContract.voteProposalId(GS_PROJECT_ID, 15, True,
                                                 private_key=self.accounts[2].key)
            self.fail()
        except Exception as e:
            self.assertIn("Proposal does not exist or is inactive", str(e))

        try:
            self.proposalContract.voteWithAmount(GS_PROJECT_ID, 15, 200, 100,
                                                 private_key=self.accounts[2].key)
            self.fail()
        except Exception as e:
            self.assertIn("Proposal does not exist or is inactive", str(e))

    def test_vote_using_80_percent_required_voting_power_pass(self):
        self.create_test_account(token_contract=self.tokenContract)
        self.create_test_account(token_contract=self.tokenContract)

        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.tokenContract.proposeCreateTokens(100 * 10 ** 18,
                                               private_key=self.accounts[0].key)

        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[1].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[2].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[3].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[4].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[5].key)

        increase_time(VOTE_DURATION + 15)

        p = CreateTokensProposal(self.tokenContract, GS_PROJECT_ID, proposal_id)

        self.assertEqual(p.amount, 100)

        total_supply_before = self.tokenContract.totalSupply()
        self.tokenContract.processProposal(proposal_id,
                                           private_key=self.accounts[0].key,
                                           contract_project_id=GS_PROJECT_ID)
        total_supply_after = self.tokenContract.totalSupply()

        self.assertEqual(total_supply_before + p.amount * 10 ** 18, total_supply_after)

    def test_vote_using_80_percent_required_voting_power_fail(self):
        self.create_test_account(token_contract=self.tokenContract)
        self.create_test_account(token_contract=self.tokenContract)

        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.tokenContract.proposeCreateTokens(100 * 10 ** 18,
                                               private_key=self.accounts[0].key)
        # get rid of tokens from the proposing address to not influence the voting
        self.tokenContract.transfer('0x1111111111111111111111111111111111111111', 10 ** 18,
                                    private_key=self.accounts[0].key)

        self.tokenContract.transfer(self.accounts[5].address, 1, private_key=self.accounts[4].key)

        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[1].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[2].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[3].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[4].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[5].key)

        increase_time(VOTE_DURATION + 15)

        p = CreateTokensProposal(self.tokenContract, GS_PROJECT_ID, proposal_id)

        self.assertEqual(p.amount, 100)

        total_supply_before = self.tokenContract.totalSupply()
        self.tokenContract.processProposal(proposal_id,
                                           private_key=self.accounts[0].key,
                                           contract_project_id=GS_PROJECT_ID,
                                           expect_to_not_execute=True)
        total_supply_after = self.tokenContract.totalSupply()

        self.assertEqual(total_supply_before, total_supply_after)
