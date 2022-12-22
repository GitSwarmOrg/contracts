// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity ^0.8.0;

import "./base/ERC20interface.sol";
import "./base/Constants.sol";
import "./base/Common.sol";
import "./FundsManager.sol";
import "./Proposal.sol";

contract TokenSell is Constants, Common {

    mapping(uint => mapping(uint => AuctionProposal)) public auctionProposals;

    event ExecuteProposal(uint projectId, uint proposalId);
    event BuyAuction(uint projectId, uint proposalId, uint totalEthReceived, address buyerAddress);
    event ClaimAuction(uint projectId, uint proposalId, uint totalEthReceived, address claimerAddress);
    event WithdrawAuction(uint projectId, uint proposalId, uint totalEthReceived, address claimerAddress, uint amountLeft);
    event SetStartTimeForAuction(uint projectId, uint proposalId, uint64 auctionStartTime);
    event SetEndTimeForAuction(uint projectId, uint proposalId, uint64 auctionEndTime);
    event AuctionCompleted(uint projectId, uint proposalId);
    event TokensSentBack(uint projectId, uint proposalId);

    struct AuctionProposal {
        address tokenToSell;
        uint nbOfTokens;
        uint minimumWei;
        uint totalEthReceived;
        uint totalEthClaimed;
        uint64 auctionStartTime;
        uint64 auctionEndTime;
        bool canBuy;
        bool tokensSentBack;
        mapping(address => uint) buyersAmounts;
    }

    constructor(address contractsManagerAddress) {
        contractsManager = ContractsManager(contractsManagerAddress);
    }

    function proposeAuctionTokenSell(uint projectId, address tokenToSell, uint nbOfTokens, uint minimumWei, uint64 auctionStartTime, uint64 auctionEndTime) public {
        require(tokenToSell != address(0x0));
        require(block.timestamp < auctionStartTime && auctionStartTime < auctionEndTime);
        require(nbOfTokens > 0, "nbOfTokens has to be greater than 0");

        Proposal proposalContract = Proposal(contractsManager.contracts(projectId, PROPOSAL));
        auctionProposals[projectId][proposalContract.nextProposalId(projectId)].auctionStartTime = auctionStartTime;
        auctionProposals[projectId][proposalContract.nextProposalId(projectId)].auctionEndTime = auctionEndTime;
        auctionProposals[projectId][proposalContract.nextProposalId(projectId)].tokenToSell = tokenToSell;
        auctionProposals[projectId][proposalContract.nextProposalId(projectId)].nbOfTokens = nbOfTokens;
        auctionProposals[projectId][proposalContract.nextProposalId(projectId)].minimumWei = minimumWei;
        auctionProposals[projectId][proposalContract.nextProposalId(projectId)].totalEthClaimed = 0;
        proposalContract.createProposal(projectId, AUCTION, msg.sender);
    }

    function executeProposal(uint projectId, uint proposalId) public {
        Proposal proposalContract = Proposal(contractsManager.contracts(projectId, PROPOSAL));
        (uint32 typeOfProposal, uint256 endTime, bool votingAllowed, bool willExecute,) = proposalContract.proposals(projectId, proposalId);
        (uint expirationPeriod,,) = proposalContract.parameters(0, keccak256("ExpirationPeriod"));
        require(proposalId < proposalContract.nextProposalId(projectId), "Proposal does not exist");
        require(endTime <= block.timestamp, "Can't execute proposal, buffer time did not end yet");
        require(endTime + expirationPeriod >= block.timestamp, "Can't execute proposal, execute period has expired");
        require(willExecute, "Can't execute, proposal was rejected or vote count was not locked");
        proposalContract.setWillExecute(projectId, proposalId, false);

        if (typeOfProposal == AUCTION) {
            proposalContract.setActive(projectId, proposalId, false);
            auctionProposals[projectId][proposalId].canBuy = true;
            FundsManager fundsManagerContract = FundsManager(payable(contractsManager.contracts(projectId, FUNDS_MANAGER)));
            fundsManagerContract.sendToken(projectId, auctionProposals[projectId][proposalId].tokenToSell, address(this), auctionProposals[projectId][proposalId].nbOfTokens);

        } else {
            revert('Unexpected proposal type');
        }
        emit ExecuteProposal(projectId, proposalId);
    }

    function buyAuction(uint projectId, uint proposalId) payable public {
        require(msg.value > 0, "Must send Ether to buy auction");
        require(auctionProposals[projectId][proposalId].auctionStartTime <= block.timestamp, "Auction has not started yet");
        require(auctionProposals[projectId][proposalId].auctionEndTime >= block.timestamp, "Auction already ended");
        require(auctionProposals[projectId][proposalId].canBuy, "Auction Proposal is not active");

        auctionProposals[projectId][proposalId].buyersAmounts[msg.sender] += msg.value;
        auctionProposals[projectId][proposalId].totalEthReceived += msg.value;
        emit BuyAuction(projectId, proposalId, auctionProposals[projectId][proposalId].totalEthReceived, msg.sender);
    }

    function withdrawAuction(uint projectId, uint proposalId, uint withdrawAmount) public {
        require(auctionProposals[projectId][proposalId].auctionStartTime <= block.timestamp, "Auction has not started yet");
        require(auctionProposals[projectId][proposalId].auctionEndTime >= block.timestamp, "Auction already ended");
        require(auctionProposals[projectId][proposalId].canBuy, "Auction Proposal is not active");
        require(auctionProposals[projectId][proposalId].buyersAmounts[msg.sender] >= withdrawAmount, "You can not withdraw this amount, try less");

        auctionProposals[projectId][proposalId].buyersAmounts[msg.sender] -= withdrawAmount;
        auctionProposals[projectId][proposalId].totalEthReceived -= withdrawAmount;
        payable(msg.sender).transfer(withdrawAmount);

        emit WithdrawAuction(projectId, proposalId, auctionProposals[projectId][proposalId].totalEthReceived, msg.sender, auctionProposals[projectId][proposalId].buyersAmounts[msg.sender]);
    }

    //TODO:delete this before production
    //really
    //dont forget
    function setEndTimeAuction(uint projectId, uint proposalId) public {
        auctionProposals[projectId][proposalId].auctionEndTime = uint64(block.timestamp);
        emit SetEndTimeForAuction(projectId, proposalId, auctionProposals[projectId][proposalId].auctionEndTime);
    }

    function setStartTimeAuction(uint projectId, uint proposalId) public {
        auctionProposals[projectId][proposalId].auctionStartTime = uint64(block.timestamp);
        emit SetStartTimeForAuction(projectId, proposalId, auctionProposals[projectId][proposalId].auctionStartTime);
    }
    //ok?
    //ok

    function auctionAmountForBuyer(uint projectId, uint proposalId, address addr) public view returns (uint){
        return auctionProposals[projectId][proposalId].buyersAmounts[addr];
    }

    function claimAuction(uint projectId, uint proposalId) public {
        require(auctionProposals[projectId][proposalId].canBuy, "Auction Proposal is not active");
        require(auctionProposals[projectId][proposalId].auctionEndTime <= block.timestamp, "Auction can not be claimed yet");
        require(auctionProposals[projectId][proposalId].buyersAmounts[msg.sender] > 0, "You did not buy this auction");
        uint amount = auctionProposals[projectId][proposalId].buyersAmounts[msg.sender];
        if (auctionProposals[projectId][proposalId].totalEthReceived < auctionProposals[projectId][proposalId].minimumWei) {
            auctionProposals[projectId][proposalId].buyersAmounts[msg.sender] = 0;
            payable(msg.sender).transfer(amount);
        } else {
            uint amount_percentage;
            uint amount_to_send;
            address payable funds_manager = payable(contractsManager.contracts(projectId, FUNDS_MANAGER));
            FundsManager fundsManagerContract = FundsManager(funds_manager);
            auctionProposals[projectId][proposalId].buyersAmounts[msg.sender] = 0;
            amount_percentage = amount * 10 ** 21 / auctionProposals[projectId][proposalId].totalEthReceived;
            amount_to_send = amount_percentage * auctionProposals[projectId][proposalId].nbOfTokens / 10 ** 21;
            fundsManagerContract.depositEth{value : amount}(projectId);

            ERC20interface tokenContract = ERC20interface(auctionProposals[projectId][proposalId].tokenToSell);
            require(tokenContract.transfer(msg.sender, amount_to_send), "Token transfer failed");
        }
        auctionProposals[projectId][proposalId].totalEthClaimed += amount;

        emit ClaimAuction(projectId, proposalId, auctionProposals[projectId][proposalId].totalEthReceived, msg.sender);
        if (auctionProposals[projectId][proposalId].totalEthClaimed == auctionProposals[projectId][proposalId].totalEthReceived) {
            if (auctionProposals[projectId][proposalId].totalEthReceived < auctionProposals[projectId][proposalId].minimumWei && auctionProposals[projectId][proposalId].tokensSentBack) {
                Proposal proposalContract = Proposal(contractsManager.contracts(projectId, PROPOSAL));
                delete auctionProposals[projectId][proposalId];
                proposalContract.deleteProposal(projectId, proposalId);
            }
            emit AuctionCompleted(projectId, proposalId);
        }
    }

    function massClaimAuction(uint projectId, uint proposalId, address[] memory claimers) public {
        require(auctionProposals[projectId][proposalId].canBuy, "Auction Proposal is not active");
        require(auctionProposals[projectId][proposalId].auctionEndTime <= block.timestamp, "Auction can not be claimed yet");
        uint amount = 0;
        if (auctionProposals[projectId][proposalId].totalEthReceived < auctionProposals[projectId][proposalId].minimumWei) {
            for (uint i = 0; i < claimers.length; i++) {
                uint buyer_amount = auctionProposals[projectId][proposalId].buyersAmounts[claimers[i]];
                auctionProposals[projectId][proposalId].buyersAmounts[claimers[i]] = 0;
                payable(claimers[i]).transfer(buyer_amount);
                amount += buyer_amount;
                emit ClaimAuction(projectId, proposalId, auctionProposals[projectId][proposalId].totalEthReceived, claimers[i]);
            }
        } else {
            for (uint i = 0; i < claimers.length; i++) {
                uint amount_percentage;
                uint amount_to_send;
                uint buyer_amount = auctionProposals[projectId][proposalId].buyersAmounts[claimers[i]];
                address payable funds_manager = payable(contractsManager.contracts(projectId, FUNDS_MANAGER));
                FundsManager fundsManagerContract = FundsManager(funds_manager);
                auctionProposals[projectId][proposalId].buyersAmounts[claimers[i]] = 0;
                amount_percentage = buyer_amount * 10 ** 21 / auctionProposals[projectId][proposalId].totalEthReceived;
                amount_to_send = amount_percentage * auctionProposals[projectId][proposalId].nbOfTokens / 10 ** 21;
                fundsManagerContract.depositEth{value : buyer_amount}(projectId);

                ERC20interface tokenContract = ERC20interface(auctionProposals[projectId][proposalId].tokenToSell);
                require(tokenContract.transfer(claimers[i], amount_to_send), "Token transfer failed");
                amount += buyer_amount;
                emit ClaimAuction(projectId, proposalId, auctionProposals[projectId][proposalId].totalEthReceived, claimers[i]);
            }
        }
        auctionProposals[projectId][proposalId].totalEthClaimed += amount;

        if (auctionProposals[projectId][proposalId].totalEthClaimed == auctionProposals[projectId][proposalId].totalEthReceived) {
            if (auctionProposals[projectId][proposalId].totalEthReceived < auctionProposals[projectId][proposalId].minimumWei && auctionProposals[projectId][proposalId].tokensSentBack) {
                Proposal proposalContract = Proposal(contractsManager.contracts(projectId, PROPOSAL));
                delete auctionProposals[projectId][proposalId];
                proposalContract.deleteProposal(projectId, proposalId);
            }
            emit AuctionCompleted(projectId, proposalId);
        }
    }

    function sendAuctionTokensBack(uint projectId, uint proposalId) public {
        require(auctionProposals[projectId][proposalId].canBuy, "Auction Proposal is not active");
        require(auctionProposals[projectId][proposalId].auctionEndTime <= block.timestamp, "Auction is still active, cannot send tokens back to FundsManager");
        require(auctionProposals[projectId][proposalId].totalEthReceived < auctionProposals[projectId][proposalId].minimumWei, "Minimum wei has been reached, cannot send tokens back to FundsManager");
        require(!auctionProposals[projectId][proposalId].tokensSentBack, "Tokens already sent back to FundsManager");
        auctionProposals[projectId][proposalId].tokensSentBack = true;
        ERC20interface tokenContract = ERC20interface(auctionProposals[projectId][proposalId].tokenToSell);
        FundsManager fundsManagerContract = FundsManager(payable(contractsManager.contracts(projectId, FUNDS_MANAGER)));
        require(tokenContract.transfer(contractsManager.contracts(projectId, FUNDS_MANAGER), auctionProposals[projectId][proposalId].nbOfTokens), "Token transfer failed");
        fundsManagerContract.updateBalance(projectId, auctionProposals[projectId][proposalId].tokenToSell, auctionProposals[projectId][proposalId].nbOfTokens);
        if (auctionProposals[projectId][proposalId].totalEthClaimed == auctionProposals[projectId][proposalId].totalEthReceived) {
            if (auctionProposals[projectId][proposalId].totalEthReceived == 0) {
                emit AuctionCompleted(projectId, proposalId);
            }
            Proposal proposalContract = Proposal(contractsManager.contracts(projectId, PROPOSAL));
            delete auctionProposals[projectId][proposalId];
            proposalContract.deleteProposal(projectId, proposalId);
        }
        emit TokensSentBack(projectId, proposalId);
    }

}
