from unittest import skip

from brownie import accounts

from test.py_tests.tests import EthBaseTest
from utils import ZERO_ETH_ADDRESS


class DelegatesTests(EthBaseTest):

    def setUp(self):
        super().setUp()
        self.create_test_account()
        self.create_test_account()
        self.create_test_account()
        self.create_test_account()
        self.create_test_account(token_amount=10)

    def test_delegate_vote(self):
        self.delegatesContract.delegate(self.p_id, self.accounts[1].address,
                                        private_key=self.accounts[0].private_key)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[0].address),
                         self.accounts[1].address)
        self.assertEqual(self.delegatesContract.delegations(self.p_id, self.accounts[1].address, 0),
                         self.accounts[0].address)

    def test_delegate_vote_with_insufficient_balance(self):
        try:
            self.delegatesContract.delegate(self.p_id, self.accounts[1].address, private_key=self.accounts[4].private_key)
            self.fail()
        except Exception as e:
            self.assertIn("Not enough voting power.", str(e))

    def test_delegate_vote_to_self(self):
        try:
            self.delegatesContract.delegate(self.p_id, self.accounts[0].address, private_key=self.accounts[0].private_key)
            self.fail()
        except Exception as e:
            self.assertIn("Can't delegate to yourself", str(e))

    def test_undelegate_vote(self):
        self.delegatesContract.delegate(self.p_id, self.accounts[1].address, private_key=self.accounts[0].private_key)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[0].address),
                         self.accounts[1].address)

        self.delegatesContract.undelegate(self.p_id, private_key=self.accounts[0].private_key)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[0].address), ZERO_ETH_ADDRESS)
        try:
            self.delegatesContract.delegations(self.p_id, self.accounts[1].address, 0)
            self.fail()
        except Exception as e:
            self.assertIn("Transaction reverted", str(e))

    def test_delegate_vote_to_an_address_and_than_to_another(self):
        self.delegatesContract.delegate(self.p_id, self.accounts[1].address, private_key=self.accounts[0].private_key)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[0].address),
                         self.accounts[1].address)

        self.delegatesContract.delegate(self.p_id, self.accounts[2].address, private_key=self.accounts[0].private_key)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[0].address),
                         self.accounts[2].address)
        self.assertEqual(self.delegatesContract.delegations(self.p_id, self.accounts[2].address, 0),
                         self.accounts[0].address)

    def test_delegate_vote_to_an_address_that_already_delegated_to_another(self):
        self.delegatesContract.delegate(self.p_id, self.accounts[2].address, private_key=self.accounts[1].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[1].address, private_key=self.accounts[0].private_key)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[0].address),
                         self.accounts[1].address)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[1].address),
                         self.accounts[2].address)
        self.assertEqual(self.delegatesContract.delegations(self.p_id, self.accounts[1].address, 0),
                         self.accounts[0].address)
        self.assertEqual(self.delegatesContract.delegations(self.p_id, self.accounts[2].address, 0),
                         self.accounts[1].address)

    def test_delegate_addresses_undelegate_one_of_them_and_delegate_back(self):
        print(f"delegator address: {self.accounts[0].address}")
        self.delegatesContract.delegate(self.p_id, self.accounts[3].address, private_key=self.accounts[0].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[3].address, private_key=self.accounts[1].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[3].address, private_key=self.accounts[2].private_key)

        self.assertEqual(self.delegatesContract.delegations(self.p_id, self.accounts[3].address, 0),
                         self.accounts[0].address)
        self.assertEqual(self.delegatesContract.delegations(self.p_id, self.accounts[3].address, 1),
                         self.accounts[1].address)
        self.assertEqual(self.delegatesContract.delegations(self.p_id, self.accounts[3].address, 2),
                         self.accounts[2].address)

        self.delegatesContract.undelegate(self.p_id, private_key=self.accounts[1].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[3].address, private_key=self.accounts[1].private_key)

        self.assertEqual(self.delegatesContract.delegations(self.p_id, self.accounts[3].address, 0),
                         self.accounts[0].address)
        self.assertEqual(self.delegatesContract.delegations(self.p_id, self.accounts[3].address, 1),
                         self.accounts[2].address)
        self.assertEqual(self.delegatesContract.delegations(self.p_id, self.accounts[3].address, 2),
                         self.accounts[1].address)

    def test_undelegate_all_from_address(self):
        self.delegatesContract.delegate(self.p_id, self.accounts[3].address, private_key=self.accounts[0].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[3].address, private_key=self.accounts[1].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[3].address, private_key=self.accounts[2].private_key)

        self.delegatesContract.undelegateAllFromAddress(self.p_id, private_key=self.accounts[3].private_key)

        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[0].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[1].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[2].address), ZERO_ETH_ADDRESS)

        try:
            self.delegatesContract.delegations(self.p_id, self.accounts[3].address, 0)
            self.fail()
        except Exception as e:
            self.assertIn("Transaction reverted", str(e))

    def test_undelegate_all_from_address_and_delegate_back(self):
        self.delegatesContract.delegate(self.p_id, self.accounts[3].address, private_key=self.accounts[0].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[3].address, private_key=self.accounts[1].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[3].address, private_key=self.accounts[2].private_key)

        self.delegatesContract.undelegateAllFromAddress(self.p_id, private_key=self.accounts[3].private_key)

        self.delegatesContract.delegate(self.p_id, self.accounts[3].address, private_key=self.accounts[0].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[3].address, private_key=self.accounts[1].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[3].address, private_key=self.accounts[2].private_key)

        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[0].address),
                         self.accounts[3].address)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[1].address),
                         self.accounts[3].address)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[2].address),
                         self.accounts[3].address)

        self.assertEqual(self.delegatesContract.delegations(self.p_id, self.accounts[3].address, 0),
                         self.accounts[0].address)
        self.assertEqual(self.delegatesContract.delegations(self.p_id, self.accounts[3].address, 1),
                         self.accounts[1].address)
        self.assertEqual(self.delegatesContract.delegations(self.p_id, self.accounts[3].address, 2),
                         self.accounts[2].address)

    def test_delegate_a_delegated_address_to_one_of_its_delegators(self):
        self.delegatesContract.delegate(self.p_id, self.accounts[3].address, private_key=self.accounts[0].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[3].address, private_key=self.accounts[1].private_key)

        try:
            self.delegatesContract.delegate(self.p_id, self.accounts[0].address, private_key=self.accounts[3].private_key)
            self.fail()
        except Exception as e:
            self.assertIn("Can't delegate to yourself", str(e))

    @skip
    def test_remove_unwanted_delegates(self):
        nb_of_users = 3
        for i in range(self.p_id, nb_of_users):
            acc1 = accounts.add()
            self.tokenContract.transfer(acc1.address, 10**18, private_key=self.private_key)
            self._buffer_account.transfer(acc1.address, 10**18, {'from': self.eth_account})
            self.delegatesContract.delegate(self.p_id, self.accounts[0].address, private_key=acc1.private_key)
            self.tokenContract.transfer(self.eth_account.address, 10**18, private_key=acc1.private_key)

        #     for j in range(self.p_id, nb_of_users):
        #         acc2 = accounts.add()
        #         self.tokenContract.transfer(acc2.address, 10 ** 18, private_key=self.private_key)
        #         Web3.eth.send_transaction({'from': self._buffer_account, 'to': acc2.address, 'value': 10 ** 18})
        #         self.delegatesContract.delegate(self.p_id, acc1.address, private_key=acc2.private_key)
        #         self.tokenContract.transfer(self.eth_account.address, 10 ** 18, private_key=acc2.private_key)

        for i in range(9):
            self.create_test_account(token_contract=self.tokenContract)

        self.delegatesContract.delegate(self.p_id, self.accounts[0].address, private_key=self.accounts[1].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[0].address, private_key=self.accounts[2].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[0].address, private_key=self.accounts[3].private_key)

        self.delegatesContract.delegate(self.p_id, self.accounts[1].address, private_key=self.accounts[5].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[1].address, private_key=self.accounts[6].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[1].address, private_key=self.accounts[7].private_key)

        self.delegatesContract.delegate(self.p_id, self.accounts[2].address, private_key=self.accounts[8].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[2].address, private_key=self.accounts[9].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[2].address, private_key=self.accounts[10].private_key)

        self.delegatesContract.delegate(self.p_id, self.accounts[3].address, private_key=self.accounts[11].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[3].address, private_key=self.accounts[12].private_key)
        self.delegatesContract.delegate(self.p_id, self.accounts[3].address, private_key=self.accounts[13].private_key)

        for i in range(1, 13):
            self.tokenContract.transfer(self.eth_account.address,
                                        self.tokenContract.balanceOf(self.accounts[i].address),
                                        private_key=self.accounts[i].private_key)

        (addresses, indexes) = self.delegatesContract.getSpamDelegates(self.p_id, self.accounts[0].address)

        self.delegatesContract.removeSpamDelegates (self.p_id, addresses[:10], indexes[:10],
                                                       private_key=self.private_key)

        self.assertEqual(self.delegatesContract.delegations(self.p_id, self.accounts[0].address, 0),
                         self.accounts[3].address)
        self.assertEqual(self.delegatesContract.delegations(self.p_id, self.accounts[3].address, 0),
                         self.accounts[13].address)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[2].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[5].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[6].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[7].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[8].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[9].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[10].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[11].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[12].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[3].address),
                         self.accounts[0].address)
        self.assertEqual(self.delegatesContract.delegateOf(self.p_id, self.accounts[13].address),
                         self.accounts[3].address)
