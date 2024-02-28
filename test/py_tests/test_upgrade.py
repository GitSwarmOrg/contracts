from test.py_tests.tests import EthBaseTest
from utils import ZERO_ETH_ADDRESS, VOTE_DURATION, increase_time, EthContract, WEB3, deploy_contract_file_and_wait, \
    GS_PROJECT_ID


class UpgradeTests(EthBaseTest):

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
                                                          WEB3.keccak(text="VoteDuration")), 5 * 60 * 60 * 24)

        self.contractsManagerContract = EthContract(self.contractsManagerContract.address,
                                                    contracts_manager_logic_contract.abi, private_key=self.private_key)
        self.contractsManagerContract.changeNextProjectId(1000)
        self.assertEqual(self.contractsManagerContract.nextProjectId(), 1000)
