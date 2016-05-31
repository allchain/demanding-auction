import 'dapple/test.sol';
import 'erc20/base.sol';
import 'demanding_auction.sol';

contract TestableManager is DemandingAuctionManager {
    uint public debug_timestamp;

    function getTime() public constant returns (uint) {
        return debug_timestamp;
    }
    function setTime(uint timestamp) {
        debug_timestamp = timestamp;
    }
}

contract AuctionTester is Tester {
    TestableManager manager;
    function bindManager(TestableManager _manager) {
        _target(_manager);
        manager = TestableManager(_t);
    }
    function doApprove(address spender, uint value, ERC20 token) {
        token.approve(spender, value);
    }
    function doBid(uint auctionlet_id, uint bid_how_much)
    {
        return manager.bid(auctionlet_id, bid_how_much);
    }
    function doClaim(uint id) {
        return manager.claim(id);
    }
    function doReclaim(uint id) {
        return manager.reclaim(id);
    }
}

contract DemandingReverseAuctionTest is Test {
    TestableManager manager;
    AuctionTester seller;
    Tester beneficiary;
    AuctionTester bidder1;
    AuctionTester bidder2;

    ERC20 t1;
    ERC20 t2;

    // use prime numbers to avoid coincidental collisions
    uint constant T1 = 5 ** 12;
    uint constant T2 = 7 ** 10;

    function setUp() {
        manager = new TestableManager();
        manager.setTime(block.timestamp);

        var million = 10 ** 6;

        t1 = new ERC20Base(million * T1);
        t2 = new ERC20Base(million * T2);

        seller = new AuctionTester();
        seller.bindManager(manager);

        beneficiary = new Tester();

        t1.transfer(seller, 200 * T1);
        seller.doApprove(manager, 200 * T1, t1);

        bidder1 = new AuctionTester();
        bidder1.bindManager(manager);

        t2.transfer(bidder1, 1000 * T2);
        bidder1.doApprove(manager, 1000 * T2, t2);

        bidder2 = new AuctionTester();
        bidder2.bindManager(manager);

        t2.transfer(bidder2, 1000 * T2);
        bidder2.doApprove(manager, 1000 * T2, t2);

        t1.transfer(this, 1000 * T1);
        t2.transfer(this, 1000 * T2);
        t1.approve(manager, 1000 * T1);
        t2.approve(manager, 1000 * T2);
    }
    function newDemandingAuction() returns (uint id, uint base) {
        return manager.newDemandingReverseAuction({beneficiary:  beneficiary,
                                                   selling:      t1,
                                                   buying:       t2,
                                                   buy_amount:   100 * T2,
                                                   min_decrease: 2 * T1,
                                                   duration:     1 years
                                                  });
    }
    function testNewDemandingAuction() {
        // create a new demanding auction
        var (id, base) = newDemandingAuction();
        assertEq(id, 1);
        assertEq(base, 1);
    }
    function testVeryLargeSellAmount() {
        // check that the sell amount is very large by default
    }
    function testSupplyManager() {
        // check that the supply manager works as we expect it to
    }
    function testNoTransferFromSeller() {
        // creating a new demanding auction should not
        // transfer any funds from the seller
    }
    function testClaimTransfersToBidder() {
        // the claim function should still transfer to the bidder
    }
    function testClaimInflatesSupply() {
        // bidder calling claim should inflate the supply of the
        // sell token by their winning bid
    }
}
