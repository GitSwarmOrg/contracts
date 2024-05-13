import hre from "hardhat";
import {BaseContract, Contract, Numeric} from "ethers";

const ethers = hre.ethers;

const CONTRACTS_INDEX = {
    Token: 0,
    Delegates: 1,
    FundsManager: 2,
    Parameters: 3,
    Proposal: 4,
};

const INDEX_CONTRACTS = {
    0: "Token",
    1: "Delegates",
    2: "FundsManager",
    3: "Parameters",
    4: "Proposal",
};

const CONTRACT_NAMES = Object.fromEntries(Object.entries(CONTRACTS_INDEX).map(([k, v]) => [v, k]));

const UPGRADABLE_CONTRACTS = [
    "Delegates",
    "FundsManager",
    "Parameters",
    "Proposal"
];

const PROJECT_CONTRACTS = [
    "Delegates",
    "FundsManager",
    "Parameters",
    "Proposal",
    "ContractsManager"
];

const PROPOSAL_CONTRACT = {
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
};

class ProposalData<ProposalT> {
    contract: ProposalT;
    projectID: Numeric;
    proposalID: Numeric;

    constructor(contract: ProposalT, projectID: Numeric, proposalID: Numeric) {
        this.contract = contract;
        this.projectID = projectID;
        this.proposalID = proposalID;
    }

    get title(): string {
        return 'No title';
    }

    get description(): string {
        return 'No description';
    }

    async loadData() {
        throw new Error('Not implemented');
    }
}
