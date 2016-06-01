import 'dappsys/token/supply_manager.sol';
import 'token-auction/splitting_auction.sol';

contract DemandingAuctionManager is SplittableAuctionManager {
    mapping(uint => DSTokenSupplyManager) _suppliers;

    function newDemandingReverseAuction( address beneficiary
                                       , DSTokenSupplyManager supplier
                                       , ERC20 selling
                                       , ERC20 buying
                                       , uint buy_amount
                                       , uint min_decrease
                                       , uint duration
                                       )
        returns (uint auction_id, uint base_id)
    {
        (auction_id, base_id) = _newTwoWayAuction({ creator: msg.sender
                                                  , beneficiary: beneficiary
                                                  , selling: selling
                                                  , buying: buying
                                                  , sell_amount: INFINITY
                                                  , start_bid: buy_amount
                                                  , min_increase: 0
                                                  , min_decrease: min_decrease
                                                  , duration: duration
                                                  , COLLECT_MAX: 0
                                                  });

        Auction A = _auctions[auction_id];
        A.reversed = true;

        _suppliers[auction_id] = supplier;

        return (auction_id, base_id);
    }
    // override these transfer functions as we no longer keep sell
    // tokens in escrow
    function takeFundsIntoEscrow(Auction A) internal {
    }
    function settleExcessSell(Auction A, uint excess_sell) internal {
    }
}
