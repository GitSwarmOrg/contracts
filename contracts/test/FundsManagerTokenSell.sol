pragma solidity ^0.8.0;

import "./ERC20interface.sol";
import "../prod/1.0.0/base/ERC20interface.sol";

contract FundsManagerTokenSell {
    uint constant PERCENTAGE_MULTIPLIER = 10 ** 18;
    address constant BURN_ADDRESS = 0x1111111111111111111111111111111111111111;
    uint constant public ALL_TOKENS = 2 ** 256 - 1;


    mapping(uint => ProposalData) public proposals;
    mapping(uint => TokenSellProposal) public tokenSellProposals;
    mapping(uint => AuctionProposal) public auctionProposals;
    uint public nextProposalId;

    // key - delegated address, value - array of delegators address
    mapping(address => address[]) public delegates;
    // key - delegator address, value - delegated address
    mapping(address => address) public delegators;

    ERC20interface public votingTokenContract;

    enum Proposal {
        TRANSACTION,
        RECURRING_TRANSACTION,
        CREATE_TOKENS,
        TOKEN_SELL,
        CHANGE_PARAMETER,
        DELETE_PROPOSAL,
        AUCTION
    }

    struct Vote {
        uint amountYes;
        uint amountNo;
    }

    struct ProposalData {
        Proposal typeOfProposal;
        uint endTime;
        bool votingAllowed;
        address[] voters;
        mapping(address => Vote) votes;
    }

    struct TokenSellProposal {
        address tokenToSell;
        address tokenToBuyWith;
        uint duration;
        uint endTime;
        uint priceSignificand;
        uint priceExponent;
        uint maxAmount;
        bool canBuy;
    }

    struct AuctionProposal {
        address tokenToSell;
        uint nbOfTokens;
        uint totalEthReceived;
        uint duration;
        uint endTime;
        bool canBuy;
        address[] buyers;
        mapping(address => uint) buyersAmounts;
    }

    event NewProposal(uint id, Proposal proposalType);

    modifier activeProposal(uint id) {
        require(id < nextProposalId && proposals[id].votingAllowed,
            "Proposal does not exist or is inactive");
        _;
    }

    constructor(address _votingTokenContract) public {
        votingTokenContract = ERC20interface(_votingTokenContract);
        parameters[keccak256("VoteDuration")] = 5 seconds;
    }

    function hasVotedAlready(uint id, address addr) public view returns (bool) {
        if (proposals[id].votes[addr].amountYes != 0 || proposals[id].votes[addr].amountNo != 0) {
            return true;
        }
        return false;
    }

    function createProposal(Proposal proposalType) internal {

        proposals[nextProposalId].votingAllowed = true;
        proposals[nextProposalId].voters.push(msg.sender);
        proposals[nextProposalId].votes[msg.sender] = Vote({amountYes : ALL_TOKENS, amountNo : 0});
        proposals[nextProposalId].typeOfProposal = proposalType;
        proposals[nextProposalId].endTime = now + parameters[keccak256("VoteDuration")];
        nextProposalId++;
        NewProposal(nextProposalId - 1, proposalType);
    }


    function proposeTokenSell(address tokenToSell, address tokenToBuyWith, uint duration, uint priceSignificand, uint priceExponent, uint maxAmount) {
        require(tokenToSell != tokenToBuyWith, "Token to sell should be different than the one to buy with");
        if (tokenToSell == 0x0) {
            require(address(this).balance >= maxAmount);
        } else {
            ERC20interface erc20Contract = ERC20interface(tokenToSell);
            require(erc20Contract.balanceOf(this) > maxAmount);
        }
        tokenSellProposals[nextProposalId].tokenToSell = tokenToSell;
        tokenSellProposals[nextProposalId].tokenToBuyWith = tokenToBuyWith;
        tokenSellProposals[nextProposalId].duration = duration;
        tokenSellProposals[nextProposalId].priceSignificand = priceSignificand;
        tokenSellProposals[nextProposalId].priceExponent = priceExponent;
        tokenSellProposals[nextProposalId].maxAmount = maxAmount;

        createProposal(Proposal.TOKEN_SELL);
    }

    function proposeAuctionTokenSell(address tokenToSell, uint nbOfTokens, uint duration) public {
        auctionProposals[nextProposalId].duration = duration;
        auctionProposals[nextProposalId].tokenToSell = tokenToSell;
        createProposal(Proposal.AUCTION);
    }

    function voteProposalId(uint id, bool vote) activeProposal(id) public {
        if (vote) {
            voteWithAmount(id, ALL_TOKENS, 0);
        } else {
            voteWithAmount(id, 0, ALL_TOKENS);
        }
    }

    function voteWithAmount(uint id, uint amountYes, uint amountNo) activeProposal(id) public {
        if (hasVotedAlready(id, msg.sender) == false) {
            proposals[id].voters.push(msg.sender);
        }
        proposals[id].votes[msg.sender] = Vote({amountYes : amountYes, amountNo : amountNo});
    }

    function() payable public {
    }

    function removeIfAlreadyDelegated() private {
        if (delegators[msg.sender] != address(0)) {
            undelegate();
        }
    }

    function delegate(address delegatedAddr) public {
        require(delegatedAddr != msg.sender && delegators[delegatedAddr] != msg.sender);
        //check if it is already delegated
        removeIfAlreadyDelegated();

        delegates[delegatedAddr].push(msg.sender);
        delegators[msg.sender] = delegatedAddr;
    }

    function undelegate() public {
        undelegateAddress(msg.sender);
    }

    function undelegateAddress(address addr) private {
        //when the entry is removed, copy the last element in it's position and reduce the length with 1
        address[] delegates_array = delegates[delegators[addr]];
        for (uint i = 0; i < delegates_array.length; i++) {
            if (delegates_array[i] == addr) {
                delegates_array[i] = delegates_array[delegates_array.length - 1];
                delegates_array.length = delegates_array.length - 1;
            }
        }
        delete delegators[addr];
    }

    function undelegateAllFromAddress() public {
        for (uint i = 0; i < delegates[msg.sender].length; i++) {
            delete delegators[delegates[msg.sender][i]];
            delete delegates[msg.sender][i];
        }
        delegates[msg.sender].length = 0;
    }

    function removeUnwantedDelegates(address delegatedAddr, uint id) public {
        address[] delegates_array = delegates[delegatedAddr];
        for (uint i = 0; i < delegates_array.length; i++) {
            uint delegated_amount = 0;
            for (uint j = 0; j < delegates[delegates_array[i]].length; j++) {
                uint balance_of = votingTokenContract.balanceOf(delegates[delegates_array[i]][j]);
                if (balance_of < 2) {
                    undelegateAddress(delegates[delegates_array[i]][j]);
                    j--;
                } else delegated_amount += balance_of;
            }

            uint balance = votingTokenContract.balanceOf(delegates_array[i]) + delegated_amount;
            if (balance < 2) {
                undelegateAddress(delegates_array[i]);
                i--;
            }
        }
    }

    function countDelegatedVotes(address delegatedAddr, uint id) public view returns (uint delegatedVotes) {
        for (uint i = 0; i < delegates[delegatedAddr].length; i++) {
            if (delegates[delegatedAddr][i] != address(0) && hasVotedAlready(id, delegates[delegatedAddr][i]) == false) {
                delegatedVotes += votingTokenContract.balanceOf(delegates[delegatedAddr][i]);
                //check second level(actual accounts with tokens)
                for (uint j = 0; j < delegates[delegates[delegatedAddr][i]].length; j++) {
                    if (delegates[delegates[delegatedAddr][i]][j] != address(0) && hasVotedAlready(id, delegates[delegates[delegatedAddr][i]][j]) == false) {
                        delegatedVotes += votingTokenContract.balanceOf(delegates[delegates[delegatedAddr][i]][j]);
                    }
                }
            }
        }
    }

    function calculateTotalVotingPower(address Addr, uint id) view private returns (uint) {
        return votingTokenContract.balanceOf(Addr) + countDelegatedVotes(Addr, id);
    }

    function adjustAmount(uint actualAmount, uint amountYes, uint amountNo) private pure returns (uint, uint) {
        uint actualAmountYes = 0;
        uint actualAmountNo = 0;
        if (amountYes > 0 && actualAmount > 0) {
            actualAmountYes = (amountYes * actualAmount) / (amountYes + amountNo);
        }
        actualAmountNo = actualAmount - actualAmountYes;

        return (actualAmountYes, actualAmountNo);
    }

    function checkVoteCount(uint id) private view returns (bool) {
        uint yesVotes;
        uint noVotes;
        for (uint i = 0; i < proposals[id].voters.length; i++) {
            if (proposals[id].votes[proposals[id].voters[i]].amountYes == ALL_TOKENS) {
                yesVotes += calculateTotalVotingPower(proposals[id].voters[i], id);
            } else if (proposals[id].votes[proposals[id].voters[i]].amountNo == ALL_TOKENS) {
                noVotes += calculateTotalVotingPower(proposals[id].voters[i], id);
            } else {
                //case for site address(or vote with amount)
                //adjust the amount for votes if the actual amount is smaller
                uint amountYes = proposals[id].votes[proposals[id].voters[i]].amountYes;
                uint amountNo = proposals[id].votes[proposals[id].voters[i]].amountNo;
                uint actualAmount = calculateTotalVotingPower(proposals[id].voters[i], id);
                if (actualAmount < (amountYes + amountNo)) {
                    (amountYes, amountNo) = adjustAmount(actualAmount, amountYes, amountNo);
                }
                yesVotes += amountYes;
                noVotes += amountNo;
            }
        }

        return yesVotes > noVotes;
    }

    function executeProposal(uint id) activeProposal(id) public {
        require(proposals[id].endTime + proposalContract.parameters(keccak256("BufferBetweenEndOfVotingAndExecuteProposal")) <= block.timestamp, "Can't execute proposal, voting is ongoing");

        if (checkVoteCount(id)) {
            if (proposals[id].typeOfProposal == Proposal.TOKEN_SELL) {
                tokenSellProposals[id].endTime = now + tokenSellProposals[id].duration;
                tokenSellProposals[id].canBuy = true;
            } else if (proposals[id].typeOfProposal == Proposal.AUCTION) {
                auctionProposals[id].endTime = now + tokenSellProposals[id].duration;
                auctionProposals[id].canBuy = true;
            }
        }
    }


    function reclaimFunds(uint votingTokenAmount, address[] tokenContractsAddresses) public {
        require(votingTokenContract.allowance(msg.sender, this) >= votingTokenAmount && votingTokenAmount <= votingTokenContract.balanceOf(msg.sender));
        uint percentage = votingTokenAmount * PERCENTAGE_MULTIPLIER / (votingTokenContract.totalSupply() - votingTokenContract.balanceOf(BURN_ADDRESS));
        uint tokenAmount;
        ERC20interface tokenContract;
        votingTokenContract.transferFrom(msg.sender, BURN_ADDRESS, votingTokenAmount);
        for (uint i = 0; i < tokenContractsAddresses.length; i++) {
            if (tokenContractsAddresses[i] != address(votingTokenContract)) {
                tokenContract = ERC20interface(tokenContractsAddresses[i]);
                tokenAmount = percentage * tokenContract.balanceOf(this) / PERCENTAGE_MULTIPLIER;
                tokenContract.transfer(msg.sender, tokenAmount);
            }
        }
        uint ethAmount = percentage * address(this).balance / PERCENTAGE_MULTIPLIER;
       payable(msg.sender).transfer(ethAmount);
    }

    function buy(uint id, uint amount) payable public {
        if (tokenSellProposals[id].endTime <= now) {
            tokenSellProposals[id].canBuy = false;
        }
        require(tokenSellProposals[id].canBuy == true, "This token sell is not available");
        require(tokenSellProposals[id].maxAmount >= amount, "Amount is bigger than available");
        uint cost = amount * tokenSellProposals[id].priceSignificand / 10 ** tokenSellProposals[id].priceExponent;
        require(cost > 0, "Requested amount is too small");
        if (tokenSellProposals[id].tokenToSell == 0x0) {
            ERC20interface erc20ContractBuy = ERC20interface(tokenSellProposals[id].tokenToBuyWith);
            if (erc20ContractBuy.allowance(msg.sender, address(this)) == cost) {
                tokenSellProposals[id].maxAmount -= amount;
                bool result = erc20ContractBuy.transferFrom(msg.sender, address(this), cost);
                if (result == false) {
                    revert();
                }
               payable(msg.sender).transfer(amount);
            } else revert();
        } else if (tokenSellProposals[id].tokenToBuyWith == 0x0) {
            if (msg.value == cost) {
                ERC20interface erc20ContractSell = ERC20interface(tokenSellProposals[id].tokenToSell);
                tokenSellProposals[id].maxAmount -= amount;
                erc20ContractSell.transfer(msg.sender, amount);
            } else revert();
        } else {
            erc20ContractBuy = ERC20interface(tokenSellProposals[id].tokenToBuyWith);
            if (erc20ContractBuy.allowance(msg.sender, address(this)) == cost) {
                erc20ContractSell = ERC20interface(tokenSellProposals[id].tokenToSell);
                tokenSellProposals[id].maxAmount -= amount;
                erc20ContractBuy.transferFrom(msg.sender, address(this), cost);
                erc20ContractSell.transfer(msg.sender, amount);
            } else revert();
        }
    }

    function buyAuction(uint id) payable public {
        if (auctionProposals[id].endTime <= now) {
            auctionProposals[id].canBuy = false;
        }
        require(tokenSellProposals[id].canBuy == true, "This token sell is not available");
        auctionProposals[id].buyers.push(msg.sender);
        auctionProposals[id].buyersAmounts[msg.sender] = msg.value;
        auctionProposals[id].totalEthReceived += msg.value;
    }

    function executeAuction(uint id) public {
        require(auctionProposals[id].endTime >= now);
        auctionProposals[id].canBuy = false;
        uint amount;
        uint amount_percentage;
        uint amount_to_send;
        for (uint i = 0; i < auctionProposals[id].buyers.length; i++) {
            amount = auctionProposals[id].buyersAmounts[auctionProposals[id].buyers[i]];
            amount_percentage = amount * 100 / auctionProposals[id].totalEthReceived;
            amount_to_send = amount_percentage * auctionProposals[id].nbOfTokens / 100;
            ERC20interface erc20ContractSell = ERC20interface(auctionProposals[id].tokenToSell);
            erc20ContractSell.transfer(auctionProposals[id].buyers[i], amount_to_send);
        }
    }
}
