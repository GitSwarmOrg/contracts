// SPDX-License-Identifier: MIT
// (c) 2022+ GitSwarm
// This code is licensed under MIT license (see LICENSE.txt for details)
pragma solidity 0.8.20;

import "./base/ERC20interface.sol";
import "./base/Common.sol";

contract TokenSell is Common, Initializable, ITokenSell {
    using Address for address payable;

    mapping(uint => mapping(uint => AuctionProposal)) public auctionProposals;

    event ExecuteProposal(uint projectId, uint proposalId);
    event BuyAuction(uint projectId, uint proposalId, uint totalEthReceived, address buyerAddress);
    event ClaimAuction(uint projectId, uint proposalId, uint totalEthReceived, address claimerAddress);
    event WithdrawAuction(uint projectId, uint proposalId, uint totalEthReceived, address claimerAddress, uint amountLeft);
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

    function initialize(
        address _delegates,
        address _fundsManager,
        address _tokenSell,
        address _proposal,
        address _gasStation,
        address _contractsManager
    ) public initializer {
        _init(_delegates, _fundsManager, _tokenSell, _proposal, _gasStation, _contractsManager);
    }

    function proposeAuctionTokenSell(uint projectId, address tokenToSell, uint nbOfTokens, uint minimumWei, uint64 auctionStartTime, uint64 auctionEndTime) public {
        require(tokenToSell != address(0));
        require(block.timestamp < auctionStartTime && auctionStartTime < auctionEndTime);
        require(nbOfTokens > 0, "nbOfTokens has to be greater than 0");

        uint n_id = proposalContract.nextProposalId(projectId);

        AuctionProposal storage p = auctionProposals[projectId][n_id];
        p.auctionStartTime = auctionStartTime;
        p.auctionEndTime = auctionEndTime;
        p.tokenToSell = tokenToSell;
        p.nbOfTokens = nbOfTokens;
        p.minimumWei = minimumWei;
        p.totalEthClaimed = 0;

        proposalContract.createProposal(projectId, AUCTION, msg.sender);
    }

    function executeProposal(uint projectId, uint proposalId) public {
        (uint32 typeOfProposal,, bool willExecute,, uint256 endTime) = proposalContract.proposals(projectId, proposalId);
        uint expirationPeriod = proposalContract.parameters(0, keccak256("ExpirationPeriod"));
        require(proposalId < proposalContract.nextProposalId(projectId), "Proposal does not exist");
        require(endTime <= block.timestamp, "Can't execute proposal, buffer time did not end yet");
        require(endTime + expirationPeriod >= block.timestamp, "Can't execute proposal, execute period has expired");
        require(willExecute, "Can't execute, proposal was rejected or vote count was not locked");
        proposalContract.setWillExecute(projectId, proposalId, false);

        AuctionProposal storage p = auctionProposals[projectId][proposalId];
        if (typeOfProposal == AUCTION) {
            proposalContract.setActive(projectId, proposalId, false);
            p.canBuy = true;
            fundsManagerContract.sendToken(projectId, p.tokenToSell, address(this), p.nbOfTokens);

        } else {
            revert('Unexpected proposal type');
        }
        emit ExecuteProposal(projectId, proposalId);
    }

    function buyAuction(uint projectId, uint proposalId) payable public {
        AuctionProposal storage p = auctionProposals[projectId][proposalId];
        require(msg.value > 0, "Must send Ether to buy auction");
        require(p.auctionStartTime <= block.timestamp, "Auction has not started yet");
        require(p.auctionEndTime >= block.timestamp, "Auction already ended");
        require(p.canBuy, "Auction Proposal is not active");

        p.buyersAmounts[msg.sender] += msg.value;
        p.totalEthReceived += msg.value;
        emit BuyAuction(projectId, proposalId, p.totalEthReceived, msg.sender);
    }

    function withdrawAuction(uint projectId, uint proposalId, uint withdrawAmount) public {
        AuctionProposal storage p = auctionProposals[projectId][proposalId];
        require(p.auctionStartTime <= block.timestamp, "Auction has not started yet");
        require(p.auctionEndTime >= block.timestamp, "Auction already ended");
        require(p.canBuy, "Auction Proposal is not active");
        require(p.buyersAmounts[msg.sender] >= withdrawAmount, "You can not withdraw this amount, try less");

        p.buyersAmounts[msg.sender] -= withdrawAmount;
        p.totalEthReceived -= withdrawAmount;
        payable(msg.sender).sendValue(withdrawAmount);

        emit WithdrawAuction(projectId, proposalId, p.totalEthReceived, msg.sender, p.buyersAmounts[msg.sender]);
    }

    function auctionAmountForBuyer(uint projectId, uint proposalId, address addr) public view returns (uint){
        return auctionProposals[projectId][proposalId].buyersAmounts[addr];
    }

    function claimAuction(uint projectId, uint proposalId) public {
        AuctionProposal storage p = auctionProposals[projectId][proposalId];
        require(p.canBuy, "Auction Proposal is not active");
        require(p.auctionEndTime <= block.timestamp, "Auction can not be claimed yet");
        require(p.buyersAmounts[msg.sender] > 0, "You did not buy this auction");
        uint amount = p.buyersAmounts[msg.sender];
        if (p.totalEthReceived < p.minimumWei) {
            p.buyersAmounts[msg.sender] = 0;
            payable(msg.sender).sendValue(amount);
        } else {
            uint amount_percentage;
            uint amount_to_send;
            p.buyersAmounts[msg.sender] = 0;
            amount_percentage = amount * 10 ** 21 / p.totalEthReceived;
            amount_to_send = amount_percentage * p.nbOfTokens / 10 ** 21;
            fundsManagerContract.depositEth{value: amount}(projectId);

            ERC20interface tokenContract = ERC20interface(p.tokenToSell);
            require(tokenContract.transfer(msg.sender, amount_to_send), "Token transfer failed");
        }
        p.totalEthClaimed += amount;

        emit ClaimAuction(projectId, proposalId, p.totalEthReceived, msg.sender);
        if (p.totalEthClaimed == p.totalEthReceived) {
            if (p.totalEthReceived < p.minimumWei && p.tokensSentBack) {
                delete auctionProposals[projectId][proposalId];
                proposalContract.deleteProposal(projectId, proposalId);
            }
            emit AuctionCompleted(projectId, proposalId);
        }
    }

    function massClaimAuction(uint projectId, uint proposalId, address[] memory claimers) public {
        AuctionProposal storage p = auctionProposals[projectId][proposalId];
        require(p.canBuy, "Auction Proposal is not active");
        require(p.auctionEndTime <= block.timestamp, "Auction can not be claimed yet");
        uint amount = 0;
        if (p.totalEthReceived < p.minimumWei) {
            for (uint i = 0; i < claimers.length; i++) {
                uint buyer_amount = p.buyersAmounts[claimers[i]];
                p.buyersAmounts[claimers[i]] = 0;
                payable(claimers[i]).sendValue(buyer_amount);
                amount += buyer_amount;
                emit ClaimAuction(projectId, proposalId, p.totalEthReceived, claimers[i]);
            }
        } else {
            for (uint i = 0; i < claimers.length; i++) {
                uint amount_percentage;
                uint amount_to_send;
                uint buyer_amount = p.buyersAmounts[claimers[i]];
                p.buyersAmounts[claimers[i]] = 0;
                amount_percentage = buyer_amount * 10 ** 21 / p.totalEthReceived;
                amount_to_send = amount_percentage * p.nbOfTokens / 10 ** 21;
                fundsManagerContract.depositEth{value: buyer_amount}(projectId);

                ERC20interface tokenContract = ERC20interface(p.tokenToSell);
                require(tokenContract.transfer(claimers[i], amount_to_send), "Token transfer failed");
                amount += buyer_amount;
                emit ClaimAuction(projectId, proposalId, p.totalEthReceived, claimers[i]);
            }
        }
        p.totalEthClaimed += amount;

        if (p.totalEthClaimed == p.totalEthReceived) {
            if (p.totalEthReceived < p.minimumWei && p.tokensSentBack) {
                delete auctionProposals[projectId][proposalId];
                proposalContract.deleteProposal(projectId, proposalId);
            }
            emit AuctionCompleted(projectId, proposalId);
        }
    }

    function sendAuctionTokensBack(uint projectId, uint proposalId) public {
        AuctionProposal storage p = auctionProposals[projectId][proposalId];
        require(p.canBuy, "Auction Proposal is not active");
        require(p.auctionEndTime <= block.timestamp, "Auction is still active, cannot send tokens back to FundsManager");
        require(p.totalEthReceived < p.minimumWei, "Minimum wei has been reached, cannot send tokens back to FundsManager");
        require(!p.tokensSentBack, "Tokens already sent back to FundsManager");
        p.tokensSentBack = true;
        ERC20interface tokenContract = ERC20interface(p.tokenToSell);
        require(tokenContract.transfer(address(fundsManagerContract), p.nbOfTokens), "Token transfer failed");
        fundsManagerContract.updateBalance(projectId, p.tokenToSell, p.nbOfTokens);
        if (p.totalEthClaimed == p.totalEthReceived) {
            if (p.totalEthReceived == 0) {
                emit AuctionCompleted(projectId, proposalId);
            }
            delete auctionProposals[projectId][proposalId];
            proposalContract.deleteProposal(projectId, proposalId);
        }
        emit TokensSentBack(projectId, proposalId);
    }

}
