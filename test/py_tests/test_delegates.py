from unittest import skip

from test.py_tests.tests import EthBaseTest
from utils import WEB3, ZERO_ETH_ADDRESS, GS_PROJECT_ID


class DelegatesTests(EthBaseTest):

    def setUp(self):
        super().setUp()
        self.create_test_account()
        self.create_test_account()
        self.create_test_account()
        self.create_test_account()
        self.create_test_account(token_amount=10)

    def test_delegate_vote(self):
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[1].address,
                                        private_key=self.accounts[0].key)
        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[0].address),
                         self.accounts[1].address)
        self.assertEqual(self.delegatesContract.delegations(GS_PROJECT_ID, self.accounts[1].address, 0),
                         self.accounts[0].address)

    def test_delegate_vote_with_insufficient_balance(self):
        try:
            self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[1].address, private_key=self.accounts[4].key)
            self.fail()
        except Exception as e:
            self.assertIn("Not enough voting power.", str(e))

    def test_delegate_vote_to_self(self):
        try:
            self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[0].address, private_key=self.accounts[0].key)
            self.fail()
        except Exception as e:
            self.assertIn("Can't delegate to yourself", str(e))

    def test_undelegate_vote(self):
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[1].address, private_key=self.accounts[0].key)
        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[0].address),
                         self.accounts[1].address)

        self.delegatesContract.undelegate(GS_PROJECT_ID, private_key=self.accounts[0].key)
        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[0].address), ZERO_ETH_ADDRESS)
        try:
            self.delegatesContract.delegations(GS_PROJECT_ID, self.accounts[1].address, 0)
            self.fail()
        except Exception as e:
            self.assertIn("execution reverted", str(e))

    def test_delegate_vote_to_an_address_and_than_to_another(self):
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[1].address, private_key=self.accounts[0].key)
        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[0].address),
                         self.accounts[1].address)

        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[2].address, private_key=self.accounts[0].key)
        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[0].address),
                         self.accounts[2].address)
        self.assertEqual(self.delegatesContract.delegations(GS_PROJECT_ID, self.accounts[2].address, 0),
                         self.accounts[0].address)

    def test_delegate_vote_to_an_address_that_already_delegated_to_another(self):
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[2].address, private_key=self.accounts[1].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[1].address, private_key=self.accounts[0].key)
        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[0].address),
                         self.accounts[1].address)
        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[1].address),
                         self.accounts[2].address)
        self.assertEqual(self.delegatesContract.delegations(GS_PROJECT_ID, self.accounts[1].address, 0),
                         self.accounts[0].address)
        self.assertEqual(self.delegatesContract.delegations(GS_PROJECT_ID, self.accounts[2].address, 0),
                         self.accounts[1].address)

    def test_delegate_addresses_undelegate_one_of_them_and_delegate_back(self):
        print(f"delegator address: {self.accounts[0].address}")
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[3].address, private_key=self.accounts[0].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[3].address, private_key=self.accounts[1].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[3].address, private_key=self.accounts[2].key)

        self.assertEqual(self.delegatesContract.delegations(GS_PROJECT_ID, self.accounts[3].address, 0),
                         self.accounts[0].address)
        self.assertEqual(self.delegatesContract.delegations(GS_PROJECT_ID, self.accounts[3].address, 1),
                         self.accounts[1].address)
        self.assertEqual(self.delegatesContract.delegations(GS_PROJECT_ID, self.accounts[3].address, 2),
                         self.accounts[2].address)

        self.delegatesContract.undelegate(GS_PROJECT_ID, private_key=self.accounts[1].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[3].address, private_key=self.accounts[1].key)

        self.assertEqual(self.delegatesContract.delegations(GS_PROJECT_ID, self.accounts[3].address, 0),
                         self.accounts[0].address)
        self.assertEqual(self.delegatesContract.delegations(GS_PROJECT_ID, self.accounts[3].address, 1),
                         self.accounts[2].address)
        self.assertEqual(self.delegatesContract.delegations(GS_PROJECT_ID, self.accounts[3].address, 2),
                         self.accounts[1].address)

    def test_undelegate_all_from_address(self):
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[3].address, private_key=self.accounts[0].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[3].address, private_key=self.accounts[1].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[3].address, private_key=self.accounts[2].key)

        self.delegatesContract.undelegateAllFromAddress(GS_PROJECT_ID, private_key=self.accounts[3].key)

        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[0].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[1].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[2].address), ZERO_ETH_ADDRESS)

        try:
            self.delegatesContract.delegations(GS_PROJECT_ID, self.accounts[3].address, 0)
            self.fail()
        except Exception as e:
            self.assertIn("execution reverted", str(e))

    def test_undelegate_all_from_address_and_delegate_back(self):
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[3].address, private_key=self.accounts[0].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[3].address, private_key=self.accounts[1].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[3].address, private_key=self.accounts[2].key)

        self.delegatesContract.undelegateAllFromAddress(GS_PROJECT_ID, private_key=self.accounts[3].key)

        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[3].address, private_key=self.accounts[0].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[3].address, private_key=self.accounts[1].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[3].address, private_key=self.accounts[2].key)

        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[0].address),
                         self.accounts[3].address)
        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[1].address),
                         self.accounts[3].address)
        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[2].address),
                         self.accounts[3].address)

        self.assertEqual(self.delegatesContract.delegations(GS_PROJECT_ID, self.accounts[3].address, 0),
                         self.accounts[0].address)
        self.assertEqual(self.delegatesContract.delegations(GS_PROJECT_ID, self.accounts[3].address, 1),
                         self.accounts[1].address)
        self.assertEqual(self.delegatesContract.delegations(GS_PROJECT_ID, self.accounts[3].address, 2),
                         self.accounts[2].address)

    def test_delegate_a_delegated_address_to_one_of_its_delegators(self):
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[3].address, private_key=self.accounts[0].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[3].address, private_key=self.accounts[1].key)

        try:
            self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[0].address, private_key=self.accounts[3].key)
            self.fail()
        except Exception as e:
            self.assertIn("Can't delegate to yourself", str(e))

    @skip
    def test_remove_unwanted_delegates(self):
        nb_of_users = 3
        for i in range(GS_PROJECT_ID, nb_of_users):
            acc1 = WEB3.eth.account.create()
            self.tokenContract.transfer(acc1.address, 10**18, private_key=self.private_key)
            WEB3.eth.send_transaction({'from': self._buffer_account, 'to': acc1.address, 'value': 10**18})
            self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[0].address, private_key=acc1.key)
            self.tokenContract.transfer(self.eth_account.address, 10**18, private_key=acc1.key)

        #     for j in range(GS_PROJECT_ID, nb_of_users):
        #         acc2 = WEB3.eth.account.create()
        #         self.tokenContract.transfer(acc2.address, 10 ** 18, private_key=self.private_key)
        #         WEB3.eth.send_transaction({'from': self._buffer_account, 'to': acc2.address, 'value': 10 ** 18})
        #         self.delegatesContract.delegate(GS_PROJECT_ID, acc1.address, private_key=acc2.key)
        #         self.tokenContract.transfer(self.eth_account.address, 10 ** 18, private_key=acc2.key)

        for i in range(9):
            self.create_test_account(token_contract=self.tokenContract)

        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[0].address, private_key=self.accounts[1].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[0].address, private_key=self.accounts[2].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[0].address, private_key=self.accounts[3].key)

        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[1].address, private_key=self.accounts[5].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[1].address, private_key=self.accounts[6].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[1].address, private_key=self.accounts[7].key)

        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[2].address, private_key=self.accounts[8].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[2].address, private_key=self.accounts[9].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[2].address, private_key=self.accounts[10].key)

        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[3].address, private_key=self.accounts[11].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[3].address, private_key=self.accounts[12].key)
        self.delegatesContract.delegate(GS_PROJECT_ID, self.accounts[3].address, private_key=self.accounts[13].key)

        for i in range(1, 13):
            self.tokenContract.transfer(self.eth_account.address,
                                        self.tokenContract.balanceOf(self.accounts[i].address),
                                        private_key=self.accounts[i].key)

        (addresses, indexes) = self.delegatesContract.getSpamDelegates(GS_PROJECT_ID, self.accounts[0].address)

        self.delegatesContract.removeSpamDelegates (GS_PROJECT_ID, addresses[:10], indexes[:10],
                                                       private_key=self.private_key)

        self.assertEqual(self.delegatesContract.delegations(GS_PROJECT_ID, self.accounts[0].address, 0),
                         self.accounts[3].address)
        self.assertEqual(self.delegatesContract.delegations(GS_PROJECT_ID, self.accounts[3].address, 0),
                         self.accounts[13].address)
        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[2].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[5].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[6].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[7].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[8].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[9].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[10].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[11].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[12].address), ZERO_ETH_ADDRESS)
        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[3].address),
                         self.accounts[0].address)
        self.assertEqual(self.delegatesContract.delegateOf(GS_PROJECT_ID, self.accounts[13].address),
                         self.accounts[3].address)
