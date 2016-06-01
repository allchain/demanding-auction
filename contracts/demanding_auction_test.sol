import 'dapple/test.sol';

import 'erc20/base.sol';
import 'dappsys/token/supply_manager.sol';
import 'dappsys/data/balance_db.sol';
import 'dappsys/auth/basic_authority.sol';

import 'demanding_auction.sol';

contract TestableManager is DemandingAuctionManager {
    uint public debug_timestamp;

    function getTime() public constant returns (uint) {
        return debug_timestamp;
    }
    function setTime(uint timestamp) {
        debug_timestamp = timestamp;
    }
    function isReversed(uint id) returns (bool) {
        return _auctions[id].reversed;
    }
    function getSellAmount(uint id) returns (uint) {
        return _auctionlets[id].sell_amount;
    }
    function getAuctionSellAmount(uint id) returns (uint) {
        return _auctions[id].sell_amount;
    }
    function getSupplier(uint id) returns (DSTokenSupplyManager) {
        return _auctions[id].supplier;
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

contract DemandingReverseAuctionTest is Test, DSAuthUser {
    TestableManager manager;
    AuctionTester seller;
    Tester beneficiary;
    AuctionTester bidder1;
    AuctionTester bidder2;

    ERC20 t1;
    ERC20 t2;

    DSBalanceDB db;
    DSBasicAuthority authority;
    DSTokenSupplyManager supplier;

    // use prime numbers to avoid coincidental collisions
    uint constant T1 = 5 ** 12;
    uint constant T2 = 7 ** 10;

    function DemandingReverseAuctionTest() {
        authority = new DSBasicAuthority();
    }
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

        setUpSupplier();
    }
    function setUpSupplier() {
        db = new DSBalanceDB();
        supplier = new DSTokenSupplyManager(db);

        db.updateAuthority(authority, DSAuthModes.Authority);
        authority.setCanCall(supplier, db,
                             bytes4(sha3('addBalance(address,uint256)')),
                             true);

        supplier.updateAuthority(authority, DSAuthModes.Authority);
        authority.setCanCall(this, supplier,
                             bytes4(sha3('demand(uint256)')),
                             true);
    }
    function newDemandingAuction() returns (uint id, uint base) {
        return manager.newDemandingReverseAuction({beneficiary:  beneficiary,
                                                   supplier:     supplier,
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
        assertTrue(manager.isReversed(id));
    }
    function testVeryLargeSellAmount() {
        // check that the sell amount is very large by default
        var (id, base) = newDemandingAuction();
        var very_large = 2 ** 256 - 1;
        assertEq(manager.getAuctionSellAmount(id), very_large);
        assertEq(manager.getSellAmount(base), very_large);
    }
    function testNoTransferFromSeller() {
        // creating a new demanding auction should not
        // transfer any funds to / from the seller
        var balance_before1 = t1.balanceOf(seller);
        var balance_before2 = t2.balanceOf(seller);

        var (id, base) = newDemandingAuction();

        var balance_after1 = t1.balanceOf(seller);
        var balance_after2 = t2.balanceOf(seller);

        assertEq(balance_before1 - balance_after1, 0);
        assertEq(balance_after1 - balance_before1, 0);
        assertEq(balance_before2 - balance_after2, 0);
        assertEq(balance_after2 - balance_before2, 0);
    }
    function testSupplyManagerSetup() {
        // check that the supply manager works as we expect it to
        var balance_before = db.getBalance(this);
        supplier.demand(10);
        var balance_after = db.getBalance(this);

        assertEq(balance_after - balance_before, 10);
        assertEq(db.getSupply(), 10);
    }
    function testSupplyManager() {
        // check that the supply manager works as we expect it to
        var (id, base) = newDemandingAuction();
        var _supplier = manager.getSupplier(id);

        var balance_before = db.getBalance(this);
        supplier.demand(10);
        var balance_after = db.getBalance(this);

        assertEq(balance_after - balance_before, 10);
        assertEq(db.getSupply(), 10);
    }
    function testClaimTransfersToBidder() {
        // the claim function should still transfer to the bidder
    }
    function testClaimInflatesSupply() {
        // bidder calling claim should inflate the supply of the
        // sell token by their winning bid
    }
}
