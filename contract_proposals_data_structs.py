from datetime import datetime
from decimal import Decimal

from web3 import Web3
from web3.exceptions import ContractLogicError


def _eth_contract(*a, **kwa):
    from utils import EthContract
    return EthContract(*a, **kwa)


class ProposalData:
    def __init__(self, funds_manager_contract, project_id, proposal_id):
        self.contract = funds_manager_contract
        self.project_id = project_id
        self.proposal_id = proposal_id

    @property
    def title(self):
        return 'No title'

    @property
    def description(self):
        return 'No description'


class Proposals(ProposalData):

    def __init__(self, proposal_contract, project_id, proposal_id):
        super().__init__(proposal_contract, project_id, proposal_id)

        proposal_list = proposal_contract.proposals(project_id, proposal_id)

        if not isinstance(proposal_list, list):
            raise AssertionError("proposal_list arg must be a list")
        if not len(proposal_list) == 5:
            raise AssertionError("proposal_list should have 5 items, found %d" % len(proposal_list))

        self.typeOfProposal = proposal_list[0]
        self.votingAllowed = proposal_list[1]
        self.willExecute = proposal_list[2]
        self.nbOfVoters = proposal_list[3]
        self.endTime = proposal_list[4]


class TransactionProposal(ProposalData):

    def __init__(self, funds_manager_contract, project_id, proposal_id):
        super().__init__(funds_manager_contract, project_id, proposal_id)

        proposal_list = funds_manager_contract.transactionProposal(project_id, proposal_id)
        if not len(proposal_list) == 4:
            raise AssertionError("proposal_list tuple should have 4 items, found %d"
                                 % len(proposal_list))
        self._set_proposal_data_list(proposal_list)

    def _set_proposal_data_list(self, proposal_list):
        if not isinstance(proposal_list, list):
            raise AssertionError("proposal_list must be a list")

        from utils import get_abi_for_contract_version
        from utils import ZERO_ETH_ADDRESS

        self.recipients = []
        for i in range(0, len(proposal_list[1])):
            self.tokens = proposal_list[0]
            if self.tokens[i] and self.tokens[i] != ZERO_ETH_ADDRESS:
                decimals = _eth_contract(self.tokens[i],
                                         get_abi_for_contract_version('Token', 'latest', allow_cache=True)).decimals()
            else:
                decimals = 18
            self.recipients.append(
                {'address': proposal_list[2][i] if proposal_list[2][i] is not None else ZERO_ETH_ADDRESS,
                 'amount': Decimal(proposal_list[1][i]) / 10 ** decimals,
                 'token': self.tokens[i] if self.tokens[i] is not None else ZERO_ETH_ADDRESS,
                 'depositToProjectId': proposal_list[3][i]})


class ChangeParameterProposal(ProposalData):
    parameters_names = {
        Web3.keccak(text="VoteDuration"): 'VoteDuration',
        Web3.keccak(text="MaxNrOfDelegators"): 'MaxNrOfDelegators',
        Web3.keccak(text="BufferBetweenEndOfVotingAndExecuteProposal"): 'BufferBetweenEndOfVotingAndExecuteProposal',
        Web3.keccak(text="RequiredVotingPowerPercentageToCreateTokens"): 'RequiredVotingPowerPercentageToCreateTokens',
        Web3.keccak(text="VetoMinimumPercentage"): 'VetoMinimumPercentage',
        Web3.keccak(text="ExpirationPeriod"): 'ExpirationPeriod'
    }

    def __init__(self, proposal_contract, project_id, proposal_id):
        super().__init__(proposal_contract, project_id, proposal_id)

        proposal_list = proposal_contract.changeParameterProposals(project_id, proposal_id)

        if not isinstance(proposal_list, list):
            raise AssertionError("ChangeParameterProposal constructor arg must be a list")
        if not len(proposal_list) == 2:
            raise AssertionError("ChangeParameterProposal proposal tuple should have 2 items")

        self.parameterName = self.parameters_names[proposal_list[0]]
        self.value = proposal_list[1]

    @property
    def title(self):
        return "Set FundsManager parameter '%s' to %s" % (self.parameterName, self.value)


class AuctionSellProposal(ProposalData):

    def __init__(self, token_sell_contract, project_id, proposal_id):
        super().__init__(token_sell_contract, project_id, proposal_id)

        proposal_list = token_sell_contract.auctionProposals(project_id, proposal_id)

        if not isinstance(proposal_list, list):
            raise AssertionError("AuctionSellProposal constructor arg must be a list")
        if not len(proposal_list) == 9:
            raise AssertionError("AuctionSellProposal proposal tuple should have 8 items")

        self.tokenToSell = proposal_list[0]
        self.nbOfTokens = proposal_list[1]
        self.minimumWei = proposal_list[2]
        self.totalEthReceived = proposal_list[3]
        self.totalEthClaimed = proposal_list[4]
        self.startTime = proposal_list[5]
        self.endTime = proposal_list[6]
        self.canBuy = proposal_list[7]
        self.tokensSentBack = proposal_list[8]

        if self.tokenToSell:
            from utils import get_abi_for_contract_version

            decimals = _eth_contract(self.tokenToSell,
                                     get_abi_for_contract_version('ExpandableSupplyToken', 'latest', allow_cache=True)).decimals()
            self.nbOfTokens = Decimal(self.nbOfTokens) / Decimal(10) ** decimals
        else:
            self.nbOfTokens = Decimal(self.nbOfTokens) / Decimal(10) ** 18

    @property
    def title(self):
        return f"Auction sell of {self.nbOfTokens:f} {self.get_token_name(self.tokenToSell)}"

    @property
    def description(self):
        return f"Sell {self.nbOfTokens:f} %s for a minimum of {self.minimumWei / 10 ** 18:f} ETH." \
               f" Starts at %s and ends at %s" % \
            (self.get_token_name(self.tokenToSell),
             datetime.utcfromtimestamp(self.startTime), datetime.utcfromtimestamp(self.endTime))


class ChangeTrustedAddressProposal(ProposalData):

    def __init__(self, contracts_manager, project_id, proposal_id):
        super().__init__(contracts_manager, project_id, proposal_id)

        proposal_list = contracts_manager.changeTrustedAddressProposals(project_id, proposal_id)

        if not isinstance(proposal_list, list):
            raise AssertionError("ChangeTrustedAddressProposal constructor arg must be a list")
        if not len(proposal_list) == 2:
            raise AssertionError("ChangeTrustedAddressProposal proposal tuple should have 2 items")

        self.index = proposal_list[0]
        self.address = proposal_list[1]
        self.trusted_addresses = contracts_manager.trustedAddresses
        self.project_id = project_id

        i = 0
        try:
            while True:
                contracts_manager.trustedAddresses(project_id, i)
                i += 1
        except ContractLogicError:
            self.trustedAddressesCount = i

    @property
    def title(self):
        from utils import ZERO_ETH_ADDRESS
        if self.address == ZERO_ETH_ADDRESS:
            return "Remove %s from trusted addresses list" % self.trusted_addresses(self.project_id, self.index)

        elif self.index == self.trustedAddressesCount:
            return "Add %s to trusted addresses list" % self.address

        else:
            return "Replace trusted address %s with %s" % (
                self.trusted_addresses(self.project_id, self.index), self.address)


class CreateTokensProposal(ProposalData):

    def __init__(self, token_contract, project_id, proposal_id):
        super().__init__(token_contract, project_id, proposal_id)
        # TODO: projectId is hardcoded to 0

        token_amount = token_contract.createTokensProposals(proposal_id)
        decimals = token_contract.decimals()

        self.amount = Decimal(token_amount).canonical() / Decimal(10) ** decimals

    @property
    def title(self):
        return f'Create {self.amount:f} voting tokens'


class TransferToGasAddressProposal(ProposalData):

    def __init__(self, gas_station_contract, project_id, proposal_id):
        super().__init__(gas_station_contract, project_id, proposal_id)

        transfer_to_gas_address_proposal = gas_station_contract.transferToGasAddressProposals(proposal_id)

        if not isinstance(transfer_to_gas_address_proposal, list):
            raise AssertionError("ChangeTrustedAddressProposal constructor arg must be a list")
        if not len(transfer_to_gas_address_proposal) == 2:
            raise AssertionError("ChangeTrustedAddressProposal proposal tuple should have 5 items")

        self.amount = transfer_to_gas_address_proposal[0]
        self.to = transfer_to_gas_address_proposal[1]

    @property
    def title(self):
        return f'Transfer {self.amount / 10 ** 18:f} Eth to gas address %s' % self.to


class AddBurnAddressProposal(ProposalData):

    def __init__(self, contracts_manager, project_id, proposal_id):
        super().__init__(contracts_manager, project_id, proposal_id)

        self.burn_address = contracts_manager.addBurnAddressProposals(project_id, proposal_id)

    @property
    def title(self):
        return 'Add burn address %s' % self.burn_address


class UpgradeContractsProposal(ProposalData):

    def __init__(self, contracts_manager, project_id, proposal_id):
        super().__init__(contracts_manager, project_id, proposal_id)

        (self.delegates, self.fundsManager, self.tokenSell, self.proposal,
         self.gasStation, self.contractsManagerContract) = contracts_manager.upgradeContractsProposals(proposal_id)

    @property
    def title(self):
        return 'Upgrade contracts to delegates %s, fundsManager %s, tokenSell %s, proposal %s, ' \
               'gasStation %s, contractsManagerContract %s' % (
            self.delegates, self.fundsManager, self.tokenSell,
            self.proposal, self.gasStation, self.contractsManagerContract)


class ChangeVotingTokenAddressProposal(ProposalData):

    def __init__(self, contracts_manager, project_id, proposal_id):
        super().__init__(contracts_manager, project_id, proposal_id)

        self.contractAddress = contracts_manager.changeVotingTokenProposals(project_id, proposal_id)

    @property
    def title(self):
        return "Change voting token address to %s" % self.contractAddress


class DisableCreateMoreTokensProposal(ProposalData):
    @property
    def title(self):
        return "Disable max supply increase for <token address=\"%s\"/>" % self.contract.address
