from unittest import TestCase

from brownie import accounts
from web3 import Web3

from contract_proposals_data_structs import Proposals, ChangeTrustedAddressProposal
from utils import increase_time, VOTE_DURATION, CONTRACTS_INDEX, EthContract, send_eth, \
    initial_deploy_gs_contracts, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY

class EthBaseTest(TestCase):
    token_buffer_amount = 10 ** 20
    fm_supply = 10 ** 20
    skip_deploy = False

    def setUp(self):
        EthContract.wait_until_mined = True
        self.accounts = []
        self.eth_account = accounts.add(INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY)
        self.private_key = INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY
        send_eth(100, self.eth_account.address, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY)

        if not self.skip_deploy:
            contracts = initial_deploy_gs_contracts("GitSwarm", "GS", self.fm_supply,
                                                    self.token_buffer_amount, self.private_key)

            self.delegatesContract = contracts['Delegates']['proxy']
            self.fundsManagerContract = contracts['FundsManager']['proxy']
            self.parametersContract = contracts['Parameters']['proxy']
            self.proposalContract = contracts['Proposal']['proxy']
            self.gasStationContract = contracts['GasStation']['proxy']
            self.contractsManagerContract = contracts['ContractsManager']['proxy']
            self.tokenContract = contracts['Token']['proxy']

            self.p_id = self.contractsManagerContract.nextProjectId() - 1
            
            self.assertEqual(self.tokenContract.delegatesContract(), self.delegatesContract.address)
            self.assertEqual(self.tokenContract.fundsManagerContract(), self.fundsManagerContract.address)
            self.assertEqual(self.tokenContract.parametersContract(), self.parametersContract.address)
            self.assertEqual(self.tokenContract.proposalContract(), self.proposalContract.address)
            self.assertEqual(self.tokenContract.gasStationContract(), self.gasStationContract.address)
            self.assertEqual(self.tokenContract.contractsManagerContract(), self.contractsManagerContract.address)
            self.assertEqual(self.tokenContract.totalSupply(), self.fm_supply + self.token_buffer_amount)
            self.assertEqual(self.tokenContract.balanceOf(self.eth_account.address), self.token_buffer_amount)
            self.assertEqual(self.tokenContract.balanceOf(self.fundsManagerContract.address), self.fm_supply)
            self.assertEqual(self.fundsManagerContract.balances(self.p_id, self.tokenContract.address), self.fm_supply)

    def create_test_account(self, token_contract=None, token_amount=10 ** 18, eth_amount=10 ** 20):
        if token_contract is None:
            token_contract = self.tokenContract
        acc = accounts.add()
        self.accounts.append(acc)

        if self.token_buffer_amount < token_amount:
            raise ValueError("Insufficient tokens!")
        if eth_amount != 0:
            send_eth(eth_amount, acc.address, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY, unit='wei')
        print(f'zzzz1 balance before: {token_contract.balanceOf(acc.address, private_key=acc.private_key)} '
              f'||| {token_amount}')
        if token_amount != 0:
            token_contract.transfer(acc.address, token_amount, private_key=self.private_key)
            self.token_buffer_amount -= token_amount
        print(f'zzzz2 balance after: {token_contract.balanceOf(acc.address, private_key=acc.private_key)}')

        print(f'Created test account {acc.address} with {token_amount} tokens and {eth_amount} eth.'
              f' Total accounts: {len(self.accounts)}')
        return acc


# noinspection PyTypeChecker
class EthereumTests(EthBaseTest):

    def setUp(self):
        super().setUp()
        self.create_test_account()
        self.create_test_account()

    def test_restricted_modifier(self):
        try:
            self.proposalContract.deleteProposal(self.p_id, 5,
                                                 private_key=self.accounts[1].private_key)
            self.fail()
        except Exception as e:
            self.assertIn("Restricted function ", str(e))

        proposal_id = self.proposalContract.nextProposalId(self.p_id)
        self.contractsManagerContract.proposeChangeTrustedAddress(self.p_id, CONTRACTS_INDEX["Token"],
                                                                  self.accounts[1].address,
                                                                  private_key=self.accounts[0].private_key)
        self.proposalContract.vote(self.p_id, proposal_id, True,
                                   private_key=self.accounts[1].private_key)
        increase_time(VOTE_DURATION)
        proposal = Proposals(self.proposalContract, self.p_id, proposal_id)
        self.assertTrue(proposal.votingAllowed)
        token_sell_proposal = ChangeTrustedAddressProposal(self.contractsManagerContract, self.p_id,
                                                           proposal_id)
        self.assertEqual(token_sell_proposal.index, CONTRACTS_INDEX["Token"])
        self.assertEqual(token_sell_proposal.address, self.accounts[1].address)

        self.contractsManagerContract.processProposal(proposal_id, private_key=self.accounts[0].private_key,
                                                      contract_project_id=self.p_id)

        self.assertEqual(self.contractsManagerContract.trustedAddresses(self.p_id, CONTRACTS_INDEX["Token"]),
                         self.accounts[1].address)

        self.proposalContract.deleteProposal(self.p_id, 0, private_key=self.accounts[1].private_key)
