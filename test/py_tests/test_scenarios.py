from unittest import skip

from test.py_tests.tests import EthBaseTest
from utils import increase_time, VOTE_DURATION, ZERO_ETH_ADDRESS


class ScenariosTests(EthBaseTest):
    DECIMALS = 10 ** 18

    def setUp(self):
        super().setUp()
        self.create_test_account(token_contract=self.tokenContract)
        self.create_test_account(token_contract=self.tokenContract)
        self.create_test_account(token_contract=self.tokenContract)
        self.create_test_account(token_contract=self.tokenContract)
        self.create_test_account(token_contract=self.tokenContract)
        self.create_test_account(token_contract=self.tokenContract)
        self.create_test_account(token_contract=self.tokenContract)
        self.create_test_account(token_contract=self.tokenContract)
        self.create_test_account(token_contract=self.tokenContract)
        self.create_test_account(token_contract=self.tokenContract, token_amount=50 * self.DECIMALS)

    def proposeAndExecute(self, proposal_function, *args, votes=None):
        if votes is None:
            votes = {}
        tx = proposal_function(*args)

    def test_scenario_1(self):
        # step 1
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[3].address], [0],
                                                     private_key=self.accounts[0].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[1].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[2].private_key)
        increase_time(VOTE_DURATION)
        balance_before = self.tokenContract.balanceOf(self.accounts[3].address)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].private_key,
                                                  contract_project_id=self.p_id,
                                                  expect_to_not_execute=True)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[3].address), balance_before)

        # step 2
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[3].address], [0],
                                                     private_key=self.accounts[0].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[1].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[2].private_key)
        increase_time(VOTE_DURATION)
        balance_before = self.tokenContract.balanceOf(self.accounts[3].address)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].private_key,
                                                  contract_project_id=self.p_id)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[3].address), balance_before + self.DECIMALS)

        # step 3
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[3].address], [0],
                                                     private_key=self.accounts[0].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[1].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[2].private_key)
        increase_time(VOTE_DURATION)
        balance_before = self.tokenContract.balanceOf(self.accounts[3].address)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].private_key,
                                                  contract_project_id=self.p_id)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[3].address), balance_before + self.DECIMALS)

        # step 4
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[3].address], [0],
                                                     private_key=self.accounts[0].private_key)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[3].address], [0],
                                                     private_key=self.accounts[0].private_key)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[3].address], [0],
                                                     private_key=self.accounts[0].private_key)
        # vote only for 4
        self.proposalContract.vote(self.p_id, proposal_id + 1, True,
                                   private_key=self.accounts[1].private_key)
        self.proposalContract.vote(self.p_id, proposal_id + 1, True,
                                   private_key=self.accounts[2].private_key)
        self.proposalContract.vote(self.p_id, proposal_id + 1, False,
                                   private_key=self.accounts[3].private_key)
        balance_before = self.tokenContract.balanceOf(self.accounts[3].address)
        increase_time(VOTE_DURATION)
        self.fundsManagerContract.processProposal(proposal_id + 1,
                                                  private_key=self.accounts[0].private_key,
                                                  contract_project_id=self.p_id)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[3].address), balance_before)

        # step 5
        # propose transaction 6 leaving 3 and 5 still active
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[3].address], [0],
                                                     private_key=self.accounts[0].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[1].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[2].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[3].private_key)
        balance_before = self.tokenContract.balanceOf(self.accounts[3].address)
        increase_time(VOTE_DURATION)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].private_key,
                                                  contract_project_id=self.p_id)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[3].address), balance_before + self.DECIMALS)

    @skip
    def test_scenario_2(self):
        self.tokenContract.transfer(self.accounts[0].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[3].address, self.DECIMALS,
                                    private_key=self.accounts[9].private_key)

        # step 1
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[4].address], [0],
                                                     private_key=self.accounts[0].private_key)  # 3 yes and 0 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 300, 100,
                                             private_key=self.accounts[1].private_key)  # 0.75 yes and 0.25 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 300, 100,
                                             private_key=self.accounts[2].private_key)  # 0.25 yes and 0.75 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 300, 100,
                                             private_key=self.accounts[3].private_key)  # 0 yes and 2 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 300, 100,
                                             private_key=self.accounts[4].private_key)  # 1 yes and 0 no
        # 5 yes and 3 no
        balance_before = self.tokenContract.balanceOf(self.accounts[4].address)
        increase_time(VOTE_DURATION)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].private_key,
                                                  contract_project_id=self.p_id)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[4].address), balance_before + self.DECIMALS)

        # step 2
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[4].address], [0],
                                                     private_key=self.accounts[0].private_key)  # 3 yes and 0 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 1, 0,
                                             private_key=self.accounts[1].private_key)  # 1 yes and 0 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 0, 1,
                                             private_key=self.accounts[2].private_key)  # 0 yes and 1 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 2, 0,
                                             private_key=self.accounts[3].private_key)  # 2 yes and 0 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 0, 1,
                                             private_key=self.accounts[4].private_key)  # 0 yes and 1 no
        # 6 yes and 2 no
        balance_before = self.tokenContract.balanceOf(self.accounts[4].address)
        increase_time(VOTE_DURATION)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].private_key,
                                                  contract_project_id=self.p_id)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[4].address), balance_before + self.DECIMALS)

    def test_scenario_3(self):
        # delegate some addresses
        self.delegatesContract.delegate(self.p_id, self.accounts[1].address,
                                        private_key=self.accounts[0].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[3].address,
                                        private_key=self.accounts[2].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[2].address,
                                        private_key=self.accounts[1].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[4].address,
                                        private_key=self.accounts[5].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[4].address,
                                        private_key=self.accounts[6].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[4].address,
                                        private_key=self.accounts[3].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[4].address,
                                        private_key=self.accounts[7].private_key)

        # remove some delegations
        self.delegatesContract.undelegate(self.p_id, private_key=self.accounts[6].private_key)
        self.delegatesContract.undelegate(self.p_id, private_key=self.accounts[3].private_key)
        self.delegatesContract.undelegate(self.p_id, private_key=self.accounts[1].private_key)

        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[6].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[3].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[1].address), ZERO_ETH_ADDRESS)

        self.assertEqual(self.delegatesContract.delegations(self.p_id, self.accounts[4].address, 0),
                         self.accounts[5].address)
        self.assertEqual(self.delegatesContract.delegations(self.p_id, self.accounts[4].address, 1),
                         self.accounts[7].address)

        # delegate accounts[4] to account[8]
        self.delegatesContract.delegate(self.p_id, self.accounts[8].address,
                                        private_key=self.accounts[4].private_key)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[4].address),
                         self.accounts[8].address)
        self.assertEqual(self.delegatesContract.delegations(self.p_id, self.accounts[8].address, 0),
                         self.accounts[4].address)

        # delegate accounts[0] to accounts[4]
        self.delegatesContract.delegate(self.p_id, self.accounts[4].address,
                                        private_key=self.accounts[0].private_key)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[0].address),
                         self.accounts[4].address)
        self.assertEqual(self.delegatesContract.delegations(self.p_id, self.accounts[4].address, 2),
                         self.accounts[0].address)

    def test_scenario_4(self):
        self.tokenContract.transfer(self.accounts[0].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[1].address, self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[3].address, self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[5].address, self.DECIMALS,
                                    private_key=self.accounts[9].private_key)

        # delegate some addresses
        self.delegatesContract.delegate(self.p_id, self.accounts[0].address,
                                        private_key=self.accounts[1].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[0].address,
                                        private_key=self.accounts[2].private_key)

        # propose transaction and vote
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [4 * self.DECIMALS],
                                                     [self.accounts[6].address], [0],
                                                     private_key=self.accounts[3].private_key)  # 2 yes and 0 no
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[0].private_key)  # 6 yes and 0 no
        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[4].private_key)  # 0 yes and 1 no
        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[5].private_key)  # 0 yes and 2 no
        # change vote for account 3
        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[
                                       3].private_key)  # 0 yes and 2 no(and remove 2 yes from proposal)

        # 6 yes and 5 no
        balance_before = self.tokenContract.balanceOf(self.accounts[6].address)
        increase_time(VOTE_DURATION)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].private_key,
                                                  contract_project_id=self.p_id)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[6].address), balance_before + 4 * self.DECIMALS)

        # propose a second transaction and vote
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [2 * self.DECIMALS],
                                                     [self.accounts[6].address], [0],
                                                     private_key=self.accounts[1].private_key)  # 2 yes and 0 no
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[0].private_key)  # 6 yes and 0 no
        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[3].private_key)  # 0 yes and 2 no
        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[4].private_key)  # 0 yes and 1 no
        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[5].private_key)  # 0 yes and 2 no
        # change vote for account 3
        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[
                                       1].private_key)  # 0 yes and 2 no(and remove 2 yes from proposal)

        # 6 yes and 7 no
        balance_before = self.tokenContract.balanceOf(self.accounts[6].address)
        increase_time(VOTE_DURATION)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].private_key,
                                                  contract_project_id=self.p_id,
                                                  expect_to_not_execute=True)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[6].address), balance_before)

    @skip
    def test_scenario_5(self):
        self.tokenContract.transfer(self.accounts[1].address, self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[3].address, 4 * self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[4].address, self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[5].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[8].address, 3 * self.DECIMALS,
                                    private_key=self.accounts[9].private_key)

        # delegate some addresses
        self.delegatesContract.delegate(self.p_id, self.accounts[0].address,
                                        private_key=self.accounts[1].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[0].address,
                                        private_key=self.accounts[2].private_key)

        # propose transaction and vote
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[7].address], [0],
                                                     private_key=self.accounts[5].private_key)  # 3 yes and 0 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 600 * self.DECIMALS, 400 * self.DECIMALS,
                                             private_key=self.accounts[0].private_key)  # 2.4 yes and 1.6 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 500 * self.DECIMALS, 500 * self.DECIMALS,
                                             private_key=self.accounts[3].private_key)  # 2.5 yes and 2.5 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 0, 500 * self.DECIMALS,
                                             private_key=self.accounts[4].private_key)  # 0 yes and 2 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 0, 100 * self.DECIMALS,
                                             private_key=self.accounts[6].private_key)  # 0 yes and 1 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 55 * self.DECIMALS, 45 * self.DECIMALS,
                                             private_key=self.accounts[7].private_key)  # 0.55 yes and 0.45 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 0, 2 * self.DECIMALS,
                                             private_key=self.accounts[8].private_key)  # 0 yes and 2 no

        # 8.45 yes and 9.45 no
        balance_before = self.tokenContract.balanceOf(self.accounts[6].address)
        increase_time(VOTE_DURATION)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].private_key,
                                                  contract_project_id=self.p_id,
                                                  expect_to_not_execute=True)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[6].address), balance_before)

    @skip
    def test_scenario_6(self):
        self.tokenContract.transfer(self.accounts[1].address, self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[4].address, self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[5].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[7].address, 5 * self.DECIMALS,
                                    private_key=self.accounts[9].private_key)

        # delegate some addresses
        self.delegatesContract.delegate(self.p_id, self.accounts[0].address,
                                        private_key=self.accounts[1].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[0].address,
                                        private_key=self.accounts[2].private_key)

        # propose transaction and vote
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[8].address], [0],
                                                     private_key=self.accounts[5].private_key)  # 3 yes and 0 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 0, 600 * self.DECIMALS,
                                             private_key=self.accounts[7].private_key)  # 0 yes and 6 no
        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[6].private_key)  # 0 yes and 1 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 10 * self.DECIMALS, 0,
                                             private_key=self.accounts[3].private_key)  # 1 yes and 0 no
        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[4].private_key)  # 0 yes and 2 no
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[8].private_key)  # 1 yes and 0 no
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[0].private_key)  # 4 yes and 0 no

        # 9 yes and 9 no
        balance_before = self.tokenContract.balanceOf(self.accounts[6].address)
        increase_time(VOTE_DURATION)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].private_key,
                                                  contract_project_id=self.p_id,
                                                  expect_to_not_execute=True)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[6].address), balance_before)

    @skip
    def test_scenario_7(self):
        self.tokenContract.transfer(self.accounts[1].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[4].address, self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[5].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[7].address, self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[8].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].private_key)

        # delegate some addresses
        self.delegatesContract.delegate(self.p_id, self.accounts[0].address,
                                        private_key=self.accounts[1].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[0].address,
                                        private_key=self.accounts[2].private_key)

        # propose transaction and vote
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[2].address], [0],
                                                     private_key=self.accounts[5].private_key)  # 3 yes and 0 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 0, 700 * self.DECIMALS,
                                             private_key=self.accounts[7].private_key)  # 0 yes and 2 no
        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[3].private_key)  # 0 yes and 1 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 0, 100 * self.DECIMALS,
                                             private_key=self.accounts[4].private_key)  # 0 yes and 2 no
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[0].private_key)  # 5 yes and 0 no

        # delegate some accounts
        self.delegatesContract.delegate(self.p_id, self.accounts[0].address,
                                        private_key=self.accounts[6].private_key)  # this will add 1 to yes and 0 to no
        self.delegatesContract.delegate(self.p_id, self.accounts[0].address,
                                        private_key=self.accounts[7].private_key)  # no effect as account 7 already voted
        self.delegatesContract.delegate(self.p_id, self.accounts[3].address,
                                        private_key=self.accounts[8].private_key)  # this will add 0 to yes and 3 to no

        # 9 yes and 8 no
        balance_before = self.tokenContract.balanceOf(self.accounts[2].address)
        increase_time(VOTE_DURATION)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].private_key,
                                                  contract_project_id=self.p_id)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[2].address), balance_before + self.DECIMALS)

    @skip
    def test_scenario_8(self):
        self.tokenContract.transfer(self.accounts[1].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[4].address, self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[5].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[6].address, self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[7].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[8].address, 5 * self.DECIMALS,
                                    private_key=self.accounts[9].private_key)

        # delegate some addresses
        self.delegatesContract.delegate(self.p_id, self.accounts[0].address,
                                        private_key=self.accounts[1].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[0].address,
                                        private_key=self.accounts[2].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[0].address,
                                        private_key=self.accounts[4].private_key)

        # propose transaction and vote
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[0].address], [0],
                                                     private_key=self.accounts[7].private_key)  # 3 yes and 0 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 900 * self.DECIMALS, 0,
                                             private_key=self.accounts[8].private_key)  # 6 yes and 0 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 0, 700 * self.DECIMALS,
                                             private_key=self.accounts[8].private_key)  # remove 6 yes and add 6 no
        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[3].private_key)  # 0 yes and 1 no
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[3].private_key)  # add 1 yes and remove 1 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 0, 5 * 10 ** 17,
                                             private_key=self.accounts[6].private_key)  # 0 yes and 2 no
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[0].private_key)  # 7 yes and 0 no
        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[1].private_key)  # remove 3 yes and add 3 no

        # delegate some accounts
        self.delegatesContract.undelegate(self.p_id,
                                          private_key=self.accounts[
                                              1].private_key)  # no effect, address voted independently already
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 0, 100 * self.DECIMALS,
                                             private_key=self.accounts[2].private_key)  # remove 1 yes and add 1 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 300 * self.DECIMALS, 300 * self.DECIMALS,
                                             private_key=self.accounts[4].private_key)  # remove 1 yes and add 1 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 290 * self.DECIMALS, 310 * self.DECIMALS,
                                             private_key=self.accounts[8].private_key)  # add 2.9 yes and remove 3.1 no
        # 8.9 yes and 10.1 no
        balance_before = self.tokenContract.balanceOf(self.accounts[0].address)
        increase_time(VOTE_DURATION)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].private_key,
                                                  contract_project_id=self.p_id)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[0].address), balance_before)

    @skip
    def test_scenario_9(self):
        self.tokenContract.transfer(self.accounts[1].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[4].address, self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[5].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[6].address, self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[7].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].private_key)
        self.tokenContract.transfer(self.accounts[8].address, 5 * self.DECIMALS,
                                    private_key=self.accounts[9].private_key)

        # delegate some addresses
        self.delegatesContract.delegate(self.p_id, self.accounts[0].address,
                                        private_key=self.accounts[1].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[0].address,
                                        private_key=self.accounts[2].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[0].address,
                                        private_key=self.accounts[4].private_key)

        self.delegatesContract.undelegateAllFromAddress(self.p_id, private_key=self.accounts[0].private_key)

        self.delegatesContract.delegate(self.p_id, self.accounts[2].address,
                                        private_key=self.accounts[0].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[3].address,
                                        private_key=self.accounts[2].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[4].address,
                                        private_key=self.accounts[3].private_key)

        self.delegatesContract.delegate(self.p_id, self.accounts[6].address,
                                        private_key=self.accounts[5].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[8].address,
                                        private_key=self.accounts[6].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[8].address,
                                        private_key=self.accounts[7].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[8].address,
                                        private_key=self.accounts[0].private_key)
        self.delegatesContract.undelegate(self.p_id, private_key=self.accounts[7].private_key)

        self.delegatesContract.undelegateAllFromAddress(self.p_id, private_key=self.accounts[8].private_key)

        # propose transaction and vote
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[0].address], [0],
                                                     private_key=self.accounts[7].private_key)  # 3 yes and 0 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 3 * self.DECIMALS, 2 * self.DECIMALS,
                                             private_key=self.accounts[8].private_key)  # 3 yes and 2 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 2 * self.DECIMALS, 2 * self.DECIMALS,
                                             private_key=self.accounts[8].private_key)  # 2 yes and add 2 no
        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[4].private_key)  # 0 yes and 3 no
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[3].private_key)  # 2 yes and remove 1 no
        self.proposalContract.voteWithAmount(self.p_id, proposal_id, 0, 6 * self.DECIMALS,
                                             private_key=self.accounts[1].private_key)  # 0 yes and 3 no
        self.proposalContract.vote(self.p_id, proposal_id, False,
                                   private_key=self.accounts[0].private_key)  # 0 yes and 1 no

        # 10 yes and 10 no
        balance_before = self.tokenContract.balanceOf(self.accounts[0].address)
        increase_time(VOTE_DURATION)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].private_key,
                                                  contract_project_id=self.p_id,
                                                  expect_to_not_execute=True)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[0].address), balance_before)
