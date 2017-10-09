pragma solidity ^0.4.4;

import 'token-auction/manager.sol';

contract DemandController {
    function demand(address for_whom, uint amount) public;
}

contract DemandingAuctionManager is AuctionController
                                  , SplittingAuctionFrontend
{
    mapping(uint => DemandController) _suppliers;

    function newDemandingReverseAuction( address beneficiary
                                       , DemandController supplier
                                       , address selling
                                       , address buying
                                       , uint max_inflation
                                       , uint buy_amount
                                       , uint min_decrease
                                       , uint64 ttl
                                       )
        public
        returns (uint auction_id, uint base_id)
    {
        (auction_id, base_id) = _makeGenericAuction({ creator: msg.sender
                                                    , beneficiary: beneficiary
                                                    , selling: ERC20(selling)
                                                    , buying: ERC20(buying)
                                                    , sell_amount: max_inflation
                                                    , start_bid: buy_amount
                                                    , min_increase: 0
                                                    , min_decrease: min_decrease
                                                    , ttl: ttl
                                                    , collection_limit: 0
                                                    , reversed: true
                                                    });

        _suppliers[auction_id] = supplier;

        return (auction_id, base_id);
    }
    // override sell token transfer as we no longer keep escrow
    function takeFundsIntoEscrow(Auction) internal pure {
    }
    function settleExcessSell(Auction, uint) internal pure {
    }
    function settleBidderClaim(Auction A, Auctionlet a) internal {
        // demand the claimable amount from the supplier and then
        // send it to the winning bidder

        // supplier lookup will fail for deleted auctionlet as the
        // auction_id gets set to zero, and ids start from one
        var supplier = _suppliers[a.auction_id];

        // inflate the sell token, sending to this contract
        supplier.demand(this, a.sell_amount);

        // send the newly minted sell token on to the last bidder
        assert(A.selling.transfer(a.last_bidder, a.sell_amount));
    }
    function settleReclaim(Auction) internal pure {
    }
}
