import 'dappsys/token/supply_manager.sol';
import 'token-auction/splitting_auction.sol';

contract DemandingAuctionManager is SplitUser {
    uint constant INFINITY = 2 ** 256 - 1;

    struct Auction {
        address creator;
        address beneficiary;
        DSTokenSupplyManager supplier;
        ERC20 selling;
        ERC20 buying;
        uint start_bid;
        uint min_increase;
        uint min_decrease;
        uint sell_amount;
        uint collected;
        uint COLLECT_MAX;
        uint expiration;
        bool reversed;
        uint unsold;
    }
    mapping(uint => Auction) _auctions;

    function newDemandingReverseAuction( address beneficiary
                                       , DSTokenSupplyManager supplier
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
        A.supplier = supplier;
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

        _updateBid(base_id, A.beneficiary, A.sell_amount);

        return (_last_auction_id, base_id);
    }
}
