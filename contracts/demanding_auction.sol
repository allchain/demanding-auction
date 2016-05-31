import 'token-auction/splitting_auction.sol';

contract DemandingAuctionManager is SplitUser {
    uint constant INFINITY = 2 ** 256 - 1;

    function newDemandingReverseAuction( address beneficiary
                                       , ERC20 selling
                                       , ERC20 buying
                                       , uint buy_amount
                                       , uint min_decrease
                                       , uint duration
                                       )
        returns (uint, uint)
    {
        Auction memory A;
        A.creator = msg.sender;
        A.beneficiary = beneficiary;
        A.selling = selling;
        A.buying = buying;
        A.sell_amount = INFINITY;
        A.start_bid = buy_amount;
        A.min_decrease = min_decrease;
        A.expiration = getTime() + duration;
        A.reversed = true;

        _auctions[++_last_auction_id] = A;

        // create the base auctionlet
        var base_id = newAuctionlet({auction_id: _last_auction_id,
                                     bid:         A.start_bid,
                                     quantity:    A.sell_amount,
                                     last_bidder: A.beneficiary,
                                     base:        true
                                   });

        return (_last_auction_id, base_id);
    }
}
