// SPDX-License-Identifier: GPL-2.0
pragma solidity >=0.7.0 < 0.9.0;

contract Auction {
    // Parameters of the Auction
    address payable public beneficiary; //owner
    uint public auctionEndTime;

    // Current state of the auctionEndTime
    address public highestBidder;
    uint public highestBid;

    mapping(address => uint) public all_bidders;

    mapping(address => uint) public pendingReturns;
    address[] public all_addresses;

    bool public ended = false;

    event HighestBidIncrease(address bidder, uint amount);
    event AucitionEnded(address winner, uint amount);

    constructor(uint _biddingTime, address payable _beneficiary) {
        beneficiary = _beneficiary;
        auctionEndTime = block.timestamp + _biddingTime;
    }

    function bid() public payable {
        if(block.timestamp > auctionEndTime) {
            revert ("The auction has already ended");
        }

        if(msg.value <= highestBid) {
            revert("There is already a higher or equal bid");
        }

        if(highestBid != 0) {
            pendingReturns[highestBidder] += highestBid;
        }
        all_addresses.push(msg.sender);
        all_bidders[msg.sender] = msg.value;
        highestBidder = msg.sender;
        highestBid = msg.value;
        emit HighestBidIncrease(msg.sender, msg.value);
    }

    function withdraw() public returns(bool) {
        uint amount = pendingReturns[msg.sender];
        if(amount > 0) {
            pendingReturns[msg.sender] = 0;

            if(!payable(msg.sender).send(amount)) {
                pendingReturns[msg.sender] = amount;
                return false;
            }
        }
        all_bidders[msg.sender] = 0;
        return true;
    }

    function auctionEnd() public {
        if(block.timestamp < auctionEndTime) {
            revert ("The auction has not ended yet");
        }

        if(ended) {
            revert("The function auctionEnded has already been called");
        }

        for(uint i = 0; i < all_addresses.length; i++) {
            address current_address = all_addresses[i];
            if (current_address != highestBidder) {
                uint amount = pendingReturns[current_address];
                payable(current_address).transfer(amount);
            }
        }

        ended = true;
        emit AucitionEnded(highestBidder, highestBid);
        beneficiary.transfer(highestBid);
    }

    function is_bidder(address payable check) public view returns(bool) {
        return all_bidders[check] > 0;
    }

    //+1

    function getRestTime() public view returns(uint) {
        return auctionEndTime - block.timestamp;
    }
}

contract ActionHouse {
    Auction[] public auctions;

    event NewBid(uint auction_index, uint bid_amount);

    function create_auction(uint biddingTime, address payable beneficiary) external returns(uint)  {
        Auction auction = new Auction(biddingTime, beneficiary);
        auctions.push(auction);
        return auctions.length - 1;
    }

    function get_auction_address(uint auction_index) public view returns(address) {
        return address(auctions[auction_index]);
    }

    function bid(uint auction_index) external payable {
        auctions[auction_index].bid();
        emit NewBid(auction_index, msg.value);
    }

    function all_auctions() external view returns(Auction[] memory) {
        return auctions;
    }

    function all_open_auctions() external view returns(Auction[] memory) {
        //cannot make dynamic arrays here. Have to create oversized array, then copy to correct size
        Auction[] memory oversized = new Auction[](auctions.length);
        uint count = 0;
        for(uint i = 0; i < auctions.length; i++) {
            //ignore if closed and if auction ended without bids
            if(!auctions[i].ended() &&
                !(block.timestamp > auctions[i].auctionEndTime() && auctions[i].highestBid() == 0)) {
                oversized[count] = auctions[i];
                count++;
            }
        }

        Auction[] memory ret = new Auction[](count);
        for(uint i = 0; i < count; i++) {
            ret[i] = oversized[i];
        }

        return ret;
    }

    function all_auctions_for_seller(address payable seller) external view returns(Auction[] memory) {
        //cannot make dynamic arrays here. Have to create oversized array, then copy to correct size
        Auction[] memory oversized = new Auction[](auctions.length);
        uint count = 0;
        for(uint i = 0; i < auctions.length; i++) {
            if(auctions[i].beneficiary() == seller) {
                oversized[count] = auctions[i];
                count++;
            }
        }

        Auction[] memory ret = new Auction[](count);
        for(uint i = 0; i < count; i++) {
            ret[i] = oversized[i];
        }

        return ret;
    }

    function all_auctions_for_bidder(address payable bidder) external view returns(Auction[] memory) {
        //cannot make dynamic arrays here. Have to create oversized array, then copy to correct size
        Auction[] memory oversized = new Auction[](auctions.length);
        uint count = 0;
        for(uint i = 0; i < auctions.length; i++) {
            if(auctions[i].is_bidder(bidder)) {
                oversized[count] = auctions[i];
                count++;
            }
        }

        Auction[] memory ret = new Auction[](count);
        for(uint i = 0; i < count; i++) {
            ret[i] = oversized[i];
        }

        return ret;
    }

}