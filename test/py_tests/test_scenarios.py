from test.py_tests.tests import EthBaseTest
from utils import increase_time, VOTE_DURATION, ZERO_ETH_ADDRESS, GS_PROJECT_ID


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
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[3].address], [0],
                                                     private_key=self.accounts[0].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[1].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[2].key)
        increase_time(VOTE_DURATION + 15)
        balance_before = self.tokenContract.balanceOf(self.accounts[3].address)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID,
                                                  expect_to_not_execute=True)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[3].address), balance_before)

        # step 2
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[3].address], [0],
                                                     private_key=self.accounts[0].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[1].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[2].key)
        increase_time(VOTE_DURATION + 15)
        balance_before = self.tokenContract.balanceOf(self.accounts[3].address)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[3].address), balance_before + self.DECIMALS)

        # step 3
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[3].address], [0],
                                                     private_key=self.accounts[0].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[1].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[2].key)
        increase_time(VOTE_DURATION + 15)
        balance_before = self.tokenContract.balanceOf(self.accounts[3].address)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[3].address), balance_before + self.DECIMALS)

        # step 4
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[3].address], [0],
                                                     private_key=self.accounts[0].key)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[3].address], [0],
                                                     private_key=self.accounts[0].key)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[3].address], [0],
                                                     private_key=self.accounts[0].key)
        # vote only for 4
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id + 1, True,
                                             private_key=self.accounts[1].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id + 1, True,
                                             private_key=self.accounts[2].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id + 1, False,
                                             private_key=self.accounts[3].key)
        balance_before = self.tokenContract.balanceOf(self.accounts[3].address)
        increase_time(VOTE_DURATION + 15)
        self.fundsManagerContract.processProposal(proposal_id + 1,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[3].address), balance_before)

        # step 5
        # propose transaction 6 leaving 3 and 5 still active
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[3].address], [0],
                                                     private_key=self.accounts[0].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[1].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[2].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[3].key)
        balance_before = self.tokenContract.balanceOf(self.accounts[3].address)
        increase_time(VOTE_DURATION + 15)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[3].address), balance_before + self.DECIMALS)

    def test_scenario_2(self):
        self.tokenContract.transfer(self.accounts[0].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[3].address, self.DECIMALS,
                                    private_key=self.accounts[9].key)

        # step 1
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[4].address], [0],
                                                     private_key=self.accounts[0].key)  # 3 yes and 0 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 300, 100,
                                             private_key=self.accounts[1].key)  # 0.75 yes and 0.25 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 300, 100,
                                             private_key=self.accounts[2].key)  # 0.25 yes and 0.75 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 300, 100,
                                             private_key=self.accounts[3].key)  # 0 yes and 2 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 300, 100,
                                             private_key=self.accounts[4].key)  # 1 yes and 0 no
        # 5 yes and 3 no
        balance_before = self.tokenContract.balanceOf(self.accounts[4].address)
        increase_time(VOTE_DURATION + 15)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[4].address), balance_before + self.DECIMALS)

        # step 2
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[4].address], [0],
                                                     private_key=self.accounts[0].key)  # 3 yes and 0 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 1, 0,
                                             private_key=self.accounts[1].key)  # 1 yes and 0 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 0, 1,
                                             private_key=self.accounts[2].key)  # 0 yes and 1 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 2, 0,
                                             private_key=self.accounts[3].key)  # 2 yes and 0 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 0, 1,
                                             private_key=self.accounts[4].key)  # 0 yes and 1 no
        # 6 yes and 2 no
        balance_before = self.tokenContract.balanceOf(self.accounts[4].address)
        increase_time(VOTE_DURATION + 15)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[4].address), balance_before + self.DECIMALS)

    def test_scenario_3(self):
        # delegate some addresses
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[1].address,
                                        private_key=self.accounts[0].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[3].address,
                                        private_key=self.accounts[2].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[2].address,
                                        private_key=self.accounts[1].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[4].address,
                                        private_key=self.accounts[5].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[4].address,
                                        private_key=self.accounts[6].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[4].address,
                                        private_key=self.accounts[3].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[4].address,
                                        private_key=self.accounts[7].key)

        # remove some delegates
        self.delegatesContract.undelegate(GS_PROJECT_ID, private_key=self.accounts[6].key)
        self.delegatesContract.undelegate(GS_PROJECT_ID, private_key=self.accounts[3].key)
        self.delegatesContract.undelegate(GS_PROJECT_ID, private_key=self.accounts[1].key)

        self.assertEqual(self.delegatesContract.delegators(GS_PROJECT_ID, self.accounts[6].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegators(GS_PROJECT_ID, self.accounts[3].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegators(GS_PROJECT_ID, self.accounts[1].address), ZERO_ETH_ADDRESS)

        self.assertEqual(self.delegatesContract.delegates(GS_PROJECT_ID, self.accounts[4].address, 0),
                         self.accounts[5].address)
        self.assertEqual(self.delegatesContract.delegates(GS_PROJECT_ID, self.accounts[4].address, 1),
                         self.accounts[7].address)

        # delegate accounts[4] to account[8]
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[8].address,
                                        private_key=self.accounts[4].key)
        self.assertEqual(self.delegatesContract.delegators(GS_PROJECT_ID, self.accounts[4].address),
                         self.accounts[8].address)
        self.assertEqual(self.delegatesContract.delegates(GS_PROJECT_ID, self.accounts[8].address, 0),
                         self.accounts[4].address)

        # delegate accounts[0] to accounts[4]
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[4].address,
                                        private_key=self.accounts[0].key)
        self.assertEqual(self.delegatesContract.delegators(GS_PROJECT_ID, self.accounts[0].address),
                         self.accounts[4].address)
        self.assertEqual(self.delegatesContract.delegates(GS_PROJECT_ID, self.accounts[4].address, 2),
                         self.accounts[0].address)

    def test_scenario_4(self):
        self.tokenContract.transfer(self.accounts[0].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[1].address, self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[3].address, self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[5].address, self.DECIMALS,
                                    private_key=self.accounts[9].key)

        # delegate some addresses
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[0].address,
                                        private_key=self.accounts[1].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[0].address,
                                        private_key=self.accounts[2].key)

        # propose transaction and vote
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [4 * self.DECIMALS],
                                                     [self.accounts[6].address], [0],
                                                     private_key=self.accounts[3].key)  # 2 yes and 0 no
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[0].key)  # 6 yes and 0 no
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[4].key)  # 0 yes and 1 no
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[5].key)  # 0 yes and 2 no
        # change vote for account 3
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[
                                                 3].key)  # 0 yes and 2 no(and remove 2 yes from proposal)

        # 6 yes and 5 no
        balance_before = self.tokenContract.balanceOf(self.accounts[6].address)
        increase_time(VOTE_DURATION + 15)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[6].address), balance_before + 4 * self.DECIMALS)

        # propose a second transaction and vote
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [2 * self.DECIMALS],
                                                     [self.accounts[6].address], [0],
                                                     private_key=self.accounts[1].key)  # 2 yes and 0 no
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[0].key)  # 6 yes and 0 no
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[3].key)  # 0 yes and 2 no
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[4].key)  # 0 yes and 1 no
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[5].key)  # 0 yes and 2 no
        # change vote for account 3
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[
                                                 1].key)  # 0 yes and 2 no(and remove 2 yes from proposal)

        # 6 yes and 7 no
        balance_before = self.tokenContract.balanceOf(self.accounts[6].address)
        increase_time(VOTE_DURATION + 15)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID,
                                                  expect_to_not_execute=True)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[6].address), balance_before)

    def test_scenario_5(self):
        self.tokenContract.transfer(self.accounts[1].address, self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[3].address, 4 * self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[4].address, self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[5].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[8].address, 3 * self.DECIMALS,
                                    private_key=self.accounts[9].key)

        # delegate some addresses
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[0].address,
                                        private_key=self.accounts[1].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[0].address,
                                        private_key=self.accounts[2].key)

        # propose transaction and vote
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[7].address], [0],
                                                     private_key=self.accounts[5].key)  # 3 yes and 0 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 600 * self.DECIMALS, 400 * self.DECIMALS,
                                             private_key=self.accounts[0].key)  # 2.4 yes and 1.6 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 500 * self.DECIMALS, 500 * self.DECIMALS,
                                             private_key=self.accounts[3].key)  # 2.5 yes and 2.5 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 0, 500 * self.DECIMALS,
                                             private_key=self.accounts[4].key)  # 0 yes and 2 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 0, 100 * self.DECIMALS,
                                             private_key=self.accounts[6].key)  # 0 yes and 1 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 55 * self.DECIMALS, 45 * self.DECIMALS,
                                             private_key=self.accounts[7].key)  # 0.55 yes and 0.45 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 0, 2 * self.DECIMALS,
                                             private_key=self.accounts[8].key)  # 0 yes and 2 no

        # 8.45 yes and 9.45 no
        balance_before = self.tokenContract.balanceOf(self.accounts[6].address)
        increase_time(VOTE_DURATION + 15)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID,
                                                  expect_to_not_execute=True)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[6].address), balance_before)

    def test_scenario_6(self):
        self.tokenContract.transfer(self.accounts[1].address, self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[4].address, self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[5].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[7].address, 5 * self.DECIMALS,
                                    private_key=self.accounts[9].key)

        # delegate some addresses
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[0].address,
                                        private_key=self.accounts[1].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[0].address,
                                        private_key=self.accounts[2].key)

        # propose transaction and vote
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[8].address], [0],
                                                     private_key=self.accounts[5].key)  # 3 yes and 0 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 0, 600 * self.DECIMALS,
                                             private_key=self.accounts[7].key)  # 0 yes and 6 no
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[6].key)  # 0 yes and 1 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 10 * self.DECIMALS, 0,
                                             private_key=self.accounts[3].key)  # 1 yes and 0 no
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[4].key)  # 0 yes and 2 no
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[8].key)  # 1 yes and 0 no
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[0].key)  # 4 yes and 0 no

        # 9 yes and 9 no
        balance_before = self.tokenContract.balanceOf(self.accounts[6].address)
        increase_time(VOTE_DURATION + 15)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID,
                                                  expect_to_not_execute=True)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[6].address), balance_before)

    def test_scenario_7(self):
        self.tokenContract.transfer(self.accounts[1].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[4].address, self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[5].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[7].address, self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[8].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].key)

        # delegate some addresses
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[0].address,
                                        private_key=self.accounts[1].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[0].address,
                                        private_key=self.accounts[2].key)

        # propose transaction and vote
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[2].address], [0],
                                                     private_key=self.accounts[5].key)  # 3 yes and 0 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 0, 700 * self.DECIMALS,
                                             private_key=self.accounts[7].key)  # 0 yes and 2 no
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[3].key)  # 0 yes and 1 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 0, 100 * self.DECIMALS,
                                             private_key=self.accounts[4].key)  # 0 yes and 2 no
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[0].key)  # 5 yes and 0 no

        # delegate some accounts
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[0].address,
                                        private_key=self.accounts[6].key)  # this will add 1 to yes and 0 to no
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[0].address,
                                        private_key=self.accounts[7].key)  # no effect as account 7 already voted
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[3].address,
                                        private_key=self.accounts[8].key)  # this will add 0 to yes and 3 to no

        # 9 yes and 8 no
        balance_before = self.tokenContract.balanceOf(self.accounts[2].address)
        increase_time(VOTE_DURATION + 15)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[2].address), balance_before + self.DECIMALS)

    def test_scenario_8(self):
        self.tokenContract.transfer(self.accounts[1].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[4].address, self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[5].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[6].address, self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[7].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[8].address, 5 * self.DECIMALS,
                                    private_key=self.accounts[9].key)

        # delegate some addresses
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[0].address,
                                        private_key=self.accounts[1].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[0].address,
                                        private_key=self.accounts[2].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[0].address,
                                        private_key=self.accounts[4].key)

        # propose transaction and vote
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[0].address], [0],
                                                     private_key=self.accounts[7].key)  # 3 yes and 0 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 900 * self.DECIMALS, 0,
                                             private_key=self.accounts[8].key)  # 6 yes and 0 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 0, 700 * self.DECIMALS,
                                             private_key=self.accounts[8].key)  # remove 6 yes and add 6 no
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[3].key)  # 0 yes and 1 no
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[3].key)  # add 1 yes and remove 1 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 0, 5 * 10 ** 17,
                                             private_key=self.accounts[6].key)  # 0 yes and 2 no
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[0].key)  # 7 yes and 0 no
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[1].key)  # remove 3 yes and add 3 no

        # delegate some accounts
        self.delegatesContract.undelegate(GS_PROJECT_ID,
                                          private_key=self.accounts[
                                              1].key)  # no effect, address voted independently already
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 0, 100 * self.DECIMALS,
                                             private_key=self.accounts[2].key)  # remove 1 yes and add 1 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 300 * self.DECIMALS, 300 * self.DECIMALS,
                                             private_key=self.accounts[4].key)  # remove 1 yes and add 1 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 290 * self.DECIMALS, 310 * self.DECIMALS,
                                             private_key=self.accounts[8].key)  # add 2.9 yes and remove 3.1 no
        # 8.9 yes and 10.1 no
        balance_before = self.tokenContract.balanceOf(self.accounts[0].address)
        increase_time(VOTE_DURATION + 15)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[0].address), balance_before)

    def test_scenario_9(self):
        self.tokenContract.transfer(self.accounts[1].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[4].address, self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[5].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[6].address, self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[7].address, 2 * self.DECIMALS,
                                    private_key=self.accounts[9].key)
        self.tokenContract.transfer(self.accounts[8].address, 5 * self.DECIMALS,
                                    private_key=self.accounts[9].key)

        # delegate some addresses
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[0].address,
                                        private_key=self.accounts[1].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[0].address,
                                        private_key=self.accounts[2].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[0].address,
                                        private_key=self.accounts[4].key)

        self.delegatesContract.undelegateAllFromAddress(GS_PROJECT_ID, private_key=self.accounts[0].key)

        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[2].address,
                                        private_key=self.accounts[0].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[3].address,
                                        private_key=self.accounts[2].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[4].address,
                                        private_key=self.accounts[3].key)

        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[6].address,
                                        private_key=self.accounts[5].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[8].address,
                                        private_key=self.accounts[6].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[8].address,
                                        private_key=self.accounts[7].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[8].address,
                                        private_key=self.accounts[0].key)
        self.delegatesContract.undelegate(GS_PROJECT_ID, private_key=self.accounts[7].key)

        self.delegatesContract.undelegateAllFromAddress(GS_PROJECT_ID, private_key=self.accounts[8].key)

        # propose transaction and vote
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [self.DECIMALS],
                                                     [self.accounts[0].address], [0],
                                                     private_key=self.accounts[7].key)  # 3 yes and 0 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 3 * self.DECIMALS, 2 * self.DECIMALS,
                                             private_key=self.accounts[8].key)  # 3 yes and 2 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 2 * self.DECIMALS, 2 * self.DECIMALS,
                                             private_key=self.accounts[8].key)  # 2 yes and add 2 no
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[4].key)  # 0 yes and 3 no
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[3].key)  # 2 yes and remove 1 no
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 0, 6 * self.DECIMALS,
                                             private_key=self.accounts[1].key)  # 0 yes and 3 no
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, False,
                                             private_key=self.accounts[0].key)  # 0 yes and 1 no

        # 10 yes and 10 no
        balance_before = self.tokenContract.balanceOf(self.accounts[0].address)
        increase_time(VOTE_DURATION + 15)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID,
                                                  expect_to_not_execute=True)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[0].address), balance_before)
