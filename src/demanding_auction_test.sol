pragma solidity ^0.4.4;

import 'ds-test/test.sol';
import 'ds-token/base.sol';
import './demanding_auction.sol';

contract TestableManager is DemandingAuctionManager {
    uint64 public debug_timestamp;

    function getTime() public view returns (uint64) {
        return debug_timestamp;
    }
    function setTime(uint64 timestamp) public {
        debug_timestamp = timestamp;
    }
    function getSellAmount(uint id) public view returns (uint) {
        return auctionlets(id).sell_amount;
    }
    function getAuctionSellAmount(uint id) public view returns (uint) {
        return auctions(id).sell_amount;
    }
    function getSupplier(uint id) public view returns (DemandController) {
        return _suppliers[id];
    }
    function forceExpire() public {
        // force expiry
        setTime(getTime() + 1000 years);
    }
}

contract AuctionTester {
    TestableManager manager;
    function bindManager(TestableManager _manager) public {
        manager = TestableManager(_manager);
    }
    function doApprove(address spender, uint value, address token) public {
        ERC20(token).approve(spender, value);
    }
    function doBid(uint auctionlet_id, uint bid_how_much, uint quantity)
        public
        returns (uint, uint)
    {
        return manager.bid(auctionlet_id, bid_how_much, quantity, true);
    }
    function doClaim(uint id) public {
        return manager.claim(id);
    }
}

// mock ERC20 token that provides a demand method
contract DemandableToken is DSTokenBase, DemandController {
    function DemandableToken(uint initial_balance) public DSTokenBase(initial_balance) {
    }
    function demand(address who, uint amount) public {
        _supply += amount;
        _balances[who] += amount;
    }
    function destroy(address who, uint amount) public {
        _supply -= amount;
        _balances[who] -= amount;
    }
}

contract DemandingReverseAuctionTest is DSTest {
    TestableManager manager;
    AuctionTester seller;
    AuctionTester beneficiary;
    AuctionTester bidder1;
    AuctionTester bidder2;

    DemandableToken dtoken;

    DSTokenBase t1;
    DSTokenBase t2;

    DemandController supplier;

    // use prime numbers to avoid coincidental collisions
    uint constant T1 = 5 ** 12;
    uint constant T2 = 7 ** 10;

    uint constant million = 10 ** 6;

    function setUp() public {
        t1 = new DemandableToken(million * T1);
        t2 = new DSTokenBase(million * T2);

        supplier = DemandController(t1);

        manager = new TestableManager();
        manager.setTime(uint64(block.timestamp));

        seller = new AuctionTester();
        bidder1 = new AuctionTester();
        bidder2 = new AuctionTester();
        beneficiary = new AuctionTester();

        seller.bindManager(manager);
        bidder1.bindManager(manager);
        bidder2.bindManager(manager);

        t1.transfer(seller, 200 * T1);
        t2.transfer(bidder1, 1000 * T2);
        t2.transfer(bidder2, 1000 * T2);

        t1.approve(manager, 1000 * T1);
        t2.approve(manager, 1000 * T2);

        seller.doApprove(manager, 200 * T1, t1);
        bidder1.doApprove(manager, 1000 * T2, t2);
        bidder2.doApprove(manager, 1000 * T2, t2);
    }
    function testSetUp() public {
        assertEq(t1.balanceOf(seller), 200 * T1);
        assertEq(t2.balanceOf(bidder1), 1000 * T2);
        assertEq(t2.balanceOf(bidder2), 1000 * T2);
    }
    function newDemandingAuction() public returns (uint id, uint base) {
        return manager.newDemandingReverseAuction({beneficiary:   beneficiary,
                                                   supplier:      supplier,
                                                   selling:       ERC20(t1),
                                                   buying:        ERC20(t2),
                                                   max_inflation: uint(uint128(-1)),
                                                   buy_amount:    100 * T2,
                                                   min_decrease:  2,
                                                   ttl:           1 years
                                                  });
    }
    function testNewDemandingAuction() public {
        // create a new demanding auction
        var (id, base) = newDemandingAuction();
        assertEq(id, 1);
        assertEq(base, 1);
        assert(manager.isReversed(id));
    }
    function testVeryLargeSellAmount() public {
        // check that the sell amount is very large by default
        var (id, base) = newDemandingAuction();
        uint very_large = 2 ** 128 - 1;
        assertEq(manager.getAuctionSellAmount(id), very_large);
        assertEq(manager.getSellAmount(base), very_large);
    }
    function testNoTransferFromSeller() public {
        // creating a new demanding auction should not
        // transfer any funds to / from the seller
        var balance_before1 = t1.balanceOf(seller);
        var balance_before2 = t2.balanceOf(seller);

        newDemandingAuction();

        var balance_after1 = t1.balanceOf(seller);
        var balance_after2 = t2.balanceOf(seller);

        assertEq(balance_before1 - balance_after1, 0);
        assertEq(balance_after1 - balance_before1, 0);
        assertEq(balance_before2 - balance_after2, 0);
        assertEq(balance_after2 - balance_before2, 0);
    }
    function testSupplyControllerSetup() public {
        // check that the supply manager works as we expect it to
        var balance_before = t1.balanceOf(this);
        supplier.demand(this, 10);
        var balance_after = t1.balanceOf(this);

        assertEq(balance_after - balance_before, 10);
    }
    function testSupplyController() public {
        // check that the supply manager works as we expect it to
        var (id,) = newDemandingAuction();
        var _supplier = manager.getSupplier(id);

        var balance_before = t1.balanceOf(this);
        _supplier.demand(this, 10);
        var balance_after = t1.balanceOf(this);

        assertEq(balance_after - balance_before, 10);
    }
    function testBid() public {
        // check that bid still works as expected
        var (,base) = newDemandingAuction();

        var balance_before = t2.balanceOf(bidder1);
        bidder1.doBid(base, 50 * T1, 100 * T2);
        var balance_after = t2.balanceOf(bidder1);

        assertEq(balance_before - balance_after, 100 * T2);
    }
    function testClaimTransfersToBidder() public {
        // the claim function should still transfer to the bidder
        var (,base) = newDemandingAuction();

        bidder1.doBid(base, 50 * T1, 100 * T2);

        manager.forceExpire();

        var balance_before = t1.balanceOf(bidder1);
        bidder1.doClaim(base);
        var balance_after = t1.balanceOf(bidder1);

        assertEq(balance_after - balance_before, 50 * T1);
    }
    function testClaimInflatesSupply() public {
        // bidder calling claim should inflate the supply of the
        // sell token by their winning bid
        var (,base) = newDemandingAuction();

        bidder1.doBid(base, 50 * T1, 100 * T2);

        manager.forceExpire();

        var balance_before = t1.totalSupply();
        bidder1.doClaim(base);
        var balance_after = t1.totalSupply();

        assertEq(balance_after - balance_before, 50 * T1);
    }
    function testFailClaimAgain() public {
        var (,base) = newDemandingAuction();

        bidder1.doBid(base, 50 * T1, 100 * T2);

        manager.forceExpire();

        bidder1.doClaim(base);
        bidder1.doClaim(base);
    }
}
