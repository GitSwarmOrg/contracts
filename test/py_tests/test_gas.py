from datetime import datetime
from unittest import skip

from contract_proposals_data_structs import Proposals, TokenSellProposal, AuctionSellProposal
from test.py_tests.tests import EthBaseTest
from utils import WEB3, increase_time, VOTE_DURATION, deploy_test_contract, \
    BUFFER_BETWEEN_END_OF_VOTING_AND_EXECUTE_PROPOSAL, ZERO_ETH_ADDRESS, send_eth, GS_PROJECT_ID, \
    INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY

GAS_PRICE = WEB3.to_wei('0.001', 'gwei')


# noinspection PyTypeChecker
class EthereumTests(EthBaseTest):
    def setUp(self):
        super().setUp()

        self.file = open("test/py_tests/test_gas.txt", "a")
        self.file.write("\n\n[" + str(datetime.utcnow()) + "]: " + self._testMethodName)

    def tearDown(self):
        self.file.close()

    @skip
    def test_gas_remove_spam_votes(self):
        self.file.write("\nRemove Spam Voters")
        self.create_test_account(token_contract=self.tokenContract)
        proposal_id = self.proposalContract.nextProposalId()
        tx = self.fundsManagerContract.proposTransaction(GS_PROJECT_ID, [self.tokenContract.address], [100],
                                                         [self.accounts[1].address], [0],
                                                         private_key=self.accounts[0].key)
        nr = 240
        self.file.write("\nNumber of Spam Voters: %s" % nr)
        for i in range(nr):
            acc = WEB3.eth.account.create()
            send_eth(10 ** 18, acc.address, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY, unit='wei')
            self.tokenContract.transfer(acc.address, 10 ** 18, private_key=self.accounts[0].key)
            self.proposalContract.voteProposalId(proposal_id, True,
                                                 private_key=acc.key)
            self.tokenContract.transfer(self.accounts[0].address, 10 ** 18, private_key=acc.key)

        spam_voters = self.proposalContract.getSpamVoters(proposal_id)

        tx = self.proposalContract.removeSpamVoters(proposal_id, spam_voters[:nr])
        gas_cost = tx.receipt.gasUsed
        self.file.write("\nGas cost for removeSpamVoters: %s " % gas_cost)

    @skip
    def test_gas_remove_unwanted_delegates(self):
        self.file.write("\nRemove Unwanted delegates")
        self.create_test_account(token_contract=self.tokenContract)
        nb_of_users = 15
        self.file.write("\nNb of delegates: %s" % (nb_of_users * nb_of_users + nb_of_users))

        def create_and_delegate(acc_to_delegate):
            acc = WEB3.eth.account.create()
            self.tokenContract.transfer(acc.address, 10 ** 18, private_key=self.private_key)
            send_eth(10 ** 18, acc.address, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY, unit='wei')
            self.delegatesContract.delegate(acc_to_delegate.address, private_key=acc.key)
            self.tokenContract.transfer(self.eth_account.address, 10 ** 18, private_key=acc.key)
            return acc

        for i in range(0, nb_of_users):
            a = create_and_delegate(self.accounts[0])
            for j in range(0, nb_of_users):
                create_and_delegate(a)

        self.fundsManagerContract.proposeTransaction([self.tokenContract.address], [10 ** 18],
                                                     [self.accounts[0].address], [0],
                                                     private_key=self.accounts[0].key)
        increase_time(VOTE_DURATION + 15)

        tx = self.proposalContract.lockVoteCount(self.proposalContract.nextProposalId() - 1)
        gas_cost = tx.receipt.gasUsed
        self.file.write("\nGas cost for lockVoteCount without removing unwanted delegates: %s " % gas_cost)

        (addresses, indexes) = self.delegatesContract.getUnwantedDelegates(self.accounts[0].address)
        addresses = [a for a in addresses if a is not None]
        indexes = indexes[:len(addresses)]
        self.file.write("\nNb of delegates remove: %s " % len(addresses))

        tx = self.delegatesContract.removeUnwantedDelegates(addresses, indexes, private_key=self.private_key)
        gas_cost = tx.receipt.gasUsed
        self.file.write("\nGas cost for removeUnwantedDelegates: %s " % gas_cost)

        self.fundsManagerContract.proposeTransaction([self.tokenContract.address], 10 ** 18,
                                                     self.accounts[0].address,
                                                     private_key=self.accounts[0].key)
        increase_time(VOTE_DURATION + 15)
        tx = self.proposalContract.lockVoteCount(self.proposalContract.nextProposalId() - 1)
        gas_cost = tx.receipt.gasUsed
        self.file.write("\nGas cost for lockVoteCount after removing unwanted delegates: %s " % gas_cost)

    @skip
    def test_check_gas_remove_delegates_process_proposal(self):
        gas_cost = 0
        self.file.write("\nTwo level of delegates ")
        nb_of_delegates = 1
        for i in range(nb_of_delegates):
            account = WEB3.eth.account.create()
            txhash_send_transaction_1 = WEB3.eth.send_transaction(
                {'from': WEB3.eth.accounts[0], 'to': account.address, 'value': WEB3.to_wei(1, "ether")})
            txhash_transfer_token_1 = self.tokenContract.transfer(account.address, 10 ** 18,
                                                                  private_key=self.private_key)
            for j in range(nb_of_delegates):
                account_2 = WEB3.eth.account.create()
                txhash_send_transaction_2 = WEB3.eth.send_transaction(
                    {'from': WEB3.eth.accounts[0], 'to': account_2.address, 'value': WEB3.to_wei(1, "ether")})
                txhash_transfer_token_2 = self.tokenContract.transfer(account_2.address, 10 ** 18,
                                                                      private_key=self.private_key)

                txhash_send_raw_transaction_2 = self.delegatesContract.delegate(account.address,
                                                                                private_key=account_2.key)
                gas_cost += WEB3.eth.get_transaction_receipt(
                    txhash_send_raw_transaction_2).gasUsed + WEB3.eth.get_transaction_receipt(
                    txhash_transfer_token_2).gasUsed + WEB3.eth.get_transaction_receipt(
                    txhash_send_transaction_2).gasUsed

            txhash_send_raw_transaction_1 = self.delegatesContract.delegate(self.eth_account.address,
                                                                            private_key=account.key)
            gas_cost += WEB3.eth.get_transaction_receipt(
                txhash_send_raw_transaction_1).gasUsed + WEB3.eth.get_transaction_receipt(
                txhash_transfer_token_1).gasUsed + WEB3.eth.get_transaction_receipt(
                txhash_send_transaction_1).gasUsed

        self.file.write("\nGas cost for %s delegates %s" % (nb_of_delegates * nb_of_delegates, str(gas_cost)))

        self.file.write("\nAnd Independent voting")

        nb_of_users = 200
        self.file.write("\nNumber of users: %d" % nb_of_users)
        i = 0
        while i < nb_of_users:
            self.create_test_account(token_contract=self.tokenContract, token_amount=1000,
                                     eth_amount=10 ** 19)
            i += 1

        proposal_id = self.proposalContract.nextProposalId()
        address_to = WEB3.eth.account.create()
        self.fundsManagerContract.proposeTransaction([self.tokenContract.address], [10 ** 18],
                                                     [address_to.address], [0],
                                                     private_key=self.private_key)
        i = 0
        while i < nb_of_users:
            self.proposalContract.voteProposalId(proposal_id, True,
                                                 private_key=self.accounts[i].key)
            i += 1
        increase_time(VOTE_DURATION + 15)

        # remove_tx = self.delegatesContract.removeUnwantedDelegates(self.eth_account.address, 0, 1000,
        #                                                            private_key=self.private_key)
        # self.file.write("\nGas cost for removing unwanted delegates " + str(
        #     WEB3.eth.get_transaction_receipt(remove_tx).gasUsed))

        token_balance = self.tokenContract.balanceOf(WEB3.eth.accounts[0])
        eth_balance = WEB3.eth.get_balance(WEB3.eth.accounts[0])
        tx = self.proposalContract.lockVoteCount(proposal_id,
                                                 private_key=self.private_key)
        self.file.write("\nGas cost for lockVote " + str(WEB3.eth.get_transaction_receipt(tx).gasUsed))

        increase_time(BUFFER_BETWEEN_END_OF_VOTING_AND_EXECUTE_PROPOSAL + 15)
        tx = self.fundsManagerContract.executeProposal(proposal_id,
                                                       private_key=self.private_key)
        self.file.write("\nGas cost for executeProposal " + str(WEB3.eth.get_transaction_receipt(tx).gasUsed))

    @skip
    def test_check_gas_multiple_propose_token_transaction(self):

        number_of_transactions = 10
        gas_cost = 0
        amounts = []
        addresses = []
        for i in range(number_of_transactions):
            tr_hash = self.fundsManagerContract.proposeTransaction([self.tokenContract.address], [100],
                                                                   [WEB3.eth.accounts[2]], [0],
                                                                   private_key=self.private_key)
            gas_cost += WEB3.eth.get_transaction(tr_hash).gas
            amounts.append(20)
            addresses.append(WEB3.eth.accounts[2])
        self.file.write("\nGas for calling %s proposeTokenTransaction: %s" % (number_of_transactions, gas_cost))

        tr_hash = self.fundsManagerContract.proposeTransaction([self.tokenContract.address], [amounts],
                                                               [addresses], [0],
                                                               private_key=self.private_key)
        gas_cost = WEB3.eth.get_transaction(tr_hash).gas
        self.file.write("\nGas for calling proposeTokenTransactions(batch): %s" % gas_cost)
        self.file.write("\nNumber of proposals: %s" % self.fundsManagerContract.nextProposalId())

    @skip
    def test_gas_delegate_all_to_one_address(self):
        self.file.write("\nIndependent voting")

        nb_of_users = 1000
        self.file.write("\nNumber of users: %d" % nb_of_users)
        i = 0
        while i < nb_of_users:
            if i == 0:
                self.create_test_account(token_contract=self.tokenContract, token_amount=1000,
                                         eth_amount=10 ** 19)
            else:
                self.create_test_account(token_contract=self.tokenContract, token_amount=1000)
            i += 1

        # i = 1
        # while i < nb_of_users:
        #     self.delegatesContract.delegate(self.accounts[0].address,
        #                                     private_key=self.accounts[i].key)
        #     i += 1

        proposal_id = self.proposalContract.nextProposalId()
        tx = self.tokenSellContract.proposeTokenSell(self.tokenContract.address,
                                                     ZERO_ETH_ADDRESS, 1000, 15, 1,
                                                     10 ** 19,
                                                     private_key=self.accounts[0].key)
        self.file.write("\nGas for proposeTokenSell: %d" % WEB3.eth.get_transaction_receipt(tx).gasUsed)
        i = 1
        while i < nb_of_users:
            self.proposalContract.voteProposalId(proposal_id, True,
                                                 private_key=self.accounts[i].key)
            i += 1

        increase_time(200)
        proposal = Proposals(self.proposalContract, proposal_id)
        self.assertTrue(proposal.votingAllowed)
        token_sell_proposal = TokenSellProposal(self.tokenSellContract, proposal_id)
        self.assertEqual(token_sell_proposal.tokenToSell, self.tokenContract.address)
        self.assertEqual(token_sell_proposal.tokenToBuyWith, None)
        self.assertEqual(token_sell_proposal.duration, 1000)
        self.assertEqual(token_sell_proposal.priceSignificand, 15)
        self.assertEqual(token_sell_proposal.priceExponent, 1)
        self.assertEqual(token_sell_proposal.maxAmount, 10)
        self.assertEqual(token_sell_proposal.canBuy, False)
        self.assertEqual(token_sell_proposal.endTime, 0)

        print('balance: %s' % WEB3.eth.get_balance(self.accounts[0].address))
        tx = self.tokenSellContract.processProposal(proposal_id,
                                                    private_key=self.accounts[0].key,
                                                    expect_success=False)
        gas_cost = WEB3.eth.get_transaction_receipt(tx).gasUsed
        self.file.write("\nGas for calling executeProposal: %s" % gas_cost)
        amount_to_buy = 5 * 10 ** 18
        tx = self.tokenSellContract.buy(proposal_id, amount_to_buy,
                                        private_key=self.accounts[0].key,
                                        wei=7.5 * 10 ** 18,
                                        expect_success=False)
        gas_cost = WEB3.eth.get_transaction_receipt(tx).gasUsed
        self.file.write("\nGas for calling buy: %s" % gas_cost)

    @skip
    def test_gas_for_split_proposals_from_fm_delegate_addresses_to_other_addresses(self):
        self.file.write("\nDelegate addresses to other addresses")
        self.neptuneTokenContract, _ = deploy_test_contract('NeptuneToken',
                                                            private_key=self.private_key,
                                                            allow_cache=True)
        self.fundsManagerContractTokenSell, _ = deploy_test_contract(
            'FundsManagerTokenSell',
            self.neptuneTokenContract.address,
            private_key=self.private_key,
            allow_cache=True)
        self.neptuneTokenContract.createInitialTokens(10 ** 20, 8 * 10 ** 18,
                                                      self.fundsManagerContractTokenSell.address,
                                                      private_key=self.private_key)
        nb_of_users = 100
        self.file.write("\nNumber of users: %d" % nb_of_users)
        i = 0
        while i < nb_of_users:
            if i == 0:
                self.create_test_account(token_contract=self.neptuneTokenContract, token_amount=1000,
                                         eth_amount=10 ** 19)
            else:
                self.create_test_account(token_contract=self.neptuneTokenContract, token_amount=1000,
                                         eth_amount=10 ** 10)
            i += 1

        i = 0
        while i < nb_of_users:
            self.fundsManagerContractTokenSell.delegate(self.accounts[i].address,
                                                        private_key=self.accounts[i + 1].key)
            i += 2

        proposal_id = self.fundsManagerContractTokenSell.nextProposalId()
        self.fundsManagerContractTokenSell.proposeTokenSell(self.neptuneTokenContract.address,
                                                            ZERO_ETH_ADDRESS, 1000, 15, 1,
                                                            10 ** 19,
                                                            private_key=self.accounts[0].key)
        i = 0
        while i < nb_of_users:
            self.fundsManagerContractTokenSell.voteProposalId(proposal_id, True,
                                                              private_key=self.accounts[i].key)
            i += 2

        increase_time(VOTE_DURATION + 15)
        proposal = Proposals(self.fundsManagerContractTokenSell, proposal_id)
        self.assertTrue(proposal.votingAllowed)
        token_sell_proposal = TokenSellProposal(self.fundsManagerContractTokenSell, proposal_id)
        self.assertEqual(token_sell_proposal.tokenToSell, self.neptuneTokenContract.address)
        self.assertEqual(token_sell_proposal.tokenToBuyWith, None)
        self.assertEqual(token_sell_proposal.duration, 1000)
        self.assertEqual(token_sell_proposal.priceSignificand, 15)
        self.assertEqual(token_sell_proposal.priceExponent, 1)
        self.assertEqual(token_sell_proposal.maxAmount, 10 ** 19)
        self.assertEqual(token_sell_proposal.canBuy, False)
        self.assertEqual(token_sell_proposal.endTime, 0)

        tx_hash = self.fundsManagerContractTokenSell.processProposal(proposal_id,
                                                                     private_key=self.accounts[0].key)
        gas_cost = WEB3.eth.get_transaction_receipt(tx_hash).gasUsed
        self.file.write("\nGas for calling executeProposal, no split: %s" % gas_cost)
        amount_to_buy = 5 * 10 ** 18
        tx_hash = self.fundsManagerContractTokenSell.buy(proposal_id, amount_to_buy,
                                                         private_key=self.accounts[0].key,
                                                         wei=7.5 * 10 ** 18,
                                                         expect_success=False)
        gas_cost = WEB3.eth.get_transaction_receipt(tx_hash).gasUsed
        self.file.write("\nGas for calling buy, no split: %s" % gas_cost)

        # now with split contracts
        i = 0
        while i < nb_of_users:
            if i == 0:
                self.create_test_account(token_contract=self.tokenContract, token_amount=1000, eth_amount=10 ** 19)
            else:
                self.create_test_account(token_contract=self.tokenContract, token_amount=1000, eth_amount=10 ** 10)
            i += 1

        i = nb_of_users
        while i < nb_of_users * 2:
            self.delegatesContract.delegate(self.accounts[i].address, private_key=self.accounts[i + 1].key)
            i += 2

        proposal_id = self.proposalContract.nextProposalId()
        self.tokenSellContract.proposeTokenSell(self.tokenContract.address,
                                                ZERO_ETH_ADDRESS, 1000, 15, 1,
                                                10 ** 19,
                                                private_key=self.accounts[100].key)
        increase_time(VOTE_DURATION + 15)
        i = nb_of_users + 1
        while i < nb_of_users * 2:
            self.proposalContract.voteProposalId(proposal_id, True,
                                                 private_key=self.accounts[i].key)
            i += 2

        proposal = Proposals(self.proposalContract, proposal_id)
        self.assertTrue(proposal.votingAllowed)
        token_sell_proposal = TokenSellProposal(self.tokenSellContract, proposal_id)
        self.assertEqual(token_sell_proposal.tokenToSell, self.tokenContract.address)
        self.assertEqual(token_sell_proposal.tokenToBuyWith, None)
        self.assertEqual(token_sell_proposal.duration, 1000)
        self.assertEqual(token_sell_proposal.priceSignificand, 15)
        self.assertEqual(token_sell_proposal.priceExponent, 1)
        self.assertEqual(token_sell_proposal.maxAmount, 10 ** 19)
        self.assertEqual(token_sell_proposal.canBuy, False)
        self.assertEqual(token_sell_proposal.endTime, 0)

        tx_hash = self.tokenSellContract.processProposal(proposal_id,
                                                         private_key=self.private_key)
        gas_cost = WEB3.eth.get_transaction_receipt(tx_hash).gasUsed
        self.file.write("\nGas for calling executeProposal, with split: %s" % gas_cost)
        token_sell_proposal = TokenSellProposal(self.tokenSellContract, proposal_id)
        self.assertEqual(token_sell_proposal.canBuy, True)

        amount_to_buy = 5 * 10 ** 18
        tx_hash = self.tokenSellContract.buy(proposal_id, amount_to_buy, private_key=self.accounts[100].key,
                                             wei=7.5 * 10 ** 18)
        gas_cost = WEB3.eth.get_transaction_receipt(tx_hash).gasUsed
        self.file.write("\nGas for calling buy, with split: %s" % gas_cost)

    @skip
    def test_gas_for_split_proposals_from_fm_all_addresses_vote_independently(self):
        self.file.write("\nNo delegates, all addresses vote independently")
        self.neptuneTokenContract, _ = deploy_test_contract('NeptuneToken', private_key=self.private_key,
                                                            allow_cache=True)
        self.fundsManagerContractTokenSell, _ = deploy_test_contract(
            'FundsManagerTokenSell',
            self.neptuneTokenContract.address,
            private_key=self.private_key,
            allow_cache=True)
        self.neptuneTokenContract.createInitialTokens(10 ** 20, 8 * 10 ** 18,
                                                      self.fundsManagerContractTokenSell.address,
                                                      private_key=self.private_key)
        nb_of_users = 100
        self.file.write("\nNumber of users: %d" % nb_of_users)
        i = 0
        while i < nb_of_users:
            if i == 0:
                self.create_test_account(token_contract=self.neptuneTokenContract, token_amount=1000,
                                         eth_amount=10 ** 20)
            else:
                self.create_test_account(token_contract=self.neptuneTokenContract, token_amount=1000,
                                         eth_amount=10 ** 10)
            i += 1

        # i = 1
        # while i < 100:
        #     self.fundsManagerContractTokenSell.delegate(self.accounts[0].address,
        #                                                 private_key=self.accounts[i].key)
        #     i += 2

        proposal_id = self.fundsManagerContractTokenSell.nextProposalId()
        self.fundsManagerContractTokenSell.proposeTokenSell(self.neptuneTokenContract.address,
                                                            ZERO_ETH_ADDRESS, 1000, 15,
                                                            1,
                                                            10 ** 19,
                                                            private_key=self.accounts[0].key)
        i = 1
        while i < nb_of_users:
            self.fundsManagerContractTokenSell.voteProposalId(proposal_id, True,
                                                              private_key=self.accounts[i].key)
            i += 1

        increase_time(VOTE_DURATION + 15)
        proposal = Proposals(self.fundsManagerContractTokenSell, proposal_id)
        self.assertTrue(proposal.votingAllowed)
        token_sell_proposal = TokenSellProposal(self.fundsManagerContractTokenSell, proposal_id)
        self.assertEqual(token_sell_proposal.tokenToSell, self.neptuneTokenContract.address)
        self.assertEqual(token_sell_proposal.tokenToBuyWith, None)
        self.assertEqual(token_sell_proposal.duration, 1000)
        self.assertEqual(token_sell_proposal.priceSignificand, 15)
        self.assertEqual(token_sell_proposal.priceExponent, 1)
        self.assertEqual(token_sell_proposal.maxAmount, 10 ** 19)
        self.assertEqual(token_sell_proposal.canBuy, False)
        self.assertEqual(token_sell_proposal.endTime, 0)

        tx_hash = self.fundsManagerContractTokenSell.processProposal(proposal_id,
                                                                     private_key=self.accounts[0].key)
        gas_cost = WEB3.eth.get_transaction_receipt(tx_hash).gasUsed
        self.file.write("\nGas for calling executeProposal, no split: %s" % gas_cost)
        amount_to_buy = 5 * 10 ** 18
        tx_hash = self.fundsManagerContractTokenSell.buy(proposal_id, amount_to_buy,
                                                         private_key=self.accounts[0].key,
                                                         wei=7.5 * 10 ** 18)
        gas_cost = WEB3.eth.get_transaction_receipt(tx_hash).gasUsed
        self.file.write("\nGas for calling buy, no split: %s" % gas_cost)

        # now with split contracts
        i = 0
        while i < nb_of_users:
            if i == 0:
                self.create_test_account(token_contract=self.tokenContract, token_amount=1000, eth_amount=10 ** 20)
            else:
                self.create_test_account(token_contract=self.tokenContract, token_amount=1000, eth_amount=10 ** 10)
            i += 1

        # i = 101
        # while i < 200:
        #     self.fundsManagerContract.delegate(self.accounts[100].address, private_key=self.accounts[i].key)
        #     i += 2

        proposal_id = self.proposalContract.nextProposalId()
        self.tokenSellContract.proposeTokenSell(self.tokenContract.address,
                                                ZERO_ETH_ADDRESS, 1000, 15, 1,
                                                10 ** 19,
                                                private_key=self.accounts[100].key)
        increase_time(VOTE_DURATION + 15)
        i = nb_of_users + 1
        while i < nb_of_users * 2:
            self.proposalContract.voteProposalId(proposal_id, True,
                                                 private_key=self.accounts[i].key)
            i += 1

        proposal = Proposals(self.proposalContract, proposal_id)
        self.assertTrue(proposal.votingAllowed)
        token_sell_proposal = TokenSellProposal(self.tokenSellContract, proposal_id)
        self.assertEqual(token_sell_proposal.tokenToSell, self.tokenContract.address)
        self.assertEqual(token_sell_proposal.tokenToBuyWith, None)
        self.assertEqual(token_sell_proposal.duration, 1000)
        self.assertEqual(token_sell_proposal.priceSignificand, 15)
        self.assertEqual(token_sell_proposal.priceExponent, 1)
        self.assertEqual(token_sell_proposal.maxAmount, 10 ** 19)
        self.assertEqual(token_sell_proposal.canBuy, False)
        self.assertEqual(token_sell_proposal.endTime, 0)

        tx_hash = self.tokenSellContract.processProposal(proposal_id,
                                                         private_key=self.private_key)
        gas_cost = WEB3.eth.get_transaction_receipt(tx_hash).gasUsed
        self.file.write("\nGas for calling executeProposal, with split: %s" % gas_cost)
        token_sell_proposal = TokenSellProposal(self.tokenSellContract, proposal_id)
        self.assertEqual(token_sell_proposal.canBuy, True)

        amount_to_buy = 5 * 10 ** 18
        tx_hash = self.tokenSellContract.buy(proposal_id, amount_to_buy, private_key=self.accounts[100].key,
                                             wei=7.5 * 10 ** 18)
        gas_cost = WEB3.eth.get_transaction_receipt(tx_hash).gasUsed
        self.file.write("\nGas for calling buy, with split: %s" % gas_cost)

    @skip
    def test_gas_execute_auction(self):
        start_time = WEB3.eth.get_block('latest')['timestamp'] + 10
        end_time = start_time + 180
        proposal_id = self.proposalContract.nextProposalId()
        self.tokenSellContract.proposeAuctionTokenSell(self.tokenContract.address,
                                                       10 ** 20, 10,
                                                       start_time, end_time,
                                                       private_key=self.private_key)
        self.proposalContract.voteProposalId(proposal_id, True,
                                             private_key=self.private_key)
        increase_time(VOTE_DURATION + 15)
        proposal = Proposals(self.proposalContract, proposal_id)
        self.assertTrue(proposal.votingAllowed)
        token_sell_proposal = AuctionSellProposal(self.tokenSellContract, proposal_id)
        self.assertEqual(token_sell_proposal.tokenToSell, self.tokenContract.address)
        self.assertEqual(token_sell_proposal.totalEthReceived, 0)
        # self.assertEqual(token_sell_proposal.minimumWei, 10 ** 23)
        self.assertEqual(token_sell_proposal.nbOfTokens, 10 ** 2)
        self.assertEqual(token_sell_proposal.startTime, start_time)
        self.assertEqual(token_sell_proposal.endTime, end_time)
        self.assertEqual(token_sell_proposal.canBuy, False)

        self.tokenSellContract.processProposal(proposal_id, private_key=self.private_key)
        token_sell_proposal = AuctionSellProposal(self.tokenSellContract, proposal_id)
        self.assertEqual(token_sell_proposal.canBuy, True)
        buyers = 10
        gas_cost = 0
        for i in range(0, buyers):
            self.create_test_account(self.tokenContract, token_amount=0)
            tx = self.tokenSellContract.buyAuction(proposal_id, private_key=self.accounts[i].key,
                                                   wei=10 ** 18)
            receipt = WEB3.eth.get_transaction_receipt(tx)
            gas_cost += int(receipt.gasUsed)
        self.file.write("\nAverage Gas for calling buyAuction: %s" % (gas_cost / buyers))
        increase_time(180)
        total_gas_cost = 0
        last_call_cost = 0
        for i in range(0, buyers):
            tx = self.tokenSellContract.claimAuction(proposal_id, private_key=self.accounts[i].key)
            receipt = WEB3.eth.get_transaction_receipt(tx)
            total_gas_cost += receipt.gasUsed
            if i == buyers - 1:
                last_call_cost = receipt.gasUsed
        self.file.write("\nTotal Gas for calling claimAuction with %s buyers: %s" % (buyers, total_gas_cost))
        self.file.write("\nAverage Gas for calling claimAuction: %s" % (total_gas_cost / buyers))
        self.file.write("\nGas for calling last claimAuction: %s" % last_call_cost)

        # print(self.tokenSellContract.buyersLength(proposal_id))
        # tx = self.tokenSellContract.executeAuction(proposal_id, private_key=self.private_key)
        # receipt = WEB3.eth.get_transaction_receipt(tx)
        # gas_cost = receipt.gasUsed
        # self.file.write("\nGas for calling executeAuction with %s buyers: %s" % (buyers, gas_cost))

        # for i in range(0, buyers):
        #     self.assertEqual(self.tokenContract.balanceOf(self.accounts[i].address), (Decimal(10**20)/buyers).to_integral_exact(rounding=ROUND_FLOOR))

    def test_payroll_gas(self):
        self.create_test_account(token_contract=self.tokenContract)
        self.create_test_account(token_contract=self.tokenContract)
        self.file.write("\nTest payroll gas")
        gas_cost = 0
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        transaction = self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [100],
                                                                   [self.accounts[0].address], [0],
                                                                   private_key=self.private_key)
        gas_cost += WEB3.eth.get_transaction_receipt(transaction).gasUsed
        self.file.write("\n Gas for 1 payment payroll")
        self.file.write("\n Gas for calling proposeTransaction: %s" % gas_cost)

        increase_time(VOTE_DURATION + 15)
        transaction = self.proposalContract.lockVoteCount(GS_PROJECT_ID, proposal_id, private_key=self.private_key)
        gas_cost += WEB3.eth.get_transaction_receipt(transaction).gasUsed
        self.file.write("\n Gas for calling lockVoteCount: %s" % WEB3.eth.get_transaction_receipt(transaction).gasUsed)

        increase_time(BUFFER_BETWEEN_END_OF_VOTING_AND_EXECUTE_PROPOSAL + 15)
        transaction = self.fundsManagerContract.executeProposal(GS_PROJECT_ID, proposal_id,
                                                                private_key=self.private_key)
        gas_cost += WEB3.eth.get_transaction_receipt(transaction).gasUsed
        self.file.write("\n Gas for calling executeProposal: %s" % WEB3.eth.get_transaction_receipt(transaction).gasUsed)
        self.file.write("\n Total: %s" % gas_cost)

        gas_cost = 0
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        transaction = self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address],
                                                                   [100, 50, 150, 1, 2],
                                                                   [self.accounts[0].address, self.accounts[1].address,
                                                                    self.accounts[0].address, self.accounts[1].address,
                                                                    self.accounts[0].address],
                                                                   [0, 0, 0, 0, 0],
                                                                   private_key=self.private_key)
        gas_cost += WEB3.eth.get_transaction_receipt(transaction).gasUsed
        self.file.write("\n Gas for 5 payments payroll")
        self.file.write("\n Gas for calling proposeTransaction: %s" % gas_cost)

        increase_time(VOTE_DURATION + 15)
        transaction = self.proposalContract.lockVoteCount(GS_PROJECT_ID, proposal_id, private_key=self.private_key)
        gas_cost += WEB3.eth.get_transaction_receipt(transaction).gasUsed
        self.file.write("\n Gas for calling lockVoteCount: %s" % WEB3.eth.get_transaction_receipt(transaction).gasUsed)

        increase_time(BUFFER_BETWEEN_END_OF_VOTING_AND_EXECUTE_PROPOSAL + 15)
        transaction = self.fundsManagerContract.executeProposal(GS_PROJECT_ID, proposal_id,
                                                                private_key=self.private_key)
        gas_cost += WEB3.eth.get_transaction_receipt(transaction).gasUsed
        self.file.write("\n Gas for calling executeProposal: %s" % WEB3.eth.get_transaction_receipt(transaction).gasUsed)
        self.file.write("\n Total: %s" % gas_cost)

        gas_cost = 0
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        transaction = self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address
                                                                                   ],
                                                                   [100, 50, 150, 1, 2, 100, 50, 150, 1, 2],
                                                                   [self.accounts[0].address, self.accounts[1].address,
                                                                    self.accounts[0].address, self.accounts[1].address,
                                                                    self.accounts[0].address, self.accounts[0].address,
                                                                    self.accounts[1].address,
                                                                    self.accounts[0].address, self.accounts[1].address,
                                                                    self.accounts[0].address],
                                                                   [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                                                                   private_key=self.private_key)
        gas_cost += WEB3.eth.get_transaction_receipt(transaction).gasUsed
        self.file.write("\n Gas for 10 payments payroll")
        self.file.write("\n Gas for calling proposeTransaction: %s" % gas_cost)

        increase_time(VOTE_DURATION + 15)
        transaction = self.proposalContract.lockVoteCount(GS_PROJECT_ID, proposal_id)
        gas_cost += WEB3.eth.get_transaction_receipt(transaction).gasUsed
        self.file.write("\n Gas for calling lockVoteCount: %s" % WEB3.eth.get_transaction_receipt(transaction).gasUsed)

        increase_time(BUFFER_BETWEEN_END_OF_VOTING_AND_EXECUTE_PROPOSAL + 15)
        transaction = self.fundsManagerContract.executeProposal(GS_PROJECT_ID, proposal_id,
                                                                private_key=self.private_key)
        gas_cost += WEB3.eth.get_transaction_receipt(transaction).gasUsed
        self.file.write("\n Gas for calling executeProposal: %s" % WEB3.eth.get_transaction_receipt(transaction).gasUsed)
        self.file.write("\n Total: %s" % gas_cost)

        gas_cost = 0
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        transaction = self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address
                                                                                   ],
                                                                   [100, 50, 150, 1, 2, 100, 50, 150, 1, 2, 100, 50,
                                                                    150, 1, 2],
                                                                   [self.accounts[0].address, self.accounts[1].address,
                                                                    self.accounts[0].address, self.accounts[1].address,
                                                                    self.accounts[0].address, self.accounts[0].address,
                                                                    self.accounts[1].address,
                                                                    self.accounts[0].address, self.accounts[1].address,
                                                                    self.accounts[0].address, self.accounts[0].address,
                                                                    self.accounts[1].address,
                                                                    self.accounts[0].address, self.accounts[1].address,
                                                                    self.accounts[0].address],
                                                                   [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                                                                   private_key=self.private_key)
        gas_cost += WEB3.eth.get_transaction_receipt(transaction).gasUsed
        self.file.write("\n Gas for 15 payments payroll")
        self.file.write("\n Gas for calling proposeTransaction: %s" % gas_cost)

        increase_time(VOTE_DURATION + 15)
        transaction = self.proposalContract.lockVoteCount(GS_PROJECT_ID, proposal_id)
        gas_cost += WEB3.eth.get_transaction_receipt(transaction).gasUsed
        self.file.write("\n Gas for calling lockVoteCount: %s" % WEB3.eth.get_transaction_receipt(transaction).gasUsed)

        increase_time(BUFFER_BETWEEN_END_OF_VOTING_AND_EXECUTE_PROPOSAL + 15)
        transaction = self.fundsManagerContract.executeProposal(GS_PROJECT_ID, proposal_id,
                                                                private_key=self.private_key)
        gas_cost += WEB3.eth.get_transaction_receipt(transaction).gasUsed
        self.file.write("\n Gas for calling executeProposal: %s" % WEB3.eth.get_transaction_receipt(transaction).gasUsed)
        self.file.write("\n Total: %s" % gas_cost)

        gas_cost = 0
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        transaction = self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address,
                                                                                   self.tokenContract.address
                                                                                   ],
                                                                   [100, 50, 150, 1, 2, 100, 50, 150, 1, 2, 100, 50,
                                                                    150, 1, 2, 100, 50,
                                                                    150, 1, 2],
                                                                   [self.accounts[0].address, self.accounts[1].address,
                                                                    self.accounts[0].address, self.accounts[1].address,
                                                                    self.accounts[0].address, self.accounts[0].address,
                                                                    self.accounts[1].address,
                                                                    self.accounts[0].address, self.accounts[1].address,
                                                                    self.accounts[0].address, self.accounts[0].address,
                                                                    self.accounts[1].address,
                                                                    self.accounts[0].address, self.accounts[1].address,
                                                                    self.accounts[0].address, self.accounts[0].address,
                                                                    self.accounts[1].address,
                                                                    self.accounts[0].address, self.accounts[1].address,
                                                                    self.accounts[0].address],
                                                                   [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                                                                    0, 0, 0],
                                                                   private_key=self.private_key)
        gas_cost += WEB3.eth.get_transaction_receipt(transaction).gasUsed
        self.file.write("\n Gas for 20 payments payroll")
        self.file.write("\n Gas for calling proposeTransaction: %s" % gas_cost)

        increase_time(VOTE_DURATION + 15)
        transaction = self.proposalContract.lockVoteCount(GS_PROJECT_ID, proposal_id)
        gas_cost += WEB3.eth.get_transaction_receipt(transaction).gasUsed
        self.file.write("\n Gas for calling lockVoteCount: %s" % WEB3.eth.get_transaction_receipt(transaction).gasUsed)

        increase_time(BUFFER_BETWEEN_END_OF_VOTING_AND_EXECUTE_PROPOSAL + 15)
        transaction = self.fundsManagerContract.executeProposal(GS_PROJECT_ID, proposal_id,
                                                                private_key=self.private_key)
        gas_cost += WEB3.eth.get_transaction_receipt(transaction).gasUsed
        self.file.write("\n Gas for calling executeProposal: %s" % WEB3.eth.get_transaction_receipt(transaction).gasUsed)
        self.file.write("\n Total: %s" % gas_cost)

        gas_cost = 0
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        token_contract_array = [self.tokenContract.address] * 60
        amount_array = [100, 50, 150, 1, 2] * 12
        address_array = [self.accounts[0].address, self.accounts[1].address] * 30
        project_ids = [0] * 60
        transaction = self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, token_contract_array,
                                                                   amount_array,
                                                                   address_array,
                                                                   project_ids,
                                                                   private_key=self.private_key)
        gas_cost += WEB3.eth.get_transaction_receipt(transaction).gasUsed
        self.file.write("\n Gas for 60 payments payroll")
        self.file.write("\n Gas for calling proposeTransaction: %s" % gas_cost)

        increase_time(VOTE_DURATION + 15)
        transaction = self.proposalContract.lockVoteCount(GS_PROJECT_ID, proposal_id)
        gas_cost += WEB3.eth.get_transaction_receipt(transaction).gasUsed
        self.file.write("\n Gas for calling lockVoteCount: %s" % WEB3.eth.get_transaction_receipt(transaction).gasUsed)

        increase_time(BUFFER_BETWEEN_END_OF_VOTING_AND_EXECUTE_PROPOSAL + 15)
        transaction = self.fundsManagerContract.executeProposal(GS_PROJECT_ID, proposal_id,
                                                                private_key=self.private_key)
        gas_cost += WEB3.eth.get_transaction_receipt(transaction).gasUsed
        self.file.write("\n Gas for calling executeProposal: %s" % WEB3.eth.get_transaction_receipt(transaction).gasUsed)
        self.file.write("\n Total: %s" % gas_cost)
