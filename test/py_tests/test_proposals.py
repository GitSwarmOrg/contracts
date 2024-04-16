import brownie
from brownie import accounts, chain
from brownie.network.transaction import TransactionReceipt
from web3 import Web3

from contract_proposals_data_structs import Proposals, ChangeParameterProposal, \
    AuctionSellProposal, \
    ChangeTrustedAddressProposal, CreateTokensProposal, AddBurnAddressProposal
from test.py_tests.tests import EthBaseTest
from utils import increase_time, VOTE_DURATION, CONTRACTS_INDEX, ZERO_ETH_ADDRESS, Defaults, fetch_events, \
    deploy_contract_version_and_wait, send_eth, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY


class ProposalsTests(EthBaseTest):

    def setUp(self):
        super().setUp()
        self.create_test_account()
        self.create_test_account()
        self.create_test_account()
        self.create_test_account()

    def get_event(self, receipt, event_name):
        events = receipt.events[event_name]
        if events:
            return events[0]
        return None

    def test_propose_token_transaction(self):
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        tx = self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [100],
                                                          [self.accounts[1].address], [0],
                                                          private_key=self.accounts[0].private_key)

        event = self.get_event(TransactionReceipt(tx), 'NewProposal')
        self.assertIsNotNone(event)
        self.assertEqual(TransactionReceipt(tx).status, 1)

        tx = self.proposalContract.vote(self.p_id, proposal_id, True,
                                        private_key=self.accounts[0].private_key)

        self.assertEqual(TransactionReceipt(tx).status, 1)
        increase_time(VOTE_DURATION)

        self.assertTrue(proposal_id < self.proposalContract.nextProposalId(self.p_id))
        proposal = Proposals(self.proposalContract, self.p_id, proposal_id)
        self.assertTrue(proposal.votingAllowed)

        balanceBefore = self.tokenContract.balanceOf(self.accounts[1].address)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].private_key,
                                                  expect_to_execute=True,
                                                  contract_project_id=self.p_id)

        self.assertEqual(TransactionReceipt(tx).status, 1)

        self.assertEqual(self.tokenContract.balanceOf(self.accounts[1].address), balanceBefore + 100)

    def test_propose_token_transaction_and_check_before_end_time(self):
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].private_key)

        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[1].private_key)
        try:
            self.fundsManagerContract.processProposal(proposal_id,
                                                      private_key=self.accounts[0].private_key,
                                                      contract_project_id=self.p_id)
            self.fail()
        except Exception as e:
            self.assertIn("Voting is ongoing", str(e))

    def test_propose_token_transaction_and_check_after_processed(self):
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].private_key)

        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[1].private_key)
        increase_time(VOTE_DURATION)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].private_key,
                                                  contract_project_id=self.p_id)
        try:
            self.fundsManagerContract.processProposal(proposal_id,
                                                      private_key=self.accounts[0].private_key,
                                                      contract_project_id=self.p_id)
            self.fail()
        except Exception as e:
            self.assertIn("Proposal expired", str(e))

    # def test_propose_token_transaction_with_amount_greater_than_contract_balance(self): # keep ------ can't run coverage
    #     proposal_id = self.proposalContract.nextProposalId(self.p_id)
    #     contract_balance = self.tokenContract.balanceOf(self.fundsManagerContract.address)
    #     self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address],
    #                                                  [contract_balance + 100],
    #                                                  [self.accounts[1].address], [0],
    #                                                  private_key=self.accounts[0].private_key)
    #
    #     self.proposalContract.vote(self.p_id, proposal_id, True,
    #                                private_key=self.accounts[1].private_key)
    #
    #     increase_time(VOTE_DURATION)
    #
    #     try:
    #         with brownie.reverts():
    #             self.fundsManagerContract.processProposal(proposal_id,
    #                                                       private_key=self.accounts[0].private_key,
    #                                                       contract_project_id=self.p_id)
    #     except AttributeError as e:
    #         # brownie bug in version 1.20.2 where it fails to get the revert message, arithmetic underflow in this case
    #         self.assertIn("'str' object has no attribute 'hex'", str(e))

    def test_propose_token_transaction_for_other_token_than_voting_token(self):
        self.tokenSaturnContract, self.tokenTxHash = deploy_contract_version_and_wait('ExpandableSupplyToken', 'latest',
                                                                                      'PROJ_DB_ID',
                                                                                      self.fm_supply,
                                                                                      self.token_buffer_amount,
                                                                                      self.contractsManagerContract.address,
                                                                                      self.fundsManagerContract.address,
                                                                                      self.proposalContract.address,
                                                                                      'Saturn', 'ST',
                                                                                      private_key=self.accounts[
                                                                                          0].private_key)
        project_id = self.p_id + 1
        proposal_id = 0
        self.fundsManagerContract.proposeTransaction(project_id, [self.tokenSaturnContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].private_key)
        self.proposalContract.vote(project_id, proposal_id, True,
                                   private_key=self.accounts[0].private_key)
        increase_time(VOTE_DURATION)

        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].private_key,
                                                  contract_project_id=project_id)

        self.assertEqual(self.tokenSaturnContract.balanceOf(self.accounts[1].address), 100)


    def test_propose_eth_transaction(self):
        self.fundsManagerContract.depositEth(self.p_id, private_key=INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY,
                                             wei=int(0.0005 * 10 ** 18))

        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [ZERO_ETH_ADDRESS], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[0].private_key)
        eth_balance_before = self.accounts[1].balance()
        increase_time(VOTE_DURATION)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.private_key,
                                                  expect_to_execute=True,
                                                  contract_project_id=self.p_id)

        self.assertEqual(self.accounts[1].balance(), eth_balance_before + 100)

    def test_propose_create_tokens(self):
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        create_amount = 1000 * 10 ** 18
        self.tokenContract.proposeCreateTokens(create_amount, private_key=self.accounts[0].private_key)

        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[1].private_key)
        total_supply_before = self.tokenContract.totalSupply()
        fm_balance_before = self.tokenContract.balanceOf(self.fundsManagerContract.address)

        p = CreateTokensProposal(self.tokenContract, self.p_id, proposal_id)

        self.assertEqual(p.amount, 1000)

        increase_time(VOTE_DURATION)
        self.tokenContract.processProposal(proposal_id,
                                           private_key=self.accounts[0].private_key,
                                           contract_project_id=self.p_id)

        self.assertEqual(self.tokenContract.totalSupply(), total_supply_before + create_amount)
        self.assertEqual(self.tokenContract.balanceOf(self.fundsManagerContract.address),
                         fm_balance_before + create_amount)

    def test_propose_change_parameter(self):
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.proposalContract.proposeParameterChange(self.p_id, Web3.keccak(text="VoteDuration"), 86400,
                                                     private_key=self.accounts[0].private_key)

        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[0].private_key)
        increase_time(VOTE_DURATION)

        self.assertTrue(proposal_id < self.proposalContract.nextProposalId(self.p_id))
        proposal = Proposals(self.proposalContract, self.p_id, proposal_id)
        self.assertTrue(proposal.votingAllowed)
        parameter_proposal = ChangeParameterProposal(self.proposalContract, self.p_id,  proposal_id)
        self.assertEqual(parameter_proposal.value, 86400)
        self.assertEqual(parameter_proposal.parameterName, "VoteDuration")

        self.proposalContract.processProposal(proposal_id,
                                              private_key=self.accounts[0].private_key,
                                              contract_project_id=self.p_id)
        self.assertEqual(self.proposalContract.parameters(self.p_id, Web3.keccak(text="VoteDuration")), 86400)

    def test_propose_auction_token_sell(self):
        auction_token_sell_proposal_id = self.proposalContract.nextProposalId(self.p_id)
        auction_duration = 120
        start_time = chain[-1].timestamp + VOTE_DURATION
        end_time = start_time + auction_duration
        self.parametersContract.proposeAuctionTokenSell(self.p_id, self.tokenContract.address, 10 ** 20, 0,
                                                       start_time, end_time,
                                                       private_key=self.accounts[0].private_key)
        self.proposalContract.vote(self.p_id, auction_token_sell_proposal_id, True,
                                   private_key=self.accounts[1].private_key)

        increase_time(VOTE_DURATION)
        proposal = Proposals(self.proposalContract, self.p_id, auction_token_sell_proposal_id)
        self.assertTrue(proposal.votingAllowed)
        token_sell_proposal = AuctionSellProposal(self.tokenSellContract, self.p_id,  auction_token_sell_proposal_id)
        self.assertEqual(token_sell_proposal.tokenToSell, self.tokenContract.address)
        self.assertEqual(token_sell_proposal.totalEthReceived, 0)
        self.assertEqual(token_sell_proposal.minimumWei, 0)
        self.assertEqual(token_sell_proposal.nbOfTokens, 100)
        self.assertEqual(token_sell_proposal.startTime, start_time)
        self.assertEqual(token_sell_proposal.endTime, end_time)
        self.assertEqual(token_sell_proposal.canBuy, False)

        self.tokenSellContract.processProposal(auction_token_sell_proposal_id, private_key=self.accounts[0].private_key,
                                               contract_project_id=self.p_id)
        token_sell_proposal = AuctionSellProposal(self.tokenSellContract, self.p_id,  auction_token_sell_proposal_id)
        self.assertEqual(token_sell_proposal.canBuy, True)

        self.tokenSellContract.buyAuction(self.p_id, auction_token_sell_proposal_id,
                                          private_key=self.accounts[0].private_key,
                                          wei=2 * 10 ** 10)
        self.tokenSellContract.buyAuction(self.p_id, auction_token_sell_proposal_id,
                                          private_key=self.accounts[1].private_key,
                                          wei=8 * 10 ** 10)

        account_0_balance_before = self.tokenContract.balanceOf(self.accounts[0].address)
        account_1_balance_before = self.tokenContract.balanceOf(self.accounts[1].address)
        funds_manager_balance = self.fundsManagerContract.balance()

        increase_time(auction_duration)
        self.tokenSellContract.claimAuction(self.p_id, auction_token_sell_proposal_id,
                                            private_key=self.accounts[0].private_key)
        self.tokenSellContract.claimAuction(self.p_id, auction_token_sell_proposal_id,
                                            private_key=self.accounts[1].private_key)

        account_0_balance_after = self.tokenContract.balanceOf(self.accounts[0].address)
        account_1_balance_after = self.tokenContract.balanceOf(self.accounts[1].address)

        self.assertEqual(account_0_balance_before, account_0_balance_after - 2 * 10 ** 19)
        self.assertEqual(account_1_balance_before, account_1_balance_after - 8 * 10 ** 19)
        self.assertEqual(self.fundsManagerContract.balance(), funds_manager_balance + 10 ** 11)
    #
    def test_propose_auction_token_sell_and_mass_claim(self):
        auction_token_sell_proposal_id = self.proposalContract.nextProposalId(self.p_id)
        auction_duration = 120
        start_time = chain[-1].timestamp + VOTE_DURATION
        end_time = start_time + auction_duration
        self.tokenSellContract.proposeAuctionTokenSell(self.p_id, self.tokenContract.address, 10 ** 20, 0,
                                                       start_time, end_time,
                                                       private_key=self.accounts[0].private_key)
        self.proposalContract.vote(self.p_id, auction_token_sell_proposal_id, True,
                                   private_key=self.accounts[1].private_key)

        increase_time(VOTE_DURATION)
        proposal = Proposals(self.proposalContract, self.p_id, auction_token_sell_proposal_id)
        self.assertTrue(proposal.votingAllowed)
        token_sell_proposal = AuctionSellProposal(self.tokenSellContract, self.p_id,  auction_token_sell_proposal_id)
        self.assertEqual(token_sell_proposal.tokenToSell, self.tokenContract.address)
        self.assertEqual(token_sell_proposal.totalEthReceived, 0)
        self.assertEqual(token_sell_proposal.minimumWei, 0)
        self.assertEqual(token_sell_proposal.nbOfTokens, 100)
        self.assertEqual(token_sell_proposal.startTime, start_time)
        self.assertEqual(token_sell_proposal.endTime, end_time)
        self.assertEqual(token_sell_proposal.canBuy, False)

        self.tokenSellContract.processProposal(auction_token_sell_proposal_id, private_key=self.accounts[0].private_key,
                                               contract_project_id=self.p_id)
        token_sell_proposal = AuctionSellProposal(self.tokenSellContract, self.p_id,  auction_token_sell_proposal_id)
        self.assertEqual(token_sell_proposal.canBuy, True)

        self.tokenSellContract.buyAuction(self.p_id, auction_token_sell_proposal_id,
                                          private_key=self.accounts[0].private_key,
                                          wei=2 * 10 ** 10)
        self.tokenSellContract.buyAuction(self.p_id, auction_token_sell_proposal_id,
                                          private_key=self.accounts[1].private_key,
                                          wei=8 * 10 ** 10)

        account_0_balance_before = self.tokenContract.balanceOf(self.accounts[0].address)
        account_1_balance_before = self.tokenContract.balanceOf(self.accounts[1].address)
        funds_manager_balance = self.fundsManagerContract.balance()

        increase_time(auction_duration)
        self.tokenSellContract.massClaimAuction(self.p_id, auction_token_sell_proposal_id,
                                                [self.accounts[0].address, self.accounts[1].address],
                                                private_key=self.accounts[0].private_key)

        account_0_balance_after = self.tokenContract.balanceOf(self.accounts[0].address)
        account_1_balance_after = self.tokenContract.balanceOf(self.accounts[1].address)

        self.assertEqual(account_0_balance_before, account_0_balance_after - 2 * 10 ** 19)
        self.assertEqual(account_1_balance_before, account_1_balance_after - 8 * 10 ** 19)
        self.assertEqual(self.fundsManagerContract.balance(), funds_manager_balance + 10 ** 11)

    def test_propose_auction_token_sell_with_minimum_wei_not_satisfied(self):
        auction_token_sell_proposal_id = self.proposalContract.nextProposalId(self.p_id)
        auction_duration = 120
        start_time = chain[-1].timestamp + VOTE_DURATION
        end_time = start_time + auction_duration
        self.tokenSellContract.proposeAuctionTokenSell(self.p_id, self.tokenContract.address, 10 ** 20, 10 ** 20,
                                                       start_time,
                                                       end_time,
                                                       private_key=self.accounts[0].private_key)
        self.proposalContract.vote(self.p_id, auction_token_sell_proposal_id, True,
                                   private_key=self.accounts[1].private_key)

        increase_time(VOTE_DURATION)
        proposal = Proposals(self.proposalContract, self.p_id, auction_token_sell_proposal_id)
        self.assertTrue(proposal.votingAllowed)
        token_sell_proposal = AuctionSellProposal(self.tokenSellContract, self.p_id,  auction_token_sell_proposal_id)
        self.assertEqual(token_sell_proposal.tokenToSell, self.tokenContract.address)
        self.assertEqual(token_sell_proposal.nbOfTokens, 100)
        self.assertEqual(token_sell_proposal.minimumWei, 10 ** 20)
        self.assertEqual(token_sell_proposal.totalEthReceived, 0)
        self.assertEqual(token_sell_proposal.startTime, start_time)
        self.assertEqual(token_sell_proposal.endTime, end_time)
        self.assertEqual(token_sell_proposal.canBuy, False)

        self.tokenSellContract.processProposal(auction_token_sell_proposal_id, private_key=self.accounts[0].private_key,
                                               contract_project_id=self.p_id)
        token_sell_proposal = AuctionSellProposal(self.tokenSellContract, self.p_id,  auction_token_sell_proposal_id)
        self.assertEqual(token_sell_proposal.canBuy, True)

        self.tokenSellContract.buyAuction(self.p_id, auction_token_sell_proposal_id,
                                          private_key=self.accounts[0].private_key,
                                          wei=2 * 10 ** 10)
        self.tokenSellContract.buyAuction(self.p_id, auction_token_sell_proposal_id,
                                          private_key=self.accounts[1].private_key,
                                          wei=8 * 10 ** 10)

        account_0_balance_before = self.tokenContract.balanceOf(self.accounts[0].address)
        account_1_balance_before = self.tokenContract.balanceOf(self.accounts[1].address)

        increase_time(auction_duration)
        self.tokenSellContract.claimAuction(self.p_id, auction_token_sell_proposal_id,
                                            private_key=self.accounts[0].private_key)
        self.tokenSellContract.claimAuction(self.p_id, auction_token_sell_proposal_id,
                                            private_key=self.accounts[1].private_key)

        account_0_balance_after = self.tokenContract.balanceOf(self.accounts[0].address)
        account_1_balance_after = self.tokenContract.balanceOf(self.accounts[1].address)

        self.assertEqual(account_0_balance_before, account_0_balance_after)
        self.assertEqual(account_1_balance_before, account_1_balance_after)

    def test_propose_change_trusted_address(self):
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.contractsManagerContract.proposeChangeTrustedAddress(self.p_id, CONTRACTS_INDEX["Token"],
                                                                  self.proposalContract.address,
                                                                  private_key=self.accounts[0].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[1].private_key)
        increase_time(VOTE_DURATION)
        proposal = Proposals(self.proposalContract, self.p_id, proposal_id)
        self.assertTrue(proposal.votingAllowed)
        change_address_proposal = ChangeTrustedAddressProposal(self.contractsManagerContract, self.p_id,  proposal_id)
        self.assertEqual(change_address_proposal.index, CONTRACTS_INDEX["Token"])
        self.assertEqual(change_address_proposal.address, self.proposalContract.address)

        self.contractsManagerContract.processProposal(proposal_id, private_key=self.accounts[0].private_key,
                                                      contract_project_id=self.p_id)

        self.assertEqual(self.contractsManagerContract.trustedAddresses(self.p_id, CONTRACTS_INDEX["Token"]),
                         self.proposalContract.address)

    def test_propose_add_burn_address(self):
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        burn_address = '0x1111111111111111111111111111111111111110'
        self.contractsManagerContract.proposeAddBurnAddress(self.p_id, burn_address,
                                                            private_key=self.accounts[0].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[1].private_key)
        increase_time(VOTE_DURATION)
        proposal = Proposals(self.proposalContract, self.p_id, proposal_id)
        self.assertTrue(proposal.votingAllowed)
        self.assertEqual(AddBurnAddressProposal(self.contractsManagerContract, self.p_id,  proposal_id).burn_address,
                         burn_address)

        self.contractsManagerContract.processProposal(proposal_id, private_key=self.accounts[0].private_key,
                                                      contract_project_id=self.p_id)

        self.assertEqual(self.contractsManagerContract.burnAddresses(self.p_id, 1), burn_address)

    # noinspection DuplicatedCode
    def test_propose_token_transactions(self):  # keep
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        tx = self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address,
                                                                          self.tokenContract.address], [100, 5],
                                                          [self.accounts[1].address,
                                                           self.accounts[2].address],
                                                          [self.p_id, self.p_id],
                                                          private_key=self.accounts[0].private_key)

        self.assertEqual(TransactionReceipt(tx).status, 1)

        tx = self.proposalContract.vote(self.p_id, proposal_id, True,
                                        private_key=self.accounts[0].private_key)

        self.assertEqual(TransactionReceipt(tx).status, 1)
        increase_time(VOTE_DURATION)

        self.assertTrue(proposal_id < self.proposalContract.nextProposalId(self.p_id))
        proposal = Proposals(self.proposalContract, self.p_id, proposal_id)
        self.assertTrue(proposal.votingAllowed)

        balance_before_1 = self.tokenContract.balanceOf(self.accounts[1].address)
        balance_before_2 = self.tokenContract.balanceOf(self.accounts[2].address)
        tx_list = self.fundsManagerContract.processProposal(proposal_id,
                                                            private_key=self.accounts[0].private_key,
                                                            contract_project_id=self.p_id
                                                            )
        for tx in tx_list:
            self.assertEqual(TransactionReceipt(tx).status, 1)

        self.assertEqual(self.tokenContract.balanceOf(self.accounts[1].address), balance_before_1 + 100)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[2].address), balance_before_2 + 5)

    def test_propose_eth_transactions(self):
        self.fundsManagerContract.depositEth(self.p_id, private_key=INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY,
                                             wei=int(0.0005 * 10 ** 18))

        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.fundsManagerContract.proposeTransaction(self.p_id, [ZERO_ETH_ADDRESS, ZERO_ETH_ADDRESS], [100, 5],
                                                     [self.accounts[1].address, self.accounts[2].address],
                                                     [self.p_id, self.p_id],
                                                     private_key=self.accounts[0].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[0].private_key)
        eth_balance_before_1 = self.accounts[1].balance()
        eth_balance_before_2 = self.accounts[2].balance()
        increase_time(VOTE_DURATION)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].private_key,
                                                  contract_project_id=self.p_id)

        self.assertEqual(self.accounts[1].balance(), eth_balance_before_1 + 100)
        self.assertEqual(self.accounts[2].balance(), eth_balance_before_2 + 5)

    def test_remove_spam_votes(self):  # jeep
        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        tx = self.fundsManagerContract.proposeTransaction(self.p_id, [self.tokenContract.address], [100],
                                                          [self.accounts[0].address], [0],
                                                          private_key=self.accounts[0].private_key)
        for i in range(4):
            self.proposalContract.vote(self.p_id, proposal_id, True,
                                       private_key=self.accounts[i].private_key)
            acc = accounts.add()
            send_eth(10 ** 18, acc.address, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY, unit='wei')
            self.tokenContract.transfer(acc.address, 10 ** 18, private_key=self.accounts[i].private_key)
            self.proposalContract.vote(self.p_id, proposal_id, True,
                                       private_key=acc.private_key)
            self.tokenContract.transfer(self.accounts[i].address, 10 ** 18, private_key=acc.private_key)

        spam_voters = self.proposalContract.getSpamVoters(self.p_id, proposal_id, private_key=self.private_key)

        self.assertEqual(spam_voters[:5], [1, 3, 5, 7, 0])
        spam_voters = [spam_voters[0], *[i for i in spam_voters[1:] if i != 0]]
        self.proposalContract.removeSpamVoters(self.p_id, proposal_id, spam_voters)

        proposal = Proposals(self.proposalContract, self.p_id, proposal_id)
        self.assertTrue(proposal.nbOfVoters, 4)
