import json
import logging
import os.path
import sys
import types
from typing import Literal
from unittest.mock import patch, MagicMock, PropertyMock

from eth_account import Account
from eth_utils import event_abi_to_log_topic, encode_hex
from web3 import HTTPProvider
from web3.exceptions import InvalidAddress, BadFunctionCallOutput

from contract_proposals_data_structs import *

log = logging.getLogger(__name__)

ETHEREUM_NODE_ADDRESS = "http://localhost:8545"
MAX_GAS_LIMIT = 8000000

INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
GITSWARM_ACCOUNT_ADDRESS = '0x0634D869e44cB96215bE5251fE9dE0AEE10a52Ce'

GS_PROJECT_DB_ID = 'gs'
BASE_DIR = os.path.dirname(os.path.abspath(__file__))


class AttrDict(dict):
    def __init__(self, *args, **kwargs):
        super(AttrDict, self).__init__(*args, **kwargs)
        self.__dict__ = self


ETHEREUM_NODE = HTTPProvider(ETHEREUM_NODE_ADDRESS)
WEB3 = Web3(ETHEREUM_NODE)

ZERO_ETH_ADDRESS = '0x0000000000000000000000000000000000000000'

CONTRACTS_INDEX = {
    "Token": 0,
    "Delegates": 1,
    "FundsManager": 2,
    "TokenSell": 3,
    "Proposal": 4,
}

INDEX_CONTRACTS = {
    0: "Token",
    1: "Delegates",
    2: "FundsManager",
    3: "TokenSell",
    4: "Proposal",
}

CONTRACT_NAMES = {v: k for k, v in CONTRACTS_INDEX.items()}

UPGRADABLE_CONTRACTS = [
    "Delegates",
    "FundsManager",
    "TokenSell",
    "Proposal"
]

PROJECT_CONTRACTS = [
    "Delegates",
    "FundsManager",
    "TokenSell",
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
    5: 'Proposal',
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
    gas_price = WEB3.to_wei(50, 'gwei')


class InsufficientGasOnProjectException(Exception):
    pass


contracts_cache = {}


def get_contract(address, abi):
    key = address + str(len(abi))
    if address in contracts_cache:
        return contracts_cache[key]
    else:
        contract = WEB3.eth.contract(address=address, abi=abi)
        contracts_cache[key] = contract
    return contract


_erc20_abi = None


def get_erc20_abi():
    global _erc20_abi
    if _erc20_abi is None:
        _erc20_abi = compile_contract(get_base_file_path('ERC20Interface', 'latest'), allow_cache=True).abi
    return _erc20_abi


class EthContract:

    def __init__(self, address, abi, private_key=None):
        assert address
        assert abi

        self.address = address
        self.abi = abi
        self.private_key = private_key

        self._contract = None

        for abi_entry in abi:
            if abi_entry["type"] == "function":
                func = getattr(self._c().functions, abi_entry["name"], None)
                func.abi = abi_entry

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

    def _c(self):
        if self._contract is None:
            self._contract = get_contract(address=self.address, abi=self.abi)
        return self._contract

    def concise(self, kwargs=None):
        return self._contract.caller(kwargs)

    def topic_for(self, event_name: str):
        event = getattr(self._c().events, event_name)
        if event is None:
            raise ValueError("Event %s not found." % event_name)
        # noinspection PyProtectedMember
        return encode_hex(event_abi_to_log_topic(event._get_event_abi()))

    def estimate_gas(self, func_name, *args, send_from=None):
        func = getattr(self._c().functions, func_name, None)
        if not func:
            raise ValueError("Function '%s' does not exist on contract %s" % (func_name, self._c().address))

        if func.abi['stateMutability'] == 'view':
            return 0

        return func(*args).estimate_gas({'from': send_from} if send_from else None)

    def has_function(self, name):
        return getattr(self._c().functions, name, None) is not None

    wait_until_mined = False

    def __getattr__(self, name):
        func = getattr(self._c().functions, name, None)
        if not func:
            raise ValueError("Function '%s' does not exist on contract %s" % (name, self._c().address))

        def call_contract_function(*args, private_key=self.private_key, gas=None,
                                   gas_price=None, expect_success=True, wei=0,
                                   on_transaction_mined=None, wait_until_mined=self.wait_until_mined,
                                   before_send=None, deduct_gas_project=None, only_build_tx=False):
            if func.abi['stateMutability'] == 'view' or func.abi['stateMutability'] == 'pure':
                cc_func = getattr(self.concise(), name, None)
                return cc_func(*args)

            if gas is None:
                gas = MAX_GAS_LIMIT
                # gas = self.estimate_gas(name, *args)
                # log.debug("Estimated gas is %s for %s -> '%s' args: %s" % (
                #     gas, self._c().address, name, str(args)))
                # gas *= Decimal('1.25')
                # gas = gas.__ceil__()

            if gas_price is None and deduct_gas_project is not None and deduct_gas_project.gas_price is not None:
                gas_price = WEB3.to_wei(int(deduct_gas_project.gas_price), 'gwei')

            if gas_price is None:
                gas_price = Defaults.gas_price

            assert private_key
            account = Account.from_key(private_key)
            print(f'new tx - from {account.address} -> {name}')

            if deduct_gas_project:
                if WEB3.eth.chain_id == 17 or WEB3.eth.chain_id == 28872323069:
                    # dummy transaction to move the clock forward on the poa testnet blockchain
                    send_eth(1, GITSWARM_ACCOUNT_ADDRESS, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY, 'gwei', True)

                try:
                    gas_needed = self.estimate_gas(name, *args, send_from=account.address)
                    gas_eth_cost = gas_price * gas_needed
                    if deduct_gas_project.gas_amount < gas_eth_cost:
                        msg = '%s ETH' % (gas_eth_cost / 10 ** 18)
                        raise InsufficientGasOnProjectException(msg)
                except ValueError as e:
                    self.get_error_message_for_reverted_transaction(*args, name=name, account=account, exception=e)

            nonce = get_nonce_for_address(account.address)
            transaction = func(*args).build_transaction(
                {'chainId': WEB3.eth.chain_id, 'gas': gas, 'gasPrice': gas_price, 'nonce': nonce,
                 'value': wei})

            signed_txn = WEB3.eth.account.sign_transaction(transaction, private_key=account.key)
            txhash = signed_txn.hash
            if before_send:
                before_send(txhash)

            if not only_build_tx:
                WEB3.eth.send_raw_transaction(signed_txn.rawTransaction)

            log.debug("%s -> '%s' called. With account: %s; args: %s; gasPrice: %s; tx-hash: %s" % (
                self._c().address, name, account.address, str(args), str(gas_price), txhash.hex()))

            if wait_until_mined:
                receipt = WEB3.eth.wait_for_transaction_receipt(txhash, timeout=None)

                gas_cost = receipt.gasUsed

                log.debug("%s -> '%s' mined for %s gas. With account: %s; args: %s; tx-hash: %s" % (
                    self._c().address, name, gas_cost, account.address, str(args), txhash.hex()))

                if expect_success and receipt.status != 1:
                    self.get_error_message_for_reverted_transaction(*args, name=name, account=account,
                                                                    receipt=receipt, wei=wei)

            return txhash if not only_build_tx else (txhash, signed_txn)

        return call_contract_function

    def get_error_message_for_reverted_transaction(self, *args, name, account, receipt=None, exception=None, wei=None):
        try:
            getattr(self.concise({'from': account.address, **({'value': wei} if wei else {})}), name, None)(*args)
            raise AssertionError('Failed contract call for unknown reason')
        except ContractLogicError as e:
            raise ValueError(
                "Failed contract call %s -> '%s' called with account: %s; args: %s"
                "\n%s"
                "\nMessage: %s" % (self._c().address, name, account.address, str(args),
                                   "\nTxHash: %s" % receipt.transactionHash.hex() if receipt else '',
                                   str(e))) from exception if exception else e


def send_eth_from_default_account(amount, address, unit='ether'):
    send_eth(amount, address, INFINITE_FUNDS_ACCOUNT_PRIVATE_KEY)


def get_nonce_for_address(address):
    return WEB3.eth.get_transaction_count(address, 'pending')


def send_eth(amount, address, private_key, unit='ether', wait_until_mined=False, timeout=120):
    account = Account.from_key(private_key)
    nonce = get_nonce_for_address(account.address)

    signed_txn = WEB3.eth.account.sign_transaction(
        dict(
            nonce=nonce,
            gasPrice=WEB3.to_wei('5', 'gwei'),
            gas=100000,
            to=address,
            chainId=WEB3.eth.chain_id,
            value=WEB3.to_wei(amount, unit)
        ),
        private_key)
    txh = WEB3.eth.send_raw_transaction(signed_txn.rawTransaction)
    if wait_until_mined:
        WEB3.eth.wait_for_transaction_receipt(txh, timeout)
        return txh


def send_eth_and_wait(amount, address, private_key, timeout=None, unit='ether'):
    tx_hash = send_eth(amount, address, private_key, unit=unit)
    return WEB3.eth.wait_for_transaction_receipt(tx_hash, timeout=timeout)


def get_address_from_tx_hash(tx_hash, timeout=None):
    return WEB3.eth.wait_for_transaction_receipt(tx_hash, timeout=timeout)['contractAddress']


def get_abi_from_sol_file(filename, allow_cache=False):
    base_name = os.path.splitext(os.path.basename(filename))[0]

    artifact_path = os.path.join(BASE_DIR, 'artifacts', filename)
    compiled_file = os.path.join(artifact_path, f"{base_name}.json")

    with open(compiled_file, 'r') as f:
        compiled_contract = json.load(f)

    return compiled_contract['abi']


def get_abi_for_contract_version(name, version, allow_cache=False):
    if version == 'latest':
        version = LATEST_CONTRACTS_VERSION

    return get_abi_from_sol_file('contracts/prod/' + version + '/' + name + '.sol', allow_cache=allow_cache)


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


def send_deploy_contract_transaction(filename, *contract_constructor_args, private_key, allow_cache=False):
    contract = compile_contract(filename, allow_cache)
    account = Account.from_key(private_key)

    log.info("Deploying '%s' with account: %s" % (filename, account.address))
    nonce = get_nonce_for_address(account.address)

    transaction = contract.constructor(*contract_constructor_args).build_transaction(
        {'chainId': WEB3.eth.chain_id, 'gas': MAX_GAS_LIMIT, 'gasPrice': Defaults.gas_price,
         'nonce': nonce})

    signed_txn = WEB3.eth.account.sign_transaction(transaction, private_key=private_key)
    return WEB3.eth.send_raw_transaction(signed_txn.rawTransaction), contract


def compile_contract(filename, allow_cache=False):
    used_cache = False
    base_name = os.path.splitext(os.path.basename(filename))[0]

    artifact_path = os.path.join(BASE_DIR, 'artifacts', filename)
    compiled_file = os.path.join(artifact_path, f"{base_name}.json")

    with open(compiled_file, 'r') as f:
        compiled_contract = json.load(f)

    abi = compiled_contract['abi']
    bytecode = compiled_contract['bytecode']
    contract = WEB3.eth.contract(abi=abi, bytecode=bytecode)

    return contract


def deploy_contract_file_and_wait(filename, *contract_constructor_args, private_key, allow_cache=False):
    tx_hash, contract = send_deploy_contract_transaction(filename, *contract_constructor_args, private_key=private_key,
                                                         allow_cache=allow_cache)

    receipt = WEB3.eth.wait_for_transaction_receipt(tx_hash, timeout=None)
    cost = receipt.gasUsed * WEB3.eth.get_transaction(tx_hash).gasPrice

    account = Account.from_key(private_key)
    if receipt.status != 1:
        raise ValueError("Failed to deploy contract %s with account: %s; tx: %s args: %s" % (
            filename, account.address, receipt.transactionHash.hex(), str(contract_constructor_args)))

    address = get_address_from_tx_hash(tx_hash)

    log.info(" - address: " + address)

    eth_contract = EthContract(address, contract.abi, private_key=private_key)
    return eth_contract, AttrDict({'tx_hash': tx_hash,
                                   'cost': cost,
                                   'gasUsed': receipt.gasUsed,
                                   'status': receipt.status,
                                   'contractAddress': receipt.contractAddress,
                                   'from': receipt['from']})


def deploy_test_contract(name, *contract_constructor_args, private_key, allow_cache=True):
    return deploy_contract_file_and_wait('contracts/test/' + name + '.sol',
                                         *contract_constructor_args, private_key=private_key, allow_cache=allow_cache)


def deploy_contract_version_and_wait(name, version, *contract_constructor_args, private_key, allow_cache=False):
    return deploy_contract_file_and_wait(get_contract_file_path(name, version),
                                         *contract_constructor_args, private_key=private_key, allow_cache=allow_cache)


def get_contract_file_path(name, version):
    if version == 'latest':
        version = LATEST_CONTRACTS_VERSION
    return 'contracts/prod/' + version + '/' + name + '.sol'


def get_base_file_path(name, version):
    if version == 'latest':
        version = LATEST_CONTRACTS_VERSION
    return 'contracts/prod/' + version + '/base/' + name + '.sol'


VOTE_DURATION = 60
EXPIRATION_PERIOD = 5 * 60
BUFFER_BETWEEN_END_OF_VOTING_AND_EXECUTE_PROPOSAL = 60


def increase_time(duration, http_provider: HTTPProvider = ETHEREUM_NODE):
    response = http_provider.make_request("evm_increaseTime", [duration])

    if not response or response.get('error'):
        raise Exception("Failed to increase time: " + str(response))

    return response


class TransactionFailedException(Exception):
    pass


def tx_info(tx_hash, throw_on_error=True):
    try:
        receipt = WEB3.eth.get_transaction_receipt(tx_hash)
    except Exception as e:
        if throw_on_error:
            raise e
        else:
            return AttrDict({'error': str(e)})

    if not receipt:
        return None

    cost = receipt.gasUsed * WEB3.eth.get_transaction(tx_hash).gasPrice

    if throw_on_error and receipt.status != 1:
        raise TransactionFailedException("Transaction failed tx: %s" % tx_hash)

    return AttrDict({'tx_hash': tx_hash,
                     'cost': cost,
                     'gasUsed': receipt.gasUsed,
                     'logs': [AttrDict(rl) for rl in receipt.logs],
                     'status': receipt.status,
                     'contractAddress': receipt.contractAddress,
                     'from': receipt['from']})


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


CONTRACTS_MANAGER_ABI = get_abi_for_contract_version('ContractsManager', 'latest', allow_cache=True)
PROPOSAL_CONTRACT_ABI = get_abi_for_contract_version('Proposal', 'latest', allow_cache=True)


def tx_receipt(tx_hash):
    return WEB3.eth.get_transaction_receipt(tx_hash)


def deploy_proxy_contract(name, admin, private_key, proxy='MyTransparentUpgradeableProxy'):
    logic_contract, tx_hash = deploy_contract_version_and_wait(
        name,
        'latest',
        private_key=private_key,
        allow_cache=True)
    proxy_contract, proxy_tx_hash = deploy_contract_version_and_wait(
        'base/%s' % proxy,
        'latest',
        logic_contract.address,
        *([admin] if admin else []),
        b'',
        private_key=private_key,
        allow_cache=True)
    proxy_contract = EthContract(proxy_contract.address, logic_contract.abi, private_key=private_key)
    return logic_contract, proxy_contract


def initial_deploy_gs_contracts(token_name, token_symbol, fm_supply, token_buffer_amount, private_key):
    contracts_manager_logic, contracts_manager_contract = \
        deploy_proxy_contract('ContractsManager',
                              admin=None,
                              private_key=private_key,
                              proxy='SelfAdminTransparentUpgradeableProxy')

    contracts = {
        'Delegates': {'args': []},
        'FundsManager': {'args': []},
        'TokenSell': {'args': []},
        'Proposal': {'args': [GITSWARM_ACCOUNT_ADDRESS]},
        'GasStation': {'args': []},
        'GitSwarmToken': {'args': [token_name, token_symbol, GS_PROJECT_DB_ID, fm_supply, token_buffer_amount]},
    }

    for name, details in contracts.items():
        logic_contract, proxy_contract = deploy_proxy_contract(name,
                                                               admin=contracts_manager_contract.address,
                                                               private_key=private_key)
        contracts[name]['logic'] = logic_contract
        contracts[name]['proxy'] = proxy_contract

    contracts = {
        'ContractsManager': {'proxy': contracts_manager_contract,
                             'logic': contracts_manager_logic,
                             'args': []
                             },
        **contracts}

    contracts['Token'] = contracts['GitSwarmToken']
    del contracts['GitSwarmToken']

    contract_addresses = [
        contracts['Delegates']['proxy'].address,
        contracts['FundsManager']['proxy'].address,
        contracts['TokenSell']['proxy'].address,
        contracts['Proposal']['proxy'].address,
        contracts['GasStation']['proxy'].address,
        contracts['ContractsManager']['proxy'].address,
    ]
    for name, details in contracts.items():
        details['proxy'].initialize(*details['args'], *contract_addresses, private_key=private_key)

    return contracts


GS_PROJECT_ID = 0


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


expandable_token = compile_contract(get_contract_file_path('ExpandableSupplyToken', 'latest'), allow_cache=True)
fixed_supply_token = compile_contract(get_contract_file_path('FixedSupplyToken', 'latest'), allow_cache=True)
