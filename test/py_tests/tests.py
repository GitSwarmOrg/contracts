from unittest import TestCase

from contract_proposals_data_structs import Proposals, ChangeTrustedAddressProposal
from utils import increase_time, VOTE_DURATION, WEB3, CONTRACTS_INDEX, EthContract, send_eth, EXPIRATION_PERIOD, \
    deploy_contract_file_and_wait, ZERO_ETH_ADDRESS, \
    initial_deploy_gs_contracts, GS_PROJECT_ID, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY


class EthBaseTest(TestCase):
    token_buffer_amount = 10 ** 20
    fm_supply = 10 ** 20

    def setUp(self):
        EthContract.wait_until_mined = True
        self.accounts = []
        self.eth_account = WEB3.eth.account.create()
        self.private_key = self.eth_account.key.hex()
        send_eth(100, self.eth_account.address, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY)

        contracts = initial_deploy_gs_contracts("GitSwarm", "GS", self.fm_supply, self.token_buffer_amount,
                                                self.private_key)

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

    def create_test_account(self, token_contract, token_amount=10 ** 18, eth_amount=10 ** 20):

        acc = WEB3.eth.account.create()
        self.accounts.append(acc)

        if self.token_buffer_amount < token_amount:
            raise ValueError("Insufficient tokens!")
        if token_amount != 0:
            token_contract.transfer(acc.address, token_amount, private_key=self.private_key)
            self.token_buffer_amount -= token_amount
        if eth_amount != 0:
            send_eth(eth_amount, acc.address, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY, unit='wei')

        return acc

    def test_upgrade_contract(self):
        proposal_logic_contract, tx_hash = deploy_contract_file_and_wait('contracts/test/Proposal2.sol',
                                                                         private_key=self.private_key,
                                                                         allow_cache=True)
        contracts_manager_logic_contract, tx_hash = deploy_contract_file_and_wait(
            'contracts/test/ContractsManager2.sol',
            private_key=self.private_key,
            allow_cache=True)

        self.contractsManagerContract.proposeUpgradeContracts(ZERO_ETH_ADDRESS,
                                                              ZERO_ETH_ADDRESS,
                                                              ZERO_ETH_ADDRESS,
                                                              proposal_logic_contract.address,
                                                              ZERO_ETH_ADDRESS,
                                                              contracts_manager_logic_contract.address,
                                                              private_key=self.private_key)

        increase_time(VOTE_DURATION + 15)
        self.contractsManagerContract.processProposal(self.proposalContract.nextProposalId(GS_PROJECT_ID) - 1,
                                                      private_key=self.private_key,
                                                      contract_project_id=GS_PROJECT_ID)

        self.proposalContract = EthContract(self.proposalContract.address, proposal_logic_contract.abi,
                                            private_key=self.private_key)
        self.proposalContract.changeVoteDuration(GS_PROJECT_ID)
        self.assertEqual(self.proposalContract.parameters(GS_PROJECT_ID,
                                                          WEB3.keccak(text="VoteDuration"))[0], 5 * 60 * 60 * 24)

        self.contractsManagerContract = EthContract(self.contractsManagerContract.address,
                                                    contracts_manager_logic_contract.abi, private_key=self.private_key)
        self.contractsManagerContract.changeNextProjectId(1000)
        self.assertEqual(self.contractsManagerContract.nextProjectId(), 1000)


# noinspection PyTypeChecker
class EthereumTests(EthBaseTest):

    def setUp(self):
        super().setUp()
        self.create_test_account(token_contract=self.tokenContract)
        self.create_test_account(token_contract=self.tokenContract)

    def test_restricted_modifier(self):
        try:
            self.proposalContract.deleteProposal(GS_PROJECT_ID, 5,
                                                 private_key=self.accounts[1].key)
            self.fail()
        except Exception as e:
            self.assertIn("Failed contract call", str(e))

        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.contractsManagerContract.proposeChangeTrustedAddress(GS_PROJECT_ID, CONTRACTS_INDEX["Token"],
                                                                  self.accounts[1].address,
                                                                  private_key=self.accounts[0].key)
        self.proposalContract.voteProposalId(GS_PROJECT_ID, proposal_id, True,
                                             private_key=self.accounts[1].key)
        increase_time(VOTE_DURATION + 15)
        proposal = Proposals(self.proposalContract, GS_PROJECT_ID, proposal_id)
        self.assertTrue(proposal.votingAllowed)
        token_sell_proposal = ChangeTrustedAddressProposal(self.contractsManagerContract, GS_PROJECT_ID,
                                                           proposal_id)
        self.assertEqual(token_sell_proposal.contractIndex, CONTRACTS_INDEX["Token"])
        self.assertEqual(token_sell_proposal.contractAddress, self.accounts[1].address)

        self.contractsManagerContract.processProposal(proposal_id, private_key=self.accounts[0].key,
                                                      contract_project_id=GS_PROJECT_ID)

        self.assertEqual(self.contractsManagerContract.trustedAddresses(GS_PROJECT_ID, CONTRACTS_INDEX["Token"]),
                         self.accounts[1].address)

        self.proposalContract.deleteProposal(GS_PROJECT_ID, 0, private_key=self.accounts[1].key)

    def test_delete_expired_proposals(self):
        proposal_id = self.proposalContract.nextProposalId(GS_PROJECT_ID)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [101],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].key)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [102],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].key)
        self.fundsManagerContract.proposeTransaction(GS_PROJECT_ID, [self.tokenContract.address], [103],
                                                     [self.accounts[1].address], [0],
                                                     private_key=self.accounts[0].key)

        self.assertEqual(Proposals(self.proposalContract, GS_PROJECT_ID, proposal_id).typeOfProposal, 1)
        self.assertEqual(Proposals(self.proposalContract, GS_PROJECT_ID, proposal_id + 1).typeOfProposal, 1)
        self.assertEqual(Proposals(self.proposalContract, GS_PROJECT_ID, proposal_id + 2).typeOfProposal, 1)
        increase_time(VOTE_DURATION + EXPIRATION_PERIOD)

        self.fundsManagerContract.deleteExpiredProposals(GS_PROJECT_ID,
                                                         [proposal_id, proposal_id + 1, proposal_id + 2])

        self.assertEqual(Proposals(self.proposalContract, GS_PROJECT_ID, proposal_id).typeOfProposal, 0)
        self.assertEqual(Proposals(self.proposalContract, GS_PROJECT_ID, proposal_id + 1).typeOfProposal, 0)
        self.assertEqual(Proposals(self.proposalContract, GS_PROJECT_ID, proposal_id + 2).typeOfProposal, 0)

        self.assertEqual(Proposals(self.proposalContract, GS_PROJECT_ID, proposal_id).endTime, 0)
        self.assertEqual(Proposals(self.proposalContract, GS_PROJECT_ID, proposal_id + 1).endTime, 0)
        self.assertEqual(Proposals(self.proposalContract, GS_PROJECT_ID, proposal_id + 2).endTime, 0)
