from web3 import Web3

from contract_proposals_data_structs import Proposals, ChangeParameterProposal, TokenSellProposal, \
    AuctionSellProposal, \
    ChangeTrustedAddressProposal, CreateTokensProposal, AddBurnAddressProposal
from test.py_tests.tests import EthBaseTest
from utils import WEB3, increase_time, VOTE_DURATION, CONTRACTS_INDEX, ZERO_ETH_ADDRESS, Defaults, fetch_events, \
    deploy_contract_version_and_wait, send_eth, GS_PROJECT_ID, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY


class ProposalsTests(EthBaseTest):

    def setUp(self):
        super().setUp()
        self.create_test_account(token_contract=self.tokenContract)
        self.create_test_account(token_contract=self.tokenContract)
        self.create_test_account(token_contract=self.tokenContract)
        self.create_test_account(token_contract=self.tokenContract)

    @staticmethod
    def get_event(receipt, contract, event_name):
        block_number = receipt.blockNumber
        return next(fetch_events(contract._c().events[event_name], from_block=block_number))

    def test_propose_token_transaction(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        tx = self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [100],
                                                          [self.accounts[1].address], [0],
                                                          private_key=self.accounts[0].key)

        event = self.get_event(WEB3.eth.get_transaction_receipt(tx), self.proposalContract, 'NewProposal')

        self.assertEqual(WEB3.eth.get_transaction_receipt(tx).status, 1)

        tx = self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                                  private_key=self.accounts[0].key)

        self.assertEqual(WEB3.eth.get_transaction_receipt(tx).status, 1)
        increase_time(VOTE_DURATION + 15)

        self.assertTrue(proposal_id < self.proposalContract.nextProposalId(GS_PROJECT_ID))
        proposal = Proposals(self.proposalContract, 0, proposal_id)
        self.assertTrue(proposal.votingAllowed)

        balanceBefore = self.tokenContract.balanceOf(self.accounts[1].address)
        tx = self.fundsManagerContract.processProposal(proposal_id,
                                                       private_key=self.accounts[0].key,
                                                       contract_project_id=GS_PROJECT_ID)

        self.assertEqual(WEB3.eth.get_transaction_receipt(tx).status, 1)

        self.assertEqual(self.tokenContract.balanceOf(self.accounts[1].address), balanceBefore + 100)

    def test_propose_token_transaction_and_vote_with_amount(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].key)

        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 300, 100,
                                             private_key=self.accounts[0].key)
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 500, 700,
                                             private_key=self.accounts[1].key)
        self.proposalContract.voteWithAmount(GS_PROJECT_ID, proposal_id, 200, 100,
                                             private_key=self.accounts[2].key)

        increase_time(VOTE_DURATION + 15)

        self.assertTrue(proposal_id < self.proposalContract.nextProposalId(GS_PROJECT_ID))
        proposal = Proposals(self.proposalContract, 0, proposal_id)
        self.assertTrue(proposal.votingAllowed)

        balanceBefore = self.tokenContract.balanceOf(self.accounts[1].address)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID)

        self.assertEqual(self.tokenContract.balanceOf(self.accounts[1].address), balanceBefore + 100)

    def test_propose_token_transaction_and_check_before_end_time(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].key)

        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[1].key)
        try:
            self.fundsManagerContract.processProposal(proposal_id,
                                                      private_key=self.accounts[0].key,
                                                      contract_project_id=GS_PROJECT_ID)
            self.fail()
        except Exception as e:
            self.assertIn("Voting is ongoing", str(e))

    def test_propose_token_transaction_and_check_after_processed(self):
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
            self.fundsManagerContract.processProposal(proposal_id,
                                                      private_key=self.accounts[0].key,
                                                      contract_project_id=GS_PROJECT_ID)
            self.fail()
        except Exception as e:
            self.assertIn("Proposal expired", str(e))

    def test_propose_token_transaction_with_amount_greater_than_contract_balance(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        contract_balance = self.tokenContract.balanceOf(self.fundsManagerContract.address)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address],
                                                     [contract_balance + 100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].key)

        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[1].key)

        increase_time(VOTE_DURATION + 15)
        try:
            self.fundsManagerContract.processProposal(proposal_id,
                                                      private_key=self.accounts[0].key,
                                                      contract_project_id=GS_PROJECT_ID)
            self.fail()
        except Exception as e:
            self.assertIn("Not enough balance", str(e))

    def test_propose_token_transaction_for_other_token_than_voting_token(self):
        self.tokenSaturnContract, self.tokenTxHash = deploy_contract_version_and_wait('Token', 'latest',
                                                                                      'PROJ_DB_ID',
                                                                                      self.fm_supply,
                                                                                      self.token_buffer_amount,
                                                                                      self.contractsManagerContract.address,
                                                                                      self.fundsManagerContract.address,
                                                                                      self.proposalContract.address,
                                                                                      'Saturn', 'ST',
                                                                                      private_key=self.accounts[
                                                                                          0].key,
                                                                                      allow_cache=True)
        project_id = 1
        proposal_id = 0
        self.fundsManagerContract.proposeTransaction(project_id, [self.tokenSaturnContract.address], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].key)
        self.proposalContract.voteProposalId(project_id, proposal_id, True,
                                             private_key=self.accounts[0].key)
        increase_time(VOTE_DURATION + 15)

        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=project_id)

        self.assertEqual(self.tokenSaturnContract.balanceOf(self.accounts[1].address), 100)

    def test_propose_eth_transaction(self):
        self.fundsManagerContract.depositEth(GS_PROJECT_ID, private_key=INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY,
                                             wei=0.0005 * 10 ** 18)

        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [ZERO_ETH_ADDRESS], [100],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[0].key)
        eth_balance_before = WEB3.eth.get_balance(self.accounts[1].address)
        increase_time(VOTE_DURATION + 15)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID)

        self.assertEqual(WEB3.eth.get_balance(self.accounts[1].address), eth_balance_before + 100)

    def test_propose_create_tokens(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        create_amount = 1000 * 10 ** 18
        self.tokenContract.proposeCreateTokens(create_amount, private_key=self.accounts[0].key)

        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[1].key)
        total_supply_before = self.tokenContract.totalSupply()
        fm_balance_before = self.tokenContract.balanceOf(self.fundsManagerContract.address)

        p = CreateTokensProposal(self.tokenContract, GS_PROJECT_ID, proposal_id)

        self.assertEqual(p.amount, 1000)

        increase_time(VOTE_DURATION + 15)
        self.tokenContract.processProposal(proposal_id,
                                           private_key=self.accounts[0].key,
                                           contract_project_id=GS_PROJECT_ID)

        self.assertEqual(self.tokenContract.totalSupply(), total_supply_before + create_amount)
        self.assertEqual(self.tokenContract.balanceOf(self.fundsManagerContract.address),
                         fm_balance_before + create_amount)

    def test_propose_change_parameter(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.proposalContract.proposeParameterChange(GS_PROJECT_ID, Web3.keccak(text="VoteDuration"), 86400,
                                                     private_key=self.accounts[0].key)

        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[0].key)
        increase_time(VOTE_DURATION + 15)

        self.assertTrue(proposal_id < self.proposalContract.nextProposalId(GS_PROJECT_ID))
        proposal = Proposals(self.proposalContract, 0, proposal_id)
        self.assertTrue(proposal.votingAllowed)
        parameter_proposal = ChangeParameterProposal(self.proposalContract, 0, proposal_id)
        self.assertEqual(parameter_proposal.value, 86400)
        self.assertEqual(parameter_proposal.parameterName, "VoteDuration")

        self.proposalContract.processProposal(proposal_id,
                                              private_key=self.accounts[0].key,
                                              contract_project_id=GS_PROJECT_ID)
        self.assertEqual(self.proposalContract.parameters(GS_PROJECT_ID, WEB3.keccak(text="VoteDuration"))[0], 86400)

    def test_propose_auction_token_sell(self):
        auction_token_sell_proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        auction_duration = 120
        start_time = WEB3.eth.get_block('latest')['timestamp'] + VOTE_DURATION
        end_time = start_time + auction_duration
        self.tokenSellContract.proposeAuctionTokenSell(GS_PROJECT_ID, self.tokenContract.address, 10 ** 20, 0,
                                                       start_time, end_time,
                                                       private_key=self.accounts[0].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, auction_token_sell_proposal_id, True,
                                             private_key=self.accounts[1].key)

        increase_time(VOTE_DURATION + 15)
        proposal = Proposals(self.proposalContract, 0, auction_token_sell_proposal_id)
        self.assertTrue(proposal.votingAllowed)
        token_sell_proposal = AuctionSellProposal(self.tokenSellContract, 0, auction_token_sell_proposal_id)
        self.assertEqual(token_sell_proposal.tokenToSell, self.tokenContract.address)
        self.assertEqual(token_sell_proposal.totalEthReceived, 0)
        self.assertEqual(token_sell_proposal.minimumWei, 0)
        self.assertEqual(token_sell_proposal.nbOfTokens, 100)
        self.assertEqual(token_sell_proposal.startTime, start_time)
        self.assertEqual(token_sell_proposal.endTime, end_time)
        self.assertEqual(token_sell_proposal.canBuy, False)

        self.tokenSellContract.processProposal(auction_token_sell_proposal_id, private_key=self.accounts[0].key,
                                               contract_project_id=GS_PROJECT_ID)
        token_sell_proposal = AuctionSellProposal(self.tokenSellContract, 0, auction_token_sell_proposal_id)
        self.assertEqual(token_sell_proposal.canBuy, True)

        self.tokenSellContract.buyAuction(GS_PROJECT_ID, auction_token_sell_proposal_id,
                                          private_key=self.accounts[0].key,
                                          wei=2 * 10 ** 10)
        self.tokenSellContract.buyAuction(GS_PROJECT_ID, auction_token_sell_proposal_id,
                                          private_key=self.accounts[1].key,
                                          wei=8 * 10 ** 10)

        account_0_balance_before = self.tokenContract.balanceOf(self.accounts[0].address)
        account_1_balance_before = self.tokenContract.balanceOf(self.accounts[1].address)
        funds_manager_balance = WEB3.eth.get_balance(self.fundsManagerContract.address)

        increase_time(auction_duration)
        self.tokenSellContract.claimAuction(GS_PROJECT_ID, auction_token_sell_proposal_id,
                                            private_key=self.accounts[0].key)
        self.tokenSellContract.claimAuction(GS_PROJECT_ID, auction_token_sell_proposal_id,
                                            private_key=self.accounts[1].key)

        account_0_balance_after = self.tokenContract.balanceOf(self.accounts[0].address)
        account_1_balance_after = self.tokenContract.balanceOf(self.accounts[1].address)

        self.assertEqual(account_0_balance_before, account_0_balance_after - 2 * 10 ** 19)
        self.assertEqual(account_1_balance_before, account_1_balance_after - 8 * 10 ** 19)
        self.assertEqual(WEB3.eth.get_balance(self.fundsManagerContract.address), funds_manager_balance + 10 ** 11)

    def test_propose_auction_token_sell_and_mass_claim(self):
        auction_token_sell_proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        auction_duration = 120
        start_time = WEB3.eth.get_block('latest')['timestamp'] + VOTE_DURATION
        end_time = start_time + auction_duration
        self.tokenSellContract.proposeAuctionTokenSell(GS_PROJECT_ID, self.tokenContract.address, 10 ** 20, 0,
                                                       start_time, end_time,
                                                       private_key=self.accounts[0].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, auction_token_sell_proposal_id, True,
                                             private_key=self.accounts[1].key)

        increase_time(VOTE_DURATION + 15)
        proposal = Proposals(self.proposalContract, 0, auction_token_sell_proposal_id)
        self.assertTrue(proposal.votingAllowed)
        token_sell_proposal = AuctionSellProposal(self.tokenSellContract, 0, auction_token_sell_proposal_id)
        self.assertEqual(token_sell_proposal.tokenToSell, self.tokenContract.address)
        self.assertEqual(token_sell_proposal.totalEthReceived, 0)
        self.assertEqual(token_sell_proposal.minimumWei, 0)
        self.assertEqual(token_sell_proposal.nbOfTokens, 100)
        self.assertEqual(token_sell_proposal.startTime, start_time)
        self.assertEqual(token_sell_proposal.endTime, end_time)
        self.assertEqual(token_sell_proposal.canBuy, False)

        self.tokenSellContract.processProposal(auction_token_sell_proposal_id, private_key=self.accounts[0].key,
                                               contract_project_id=GS_PROJECT_ID)
        token_sell_proposal = AuctionSellProposal(self.tokenSellContract, 0, auction_token_sell_proposal_id)
        self.assertEqual(token_sell_proposal.canBuy, True)

        self.tokenSellContract.buyAuction(GS_PROJECT_ID, auction_token_sell_proposal_id,
                                          private_key=self.accounts[0].key,
                                          wei=2 * 10 ** 10)
        self.tokenSellContract.buyAuction(GS_PROJECT_ID, auction_token_sell_proposal_id,
                                          private_key=self.accounts[1].key,
                                          wei=8 * 10 ** 10)

        account_0_balance_before = self.tokenContract.balanceOf(self.accounts[0].address)
        account_1_balance_before = self.tokenContract.balanceOf(self.accounts[1].address)
        funds_manager_balance = WEB3.eth.get_balance(self.fundsManagerContract.address)

        increase_time(auction_duration)
        self.tokenSellContract.massClaimAuction(GS_PROJECT_ID, auction_token_sell_proposal_id,
                                                [self.accounts[0].address, self.accounts[1].address],
                                                private_key=self.accounts[0].key)

        account_0_balance_after = self.tokenContract.balanceOf(self.accounts[0].address)
        account_1_balance_after = self.tokenContract.balanceOf(self.accounts[1].address)

        self.assertEqual(account_0_balance_before, account_0_balance_after - 2 * 10 ** 19)
        self.assertEqual(account_1_balance_before, account_1_balance_after - 8 * 10 ** 19)
        self.assertEqual(WEB3.eth.get_balance(self.fundsManagerContract.address), funds_manager_balance + 10 ** 11)

    def test_propose_auction_token_sell_with_minimum_wei_not_satisfied(self):
        auction_token_sell_proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        auction_duration = 120
        start_time = WEB3.eth.get_block('latest')['timestamp'] + VOTE_DURATION
        end_time = start_time + auction_duration
        self.tokenSellContract.proposeAuctionTokenSell(GS_PROJECT_ID, self.tokenContract.address, 10 ** 20, 10 ** 20,
                                                       start_time,
                                                       end_time,
                                                       private_key=self.accounts[0].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, auction_token_sell_proposal_id, True,
                                             private_key=self.accounts[1].key)

        increase_time(VOTE_DURATION + 15)
        proposal = Proposals(self.proposalContract, 0, auction_token_sell_proposal_id)
        self.assertTrue(proposal.votingAllowed)
        token_sell_proposal = AuctionSellProposal(self.tokenSellContract, 0, auction_token_sell_proposal_id)
        self.assertEqual(token_sell_proposal.tokenToSell, self.tokenContract.address)
        self.assertEqual(token_sell_proposal.nbOfTokens, 100)
        self.assertEqual(token_sell_proposal.minimumWei, 10 ** 20)
        self.assertEqual(token_sell_proposal.totalEthReceived, 0)
        self.assertEqual(token_sell_proposal.startTime, start_time)
        self.assertEqual(token_sell_proposal.endTime, end_time)
        self.assertEqual(token_sell_proposal.canBuy, False)

        self.tokenSellContract.processProposal(auction_token_sell_proposal_id, private_key=self.accounts[0].key,
                                               contract_project_id=GS_PROJECT_ID)
        token_sell_proposal = AuctionSellProposal(self.tokenSellContract, 0, auction_token_sell_proposal_id)
        self.assertEqual(token_sell_proposal.canBuy, True)

        self.tokenSellContract.buyAuction(GS_PROJECT_ID, auction_token_sell_proposal_id,
                                          private_key=self.accounts[0].key,
                                          wei=2 * 10 ** 10)
        self.tokenSellContract.buyAuction(GS_PROJECT_ID, auction_token_sell_proposal_id,
                                          private_key=self.accounts[1].key,
                                          wei=8 * 10 ** 10)

        account_0_balance_before = self.tokenContract.balanceOf(self.accounts[0].address)
        account_1_balance_before = self.tokenContract.balanceOf(self.accounts[1].address)

        increase_time(auction_duration)
        self.tokenSellContract.claimAuction(GS_PROJECT_ID, auction_token_sell_proposal_id,
                                            private_key=self.accounts[0].key)
        self.tokenSellContract.claimAuction(GS_PROJECT_ID, auction_token_sell_proposal_id,
                                            private_key=self.accounts[1].key)

        account_0_balance_after = self.tokenContract.balanceOf(self.accounts[0].address)
        account_1_balance_after = self.tokenContract.balanceOf(self.accounts[1].address)

        self.assertEqual(account_0_balance_before, account_0_balance_after)
        self.assertEqual(account_1_balance_before, account_1_balance_after)

    def test_propose_change_trusted_address(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.contractsManagerContract.proposeChangeTrustedAddress(GS_PROJECT_ID, CONTRACTS_INDEX["Token"],
                                                                  self.proposalContract.address,
                                                                  private_key=self.accounts[0].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[1].key)
        increase_time(VOTE_DURATION + 15)
        proposal = Proposals(self.proposalContract, 0, proposal_id)
        self.assertTrue(proposal.votingAllowed)
        change_address_proposal = ChangeTrustedAddressProposal(self.contractsManagerContract, 0, proposal_id)
        self.assertEqual(change_address_proposal.contractIndex, CONTRACTS_INDEX["Token"])
        self.assertEqual(change_address_proposal.contractAddress, self.proposalContract.address)

        self.contractsManagerContract.processProposal(proposal_id, private_key=self.accounts[0].key,
                                                      contract_project_id=GS_PROJECT_ID)

        self.assertEqual(self.contractsManagerContract.trustedAddresses(GS_PROJECT_ID, CONTRACTS_INDEX["Token"]),
                         self.proposalContract.address)

    def test_propose_add_burn_address(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        burn_address = '0x1111111111111111111111111111111111111110'
        self.contractsManagerContract.proposeAddBurnAddress(GS_PROJECT_ID, burn_address,
                                                            private_key=self.accounts[0].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[1].key)
        increase_time(VOTE_DURATION + 15)
        proposal = Proposals(self.proposalContract, 0, proposal_id)
        self.assertTrue(proposal.votingAllowed)
        self.assertEqual(AddBurnAddressProposal(self.contractsManagerContract, 0, proposal_id).burn_address,
                         burn_address)

        self.contractsManagerContract.processProposal(proposal_id, private_key=self.accounts[0].key,
                                                      contract_project_id=GS_PROJECT_ID)

        self.assertEqual(self.contractsManagerContract.burnAddresses(GS_PROJECT_ID, 1), burn_address)

    # noinspection DuplicatedCode
    def test_propose_token_transactions(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        tx = self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address,
                                                                          self.tokenContract.address], [100, 5],
                                                          [self.accounts[1].address,
                                                           self.accounts[2].address],
                                                          [GS_PROJECT_ID, GS_PROJECT_ID],
                                                          private_key=self.accounts[0].key)

        self.assertEqual(WEB3.eth.get_transaction_receipt(tx).status, 1)

        tx = self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                                  private_key=self.accounts[0].key)

        self.assertEqual(WEB3.eth.get_transaction_receipt(tx).status, 1)
        increase_time(VOTE_DURATION + 15)

        self.assertTrue(proposal_id < self.proposalContract.nextProposalId(GS_PROJECT_ID))
        proposal = Proposals(self.proposalContract, 0, proposal_id)
        self.assertTrue(proposal.votingAllowed)

        balance_before_1 = self.tokenContract.balanceOf(self.accounts[1].address)
        balance_before_2 = self.tokenContract.balanceOf(self.accounts[2].address)
        tx = self.fundsManagerContract.processProposal(proposal_id,
                                                       private_key=self.accounts[0].key,
                                                       contract_project_id=GS_PROJECT_ID
                                                       )

        self.assertEqual(WEB3.eth.get_transaction_receipt(tx).status, 1)

        self.assertEqual(self.tokenContract.balanceOf(self.accounts[1].address), balance_before_1 + 100)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[2].address), balance_before_2 + 5)

    def test_propose_eth_transactions(self):
        self.fundsManagerContract.depositEth(GS_PROJECT_ID, private_key=INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY,
                                             wei=0.0005 * 10 ** 18)

        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [ZERO_ETH_ADDRESS, ZERO_ETH_ADDRESS], [100, 5],
                                                     [self.accounts[1].address, self.accounts[2].address],
                                                     [GS_PROJECT_ID, GS_PROJECT_ID],
                                                     private_key=self.accounts[0].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[0].key)
        eth_balance_before_1 = WEB3.eth.get_balance(self.accounts[1].address)
        eth_balance_before_2 = WEB3.eth.get_balance(self.accounts[2].address)
        increase_time(VOTE_DURATION + 15)
        self.fundsManagerContract.processProposal(proposal_id,
                                                  private_key=self.accounts[0].key,
                                                  contract_project_id=GS_PROJECT_ID)

        self.assertEqual(WEB3.eth.get_balance(self.accounts[1].address), eth_balance_before_1 + 100)
        self.assertEqual(WEB3.eth.get_balance(self.accounts[2].address), eth_balance_before_2 + 5)

    def test_remove_spam_votes(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        tx = self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [100],
                                                          [self.accounts[0].address], [0],
                                                          private_key=self.accounts[0].key)
        for i in range(4):
            self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                                 private_key=self.accounts[i].key)
            acc = WEB3.eth.account.create()
            send_eth(10 ** 18, acc.address, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY, unit='wei')
            self.tokenContract.transfer(acc.address, 10 ** 18, private_key=self.accounts[i].key)
            self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                                 private_key=acc.key)
            self.tokenContract.transfer(self.accounts[i].address, 10 ** 18, private_key=acc.key)

        spam_voters = self.proposalContract.getSpamVoters(GS_PROJECT_ID, proposal_id, private_key=self.private_key)

        self.assertEqual(spam_voters[:5], [1, 3, 5, 7, 0])
        spam_voters = [spam_voters[0], *[i for i in spam_voters[1:] if i != 0]]
        self.proposalContract.removeSpamVoters(GS_PROJECT_ID, proposal_id, spam_voters)

        proposal = Proposals(self.proposalContract, 0, proposal_id)
        self.assertTrue(proposal.nbOfVoters, 4)
