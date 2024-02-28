from unittest import TestCase

from contract_proposals_data_structs import Proposals, ChangeTrustedAddressProposal
from utils import increase_time, VOTE_DURATION, WEB3, CONTRACTS_INDEX, EthContract, send_eth, \
    initial_deploy_gs_contracts, GS_PROJECT_ID, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY

class EthBaseTest(TestCase):
    token_buffer_amount = 10 ** 20
    fm_supply = 10 ** 20
    skip_deploy = False

    def setUp(self):
        EthContract.wait_until_mined = True
        self.accounts = []
        self.eth_account = WEB3.eth.account.create()
        self.private_key = self.eth_account.key.hex()
        send_eth(100, self.eth_account.address, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY)

        if not self.skip_deploy:
            contracts = initial_deploy_gs_contracts("GitSwarm", "GS", self.fm_supply,
                                                    self.token_buffer_amount, self.private_key)

            self.delegatesContract = contracts['Delegates']['proxy']
            self.fundsManagerContract = contracts['FundsManager']['proxy']
            self.tokenSellContract = contracts['TokenSell']['proxy']
            self.proposalContract = contracts['Proposal']['proxy']
            self.gasStationContract = contracts['GasStation']['proxy']
            self.contractsManagerContract = contracts['ContractsManager']['proxy']
            self.tokenContract = contracts['Token']['proxy']

            self.assertEqual(self.tokenContract.delegatesContract(), self.delegatesContract.address)
            self.assertEqual(self.tokenContract.fundsManagerContract(), self.fundsManagerContract.address)
            self.assertEqual(self.tokenContract.tokenSellContract(), self.tokenSellContract.address)
            self.assertEqual(self.tokenContract.proposalContract(), self.proposalContract.address)
            self.assertEqual(self.tokenContract.gasStationContract(), self.gasStationContract.address)
            self.assertEqual(self.tokenContract.contractsManagerContract(), self.contractsManagerContract.address)
            self.assertEqual(self.tokenContract.totalSupply(), self.fm_supply + self.token_buffer_amount)
            self.assertEqual(self.tokenContract.balanceOf(self.eth_account.address), self.token_buffer_amount)
            self.assertEqual(self.tokenContract.balanceOf(self.fundsManagerContract.address), self.fm_supply)
            self.assertEqual(self.fundsManagerContract.balances(0, self.tokenContract.address), self.fm_supply)

    def create_test_account(self, token_contract=None, token_amount=10 ** 18, eth_amount=10 ** 20):
        if token_contract is None:
            token_contract = self.tokenContract
        acc = WEB3.eth.account.create()
        self.accounts.append(acc)

        if self.token_buffer_amount < token_amount:
            raise ValueError("Insufficient tokens!")
        if eth_amount != 0:
            send_eth(eth_amount, acc.address, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY, unit='wei')
        if token_amount != 0:
            token_contract.transfer(acc.address, token_amount, private_key=self.private_key)
            self.token_buffer_amount -= token_amount

        print(f'Created test account with {token_amount} tokens and {eth_amount} eth.'
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
            self.proposalContract.deleteProposal(GS_PROJECT_ID, 5,
                                                 private_key=self.accounts[1].key)
            self.fail()
        except Exception as e:
            self.assertIn("Restricted function ", str(e))

        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.contractsManagerContract.proposeChangeTrustedAddress(GS_PROJECT_ID, CONTRACTS_INDEX["Token"],
                                                                  self.accounts[1].address,
                                                                  private_key=self.accounts[0].key)
        self.proposalContract.vote(GS_PROJECT_ID, proposal_id, True,
                                   private_key=self.accounts[1].key)
        increase_time(VOTE_DURATION + 15)
        proposal = Proposals(self.proposalContract, GS_PROJECT_ID, proposal_id)
        self.assertTrue(proposal.votingAllowed)
        token_sell_proposal = ChangeTrustedAddressProposal(self.contractsManagerContract, GS_PROJECT_ID,
                                                           proposal_id)
        self.assertEqual(token_sell_proposal.index, CONTRACTS_INDEX["Token"])
        self.assertEqual(token_sell_proposal.address, self.accounts[1].address)

        self.contractsManagerContract.processProposal(proposal_id, private_key=self.accounts[0].key,
                                                      contract_project_id=GS_PROJECT_ID)

        self.assertEqual(self.contractsManagerContract.trustedAddresses(GS_PROJECT_ID, CONTRACTS_INDEX["Token"]),
                         self.accounts[1].address)

        self.proposalContract.deleteProposal(GS_PROJECT_ID, 0, private_key=self.accounts[1].key)
