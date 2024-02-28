from test.py_tests.tests import EthBaseTest
from utils import WEB3, deploy_test_contract, Defaults, deploy_contract_version_and_wait, GS_PROJECT_ID, \
    INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY


class ReclaimFundsTests(EthBaseTest):
    DECIMALS = 10 ** 18

    def setUp(self):
        super().setUp()
        self.neptune_token_contract, neptune_token_tx_hash = deploy_contract_version_and_wait('Token', 'latest',
                                                                                              'PROJ_DB_ID',
                                                                                              10000 * self.DECIMALS,
                                                                                              1000 * self.DECIMALS,
                                                                                              self.contractsManagerContract.address,
                                                                                              self.fundsManagerContract.address,
                                                                                              self.proposalContract.address,
                                                                                              'Neptune', 'NP',
                                                                                              private_key=self.private_key,
                                                                                              allow_cache=True)

        self.saturn_token_contract, saturn_token_tx_hash = deploy_contract_version_and_wait('Token', 'latest',
                                                                                            'PROJ_DB_ID2',
                                                                                            10000 * self.DECIMALS,
                                                                                            1000 * self.DECIMALS,
                                                                                            self.contractsManagerContract.address,
                                                                                            self.fundsManagerContract.address,
                                                                                            self.proposalContract.address,
                                                                                            'Saturn', 'ST',
                                                                                            private_key=self.private_key,
                                                                                            allow_cache=True)

        self.create_test_account()
        self.create_test_account(token_amount=75 * self.DECIMALS)

    def test_reclaim_funds(self):
        self.neptune_token_contract.approve(self.fundsManagerContract.address, 100 * self.DECIMALS,
                                            private_key=self.private_key)
        self.fundsManagerContract.depositToken(GS_PROJECT_ID, self.neptune_token_contract.address, 100 * self.DECIMALS)
        self.assertEqual(self.fundsManagerContract.balances(GS_PROJECT_ID, self.neptune_token_contract.address),
                         100 * self.DECIMALS)
        self.saturn_token_contract.approve(self.fundsManagerContract.address, 200 * self.DECIMALS,
                                           private_key=self.private_key)
        self.fundsManagerContract.depositToken(GS_PROJECT_ID, self.saturn_token_contract.address, 200 * self.DECIMALS)

        self.fundsManagerContract.depositEth(GS_PROJECT_ID, private_key=INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY,
                                             wei=1 * 10 ** 18)
        self.tokenContract.approve(self.fundsManagerContract.address, 50 * self.DECIMALS,
                                   private_key=self.accounts[1].key)

        eth_balance_before = WEB3.eth.get_balance(self.accounts[1].address)

        tokenContractsAddresses = [self.neptune_token_contract.address, self.saturn_token_contract.address]

        tx = self.fundsManagerContract.reclaimFunds(GS_PROJECT_ID, 50 * self.DECIMALS, tokenContractsAddresses,
                                                    private_key=self.accounts[1].key)

        gas_used = WEB3.eth.get_transaction_receipt(tx).gasUsed

        eth_balance_after = WEB3.eth.get_balance(self.accounts[1].address)

        self.assertEqual(gas_used * Defaults.gas_price + eth_balance_after - eth_balance_before, 50 * 10 ** 16)
        self.assertEqual(WEB3.eth.get_balance(self.fundsManagerContract.address), 50 * 10 ** 16)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[1].address), 25 * self.DECIMALS)
        self.assertEqual(self.neptune_token_contract.balanceOf(self.accounts[1].address), 50 * self.DECIMALS)
        self.assertEqual(self.saturn_token_contract.balanceOf(self.accounts[1].address), 100 * self.DECIMALS)

    def test_reclaim_funds_with_0_balance(self):
        self.neptune_token_contract.transfer(self.fundsManagerContract.address, 100 * self.DECIMALS,
                                             private_key=self.private_key)
        self.saturn_token_contract.transfer(self.fundsManagerContract.address, 200 * self.DECIMALS,
                                            private_key=self.private_key)

        self.tokenContract.transfer(self.fundsManagerContract.address, 75 * self.DECIMALS,
                                    private_key=self.accounts[1].key)

        eth_balance_before = WEB3.eth.get_balance(self.accounts[1].address)

        token_contracts_addresses = [self.neptune_token_contract.address, self.saturn_token_contract.address]
        self.tokenContract.approve(self.fundsManagerContract.address, 20000 * self.DECIMALS,
                                   private_key=self.accounts[1].key)
        funds_manager_balance = self.tokenContract.balanceOf(self.fundsManagerContract.address)
        try:
            self.fundsManagerContract.reclaimFunds(GS_PROJECT_ID, 50 * self.DECIMALS, token_contracts_addresses,
                                                   private_key=self.accounts[1].key)
            self.fail()
        except Exception as e:
            self.assertIn("insufficient balance", str(e))

        self.assertTrue(WEB3.eth.get_balance(self.accounts[1].address) <= eth_balance_before)
        self.assertEqual(self.tokenContract.balanceOf(self.fundsManagerContract.address), funds_manager_balance)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[1].address), 0)
        self.assertEqual(self.neptune_token_contract.balanceOf(self.accounts[1].address), 0)
        self.assertEqual(self.saturn_token_contract.balanceOf(self.accounts[1].address), 0)

    def test_reclaim_funds_for_token_contracts_for_which_fm_has_no_balance(self):
        self.fundsManagerContract.depositEth(GS_PROJECT_ID, private_key=INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY,
                                             wei=1 * 10 ** 18)

        tokenContractsAddresses = [self.neptune_token_contract.address, self.saturn_token_contract.address]
        eth_balance_before = WEB3.eth.get_balance(self.accounts[1].address)

        funds_manager_balance = self.tokenContract.balanceOf(self.fundsManagerContract.address)
        try:
            self.fundsManagerContract.reclaimFunds(GS_PROJECT_ID, 50 * self.DECIMALS, tokenContractsAddresses,
                                                   private_key=self.accounts[1].key)
            self.fail()
        except Exception as e:
            self.assertIn("insufficient allowance", str(e))

        self.assertTrue(WEB3.eth.get_balance(self.accounts[1].address) <= eth_balance_before)
        self.assertEqual(self.tokenContract.balanceOf(self.fundsManagerContract.address), funds_manager_balance)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[1].address), 75 * self.DECIMALS)
        self.assertEqual(self.neptune_token_contract.balanceOf(self.accounts[1].address), 0)
        self.assertEqual(self.saturn_token_contract.balanceOf(self.accounts[1].address), 0)

    def test_reclaim_funds_with_no_approval(self):
        self.neptune_token_contract.transfer(self.fundsManagerContract.address, 100 * self.DECIMALS,
                                             private_key=self.private_key)
        self.saturn_token_contract.transfer(self.fundsManagerContract.address, 200 * self.DECIMALS,
                                            private_key=self.private_key)
        self.fundsManagerContract.depositEth(GS_PROJECT_ID, private_key=INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY,
                                             wei=1 * 10 ** 18)

        eth_balance_before = WEB3.eth.get_balance(self.accounts[1].address)
        funds_manager_balance = self.tokenContract.balanceOf(self.fundsManagerContract.address)

        tokenContractsAddresses = [self.neptune_token_contract.address, self.saturn_token_contract.address]

        try:
            self.fundsManagerContract.reclaimFunds(GS_PROJECT_ID, 50 * self.DECIMALS, tokenContractsAddresses,
                                                   private_key=self.accounts[1].key)
            self.fail()
        except Exception as e:
            self.assertIn("insufficient allowance", str(e))

        self.assertTrue(WEB3.eth.get_balance(self.accounts[1].address) <= eth_balance_before)
        self.assertEqual(self.tokenContract.balanceOf(self.fundsManagerContract.address), funds_manager_balance)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[1].address), 75 * self.DECIMALS)
        self.assertEqual(self.neptune_token_contract.balanceOf(self.accounts[1].address), 0)
        self.assertEqual(self.saturn_token_contract.balanceOf(self.accounts[1].address), 0)

    def test_reclaim_funds_after_balance_of_reclaimer_was_changed(self):
        self.neptune_token_contract.transfer(self.fundsManagerContract.address, 100 * self.DECIMALS,
                                             private_key=self.private_key)
        self.saturn_token_contract.transfer(self.fundsManagerContract.address, 200 * self.DECIMALS,
                                            private_key=self.private_key)
        self.fundsManagerContract.depositEth(GS_PROJECT_ID, private_key=INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY,
                                             wei=1 * 10 ** 18)
        self.tokenContract.approve(self.fundsManagerContract.address, 50 * self.DECIMALS,
                                   private_key=self.accounts[1].key)
        self.tokenContract.transfer(self.accounts[0].address, 50 * self.DECIMALS,
                                    private_key=self.accounts[1].key)

        eth_balance_before = WEB3.eth.get_balance(self.accounts[1].address)
        funds_manager_balance = self.tokenContract.balanceOf(self.fundsManagerContract.address)

        token_contracts_addresses = [self.neptune_token_contract.address, self.saturn_token_contract.address]

        try:
            self.fundsManagerContract.reclaimFunds(GS_PROJECT_ID, 50 * self.DECIMALS, token_contracts_addresses,
                                                   private_key=self.accounts[1].key)
            self.fail()
        except Exception as e:
            self.assertIn("insufficient balance", str(e))

        self.assertTrue(WEB3.eth.get_balance(self.accounts[1].address) <= eth_balance_before)
        self.assertEqual(self.tokenContract.balanceOf(self.fundsManagerContract.address), funds_manager_balance)
        self.assertEqual(self.tokenContract.balanceOf(self.accounts[1].address), 25 * self.DECIMALS)
        self.assertEqual(self.neptune_token_contract.balanceOf(self.accounts[1].address), 0)
        self.assertEqual(self.saturn_token_contract.balanceOf(self.accounts[1].address), 0)
