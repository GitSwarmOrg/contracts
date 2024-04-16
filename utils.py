import hashlib
import json
import logging
import os.path
import re
import sys
import types
from time import sleep
from typing import Literal
from unittest.mock import patch, MagicMock

from brownie import *
from brownie.network import gas_price
from brownie.network.gas.strategies import LinearScalingStrategy
from brownie.network.transaction import TransactionReceipt
from eth_account import Account
from rich import console
from web3 import HTTPProvider

from contract_proposals_data_structs import *

network.connect('hardhat')
gas_price(LinearScalingStrategy("10 gwei", "50 gwei", 1.1))
log = logging.getLogger(__name__)

ETHEREUM_NODE_ADDRESS = "http://localhost:8545"
MAX_GAS_LIMIT = 8000000

INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
GITSWARM_ACCOUNT_ADDRESS = '0x0634D869e44cB96215bE5251fE9dE0AEE10a52Ce'

GS_PROJECT_ID = 0
GS_PROJECT_DB_ID = 'gs'
BASE_DIR = os.path.dirname(os.path.abspath(__file__))


class AttrDict(dict):
    def __init__(self, *args, **kwargs):
        super(AttrDict, self).__init__(*args, **kwargs)
        self.__dict__ = self


ZERO_ETH_ADDRESS = '0x0000000000000000000000000000000000000000'

CONTRACTS_INDEX = {
    "Token": 0,
    "Delegates": 1,
    "FundsManager": 2,
    "Parameters": 3,
    "Proposal": 4,
}

INDEX_CONTRACTS = {
    0: "Token",
    1: "Delegates",
    2: "FundsManager",
    3: "Parameters",
    4: "Proposal",
}

CONTRACT_NAMES = {v: k for k, v in CONTRACTS_INDEX.items()}

UPGRADABLE_CONTRACTS = [
    "Delegates",
    "FundsManager",
    "Parameters",
    "Proposal"
]

PROJECT_CONTRACTS = [
    "Delegates",
    "FundsManager",
    "Parameters",
    "Proposal",
    "ContractsManager"]

PROPOSAL_TYPES = {
    1: TransactionProposal,
    2: None,
    3: CreateTokensProposal,
    4: None,
    5: ChangeParameterProposal,
    6: None,
    7: None,
    8: AuctionSellProposal,
    9: ChangeTrustedAddressProposal,
    10: TransferToGasAddressProposal,
    11: AddBurnAddressProposal,
    12: UpgradeContractsProposal,
    13: ChangeVotingTokenAddressProposal,
    14: DisableCreateMoreTokensProposal
}

PROPOSAL_CONTRACT = {
    1: 'FundsManager',
    2: 'FundsManager',
    3: 'Token',
    4: 'TokenSell',
    5: 'Parameters',
    6: 'FundsManager',
    7: 'TokenSell',
    8: 'TokenSell',
    9: 'ContractsManager',
    10: 'GasStation',
    11: 'ContractsManager',
    12: 'ContractsManager',
    13: 'ContractsManager',
    14: 'Token',
}

LATEST_CONTRACTS_VERSION = '1.1'

PAYROLL_GAS_COST = {1: 519953, 5: 879852, 10: 1348215, 15: 1816708, 20: 2285141}


# Gas for 1 payment payroll: 519953
#  Gas for 5 payments payroll: 879852
#  Gas for 10 payments payroll: 1348215
#  Gas for 15 payments payroll: 1816708
#  Gas for 20 payments payroll: 2285141


class Defaults:
    gas_price = Web3.to_wei(50, 'gwei')


class InsufficientGasOnProjectException(Exception):
    pass


contracts_cache = {}

_erc20_abi = None


class EthContract:

    def __init__(self, address, abi, private_key=None):
        assert address
        assert abi

        self.address = address
        self.abi = abi
        self.private_key = private_key

        self._contract = Contract.from_abi("EthContractInstance", address, abi)

    def balance(self):
        return self._contract.balance()

    # noinspection PyPep8Naming
    def processProposal(self, proposal_id, contract_project_id, expect_to_execute=False, expect_to_not_execute=False,
                        **kwargs):
        proposal_contract = EthContract(
            address=self.proposalContract(),
            abi=PROPOSAL_CONTRACT_ABI)
        tx_list = [proposal_contract.lockVoteCount(contract_project_id, proposal_id, **kwargs)]
        proposal = Proposals(proposal_contract, contract_project_id,
                             proposal_id)
        if expect_to_execute and not proposal.willExecute:
            raise AssertionError('Expected proposal to execute but the vote did not pass.')
        if expect_to_not_execute and proposal.willExecute:
            raise AssertionError('Expected proposal not to execute but the vote did pass.')

        if proposal.willExecute:
            increase_time(BUFFER_BETWEEN_END_OF_VOTING_AND_EXECUTE_PROPOSAL + 15)
            if PROPOSAL_TYPES[proposal.typeOfProposal] == CreateTokensProposal:
                tx_list.append(self.executeProposal(proposal_id, **kwargs))
            else:
                tx_list.append(self.executeProposal(contract_project_id, proposal_id, **kwargs))
        return tx_list

    def concise(self, kwargs=None):
        return self._contract.caller(kwargs)

    def topic_for(self, event_name: str):
        event = getattr(self._contract.events, event_name, None)
        if event is None:
            raise ValueError(f"Event {event_name} not found.")
        return Web3.keccak(text=event.abi['name']).hex()

    wait_until_mined = False

    def __getattr__(self, name):
        func = getattr(self._contract, name, None)
        if not func:
            raise ValueError(f"Function '{name}' does not exist on contract")

        def call_contract_function(*args, gas=None, gas_price=None, expect_success=True,
                                   wait_until_mined=self.wait_until_mined, wei=0,
                                   private_key=self.private_key):
            account = accounts.add(private_key)
            transaction_parameters = {'from': account, 'value': wei}
            print(f"Contract function {name} called on {self._contract.address} by account {account.address}")

            if gas is not None:
                transaction_parameters['gas'] = gas

            if func.abi['stateMutability'] in ['view', 'pure']:
                # For view or pure functions, just call them
                return func.call(*args, transaction_parameters)
            else:
                # For state-changing functions, send a transaction
                tx = func.transact(*args, transaction_parameters)

                if wait_until_mined:
                    # Wait for the transaction to be mined
                    tx.wait(1)
                    if expect_success and tx.status != 1:
                        raise Exception("Transaction failed.")

                return tx.txid

        return call_contract_function

    def get_error_message_for_reverted_transaction(self, *args, name, account, receipt=None, exception=None, wei=None):
        try:
            getattr(self.concise({'from': account.address, **({'value': wei} if wei else {})}), name, None)(*args)
            raise AssertionError('Failed contract call for unknown reason')
        except ContractLogicError as e:
            raise ValueError(
                "Failed contract call %s -> '%s' called with account: %s; args: %s"
                "\n%s"
                "\nMessage: %s" % (self._contract.address, name, account.address, str(args),
                                   "\nTxHash: %s" % receipt.transactionHash.hex() if receipt else '',
                                   str(e))) from exception if exception else e


def send_eth_from_default_account(amount, address, unit='ether'):
    send_eth(amount, address, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY)


def send_eth(amount, recipient, private_key, unit='ether', wait_until_mined=False, timeout=120):
    # Load the account using the private key
    account = accounts.add(private_key)

    # Convert amount to Wei, Brownie's Wei function can understand units like 'ether'
    value_in_wei = Wei(f"{amount} {unit}")

    # Send the transaction
    transaction = account.transfer(recipient, value_in_wei)

    if wait_until_mined:
        # Wait for the transaction to be mined
        transaction.wait(timeout)

    return transaction.txid


def get_abi_from_sol_file(filename):
    base_name = os.path.splitext(os.path.basename(filename))[0]

    artifact_path = os.path.join(BASE_DIR, 'artifacts', filename)
    compiled_file = os.path.join(artifact_path, f"{base_name}.json")
    compiled_file = compiled_file.replace('\\', '/')
    compiled_file = re.sub(r'(.*contracts/).*/([^/]+)$', r'\1\2', compiled_file)

    with open(compiled_file, 'r') as f:
        compiled_contract = json.load(f)

    return compiled_contract['abi']


def get_abi_for_contract_version(name, version):
    if version == 'latest':
        version = LATEST_CONTRACTS_VERSION

    return get_abi_from_sol_file('contracts/prod/' + version + '/' + name + '.sol')


def get_abi_for_event(name, contract):
    for e in contract.contract_instance().abi:
        if e['type'] == 'event' and e['name'] == name:
            return e


def decode_event_args(abi_event, data):
    types = []
    for a in abi_event['inputs']:
        types.append(a['type'])

    from eth_abi import decode
    args_tuple = decode(types, bytes.fromhex(data[2:]))
    args = {}
    i = 0
    for a in abi_event['inputs']:
        args[a['name']] = args_tuple[i]
        i += 1

    return args


compiled_files_cache = {}

deployer_account = accounts.add(config["wallets"]["from_key"])
DEPLOYMENT_DATA_FILE = 'deployment_data.json'


def get_contract_hash(contract_class, *constructor_args):
    # Combine the contract's bytecode with a string representation of constructor arguments
    # Return a hash of the combined bytes
    return hashlib.sha256(contract_class.bytecode.encode('utf-8') + str(constructor_args).encode()).hexdigest()


deployed_contracts_cache = {}


def get_cached_contract(contract_name, current_hash):
    cache_key = f"{contract_name}_{current_hash}"
    return deployed_contracts_cache.get(cache_key)


def cache_contract(contract_name, current_hash, deployed_contract):
    cache_key = f"{contract_name}_{current_hash}"
    deployed_contracts_cache[cache_key] = deployed_contract


def send_deploy_contract_transaction(filename, *contract_constructor_args, private_key, allow_recycled_contract=False):
    contract_name = os.path.basename(filename)[:-4]
    contract_class = globals()[contract_name]
    current_hash = get_contract_hash(contract_class, *contract_constructor_args)

    # Attempt to retrieve the contract from the cache first
    cached_contract = get_cached_contract(contract_name, current_hash)
    if allow_recycled_contract and cached_contract:
        print(f"Using cached contract: {contract_name} at {cached_contract.address}")
        setattr(cached_contract.tx, 'is_recycled_contract', True)
        return cached_contract.tx.txid, cached_contract
    else:
        account = accounts.add(private_key)
        deployed_contract = contract_class.deploy(*contract_constructor_args, {'from': account})

        if allow_recycled_contract:
            setattr(deployed_contract.tx, 'is_recycled_contract', False)
            cache_contract(contract_name, current_hash, deployed_contract)
            print(f"Deployed and saved contract: {contract_name} at {deployed_contract.address}")
        else:
            print(f"Deployed contract: {contract_name} at {deployed_contract.address}")

        print(f"Constructor args: {contract_constructor_args}")
        return deployed_contract.tx.txid, deployed_contract


def deploy_contract_file_and_wait(filename, *contract_constructor_args, private_key, allow_recycled_contract=False):
    tx_hash, contract = send_deploy_contract_transaction(filename, *contract_constructor_args, private_key=private_key,
                                                         allow_recycled_contract=allow_recycled_contract)
    is_recycled_contract = getattr(contract.tx, 'is_recycled_contract', False)
    if not is_recycled_contract:
        contract.tx.wait(1)

    receipt = TransactionReceipt(tx_hash)

    if receipt.status != 1:
        account = Account.from_key(private_key)
        raise ValueError("Failed to deploy contract %s with account: %s; tx: %s args: %s" % (
            filename, account.address, tx_hash.hex(), str(contract_constructor_args)))

    eth_contract = EthContract(contract.address, contract.abi, private_key=private_key)
    return eth_contract, AttrDict({'tx_hash': tx_hash,
                                   'gasUsed': receipt.gas_used,
                                   'status': receipt.status,
                                   'contractAddress': receipt.contract_address,
                                   'from': receipt.sender,
                                   'is_recycled_contract': is_recycled_contract})


def deploy_test_contract(name, *contract_constructor_args, private_key, allow_recycled_contract=False):
    return deploy_contract_file_and_wait('contracts/test/' + name + '.sol',
                                         *contract_constructor_args, private_key=private_key,
                                         allow_recycled_contract=allow_recycled_contract)


def deploy_contract_version_and_wait(name, version, *contract_constructor_args, private_key,
                                     allow_recycled_contract=False):
    return deploy_contract_file_and_wait(get_contract_file_path(name, version),
                                         *contract_constructor_args, private_key=private_key,
                                         allow_recycled_contract=allow_recycled_contract)


def get_contract_file_path(name, version):
    if version == 'latest':
        version = LATEST_CONTRACTS_VERSION
    return 'contracts/prod/' + version + '/' + name + '.sol'


def get_base_file_path(name, version):
    if version == 'latest':
        version = LATEST_CONTRACTS_VERSION
    return 'contracts/prod/' + version + '/base/' + name + '.sol'


VOTE_DURATION = 60 + 3
EXPIRATION_PERIOD = 5 * 60
BUFFER_BETWEEN_END_OF_VOTING_AND_EXECUTE_PROPOSAL = 60


def increase_time(duration):
    chain.sleep(duration)


class TransactionFailedException(Exception):
    pass


def tx_info(tx_hash, throw_on_error=True):
    try:
        receipt = TransactionReceipt(tx_hash)
    except Exception as e:
        if throw_on_error:
            raise e
        else:
            return AttrDict({'error': str(e)})

    if not receipt:
        return None

    if throw_on_error and receipt.status != 1:
        raise TransactionFailedException("Transaction failed tx: %s" % tx_hash)

    return AttrDict({'tx_hash': tx_hash,
                     'gasUsed': receipt.gas_used,
                     'logs': [AttrDict(rl) for rl in receipt.logs],
                     'status': receipt.status,
                     'contractAddress': receipt.contract_address,
                     'from': receipt.sender})


from web3._utils.events import get_event_data
from web3._utils.filters import construct_event_filter_params


def fetch_events(
        event,
        argument_filters=None,
        from_block=None,
        to_block: Literal["latest", "earliest", "pending", "safe", "finalized"] = "latest",
        address=None,
        topics=None):
    """Get events using eth_getLogs API.

    This is a stateless method, as opposite to createFilter and works with
    stateless nodes like QuikNode and Infura.

    :param event: Event instance from your contract.events
    :param argument_filters:
    :param from_block: Start block. Use 0 for all history/
    :param to_block: Fetch events until this contract
    :param address:
    :param topics:
    :return:
    """

    if from_block is None:
        raise TypeError("Missing mandatory keyword argument to getLogs: from_Block")

    abi = event._get_event_abi()
    abi_codec = event.w3.codec

    # Set up any indexed event filters if needed
    argument_filters = dict()
    _filters = dict(**argument_filters)

    data_filter_set, event_filter_params = construct_event_filter_params(
        abi,
        abi_codec,
        contract_address=event.address,
        argument_filters=_filters,
        fromBlock=from_block,
        toBlock=to_block,
        address=address,
        topics=topics,
    )

    # Call node over JSON-RPC API
    logs = event.w3.eth.get_logs(event_filter_params)

    # Convert raw binary event data to easily manipulable Python objects
    for entry in logs:
        data = get_event_data(abi_codec, abi, entry)
        yield data


CONTRACTS_MANAGER_ABI = get_abi_for_contract_version('ContractsManager', 'latest')
PROPOSAL_CONTRACT_ABI = get_abi_for_contract_version('Proposal', 'latest')


def deploy_proxy_contract(name, admin, private_key, proxy='MyTransparentUpgradeableProxy',
                          allow_recycled_contract=False):
    logic_contract, info_logic = deploy_contract_version_and_wait(
        name,
        'latest',
        private_key=private_key,
        allow_recycled_contract=allow_recycled_contract)
    proxy_contract, info_proxy = deploy_contract_version_and_wait(
        'base/%s' % proxy,
        'latest',
        logic_contract.address,
        *([admin] if admin else []),
        b'',
        private_key=private_key,
        allow_recycled_contract=allow_recycled_contract)
    proxy_contract = EthContract(proxy_contract.address, logic_contract.abi, private_key=private_key)
    return logic_contract, proxy_contract, info_proxy['is_recycled_contract']


def initial_deploy_gs_contracts(token_name, token_symbol, fm_supply, token_buffer_amount, private_key):
    contracts_manager_logic, contracts_manager_contract, is_cm_recycled_contract = \
        deploy_proxy_contract('ContractsManager',
                              admin=None,
                              private_key=private_key,
                              proxy='SelfAdminTransparentUpgradeableProxy',
                              allow_recycled_contract=True)

    contracts = {
        'Delegates': {'args': []},
        'FundsManager': {'args': []},
        'Parameters': {'args': []},
        'Proposal': {'args': [GITSWARM_ACCOUNT_ADDRESS]},
        'GasStation': {'args': []},
        'GitSwarmToken': {'args': [token_name, token_symbol, GS_PROJECT_DB_ID, fm_supply, token_buffer_amount]},
    }

    for name, details in contracts.items():
        logic_contract, proxy_contract, is_recycled_contract = deploy_proxy_contract(name,
                                                                                     admin=contracts_manager_contract.address,
                                                                                     private_key=private_key,
                                                                                     allow_recycled_contract=name != 'GitSwarmToken')
        contracts[name]['logic'] = logic_contract
        contracts[name]['proxy'] = proxy_contract
        contracts[name]['is_recycled_contract'] = is_recycled_contract

    contracts = {
        'ContractsManager': {'proxy': contracts_manager_contract,
                             'logic': contracts_manager_logic,
                             'args': [],
                             'is_recycled_contract': is_cm_recycled_contract
                             },
        **contracts}

    contracts['Token'] = contracts['GitSwarmToken']
    del contracts['GitSwarmToken']

    contract_addresses = [
        contracts['Delegates']['proxy'].address,
        contracts['FundsManager']['proxy'].address,
        contracts['Parameters']['proxy'].address,
        contracts['Proposal']['proxy'].address,
        contracts['GasStation']['proxy'].address,
        contracts['ContractsManager']['proxy'].address,
    ]
    for name, details in contracts.items():
        if details['is_recycled_contract']:
            print('Skipping initialize on recycled contract')
            continue
        details['proxy'].initialize(*details['args'], *contract_addresses, private_key=private_key)

    return contracts


class PatchMixin:
    """
    Testing utility mixin that provides methods to patch objects so that they
    will get unpatched automatically.
    """

    # noinspection PyUnresolvedReferences
    def patch(self, *args, **kwargs):
        patcher = patch(*args, **kwargs)
        self.addCleanup(patcher.stop)
        return patcher.start()

    # noinspection PyUnresolvedReferences
    def patch_object(self, *args, **kwargs):
        patcher = patch.object(*args, **kwargs)
        self.addCleanup(patcher.stop)
        return patcher.start()

    # noinspection PyUnresolvedReferences
    def patch_dict(self, *args, **kwargs):
        patcher = patch.dict(*args, **kwargs)
        self.addCleanup(patcher.stop)
        return patcher.start()

    list_id = 0

    def mock_add_list(self, *args, **kwargs):
        self.list_id += 111
        return MagicMock(id=str(self.list_id))

    def patch_redis(self):
        self.patch('core.redis.Redis.publish')
        self.patch('redis.lock.Lock.acquire')
        self.patch('redis.lock.Lock.release')

    # noinspection PyAttributeOutsideInit


class Method:
    def __init__(self, method):
        if not isinstance(method, types.MethodType):
            raise ValueError('param "method" must be of type types.MethodType')
        self.method = method

    def __eq__(self, other):
        if isinstance(other, Method):
            return self.method == other
        if type(other) != type(self.method):
            return False
        # noinspection PyUnresolvedReferences
        return self.method.__self__ == other.__self__ and self.method.__code__.co_name == other.__code__.co_name

    def __repr__(self):
        return str(self.method)


def hamming_distance(s1, s2):
    if len(s1) != len(s2):
        return sys.maxsize

    return sum(el1 != el2 for el1, el2 in zip(s1, s2))
