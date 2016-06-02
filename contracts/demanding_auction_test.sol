import 'dapple/test.sol';

import 'dappsys/data/balance_db.sol';
import 'dappsys/factory/factory_test.sol';
import 'dappsys/token/supply_manager.sol';
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
        return _suppliers[id];
    }
    function forceExpire() {
        // force expiry
        setTime(getTime() + 1000 years);
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

// This test uses the full dappsys auth / factory system. This isn't
// strictly necessary as the only necessary component is a supply
// manager, which could be mocked. However, at the time of writing the
// intended usage is in a dappsys system.
contract DemandingReverseAuctionTest is Test, TestFactoryUser {
    TestableManager manager;
    AuctionTester seller;
    Tester beneficiary;
    AuctionTester bidder1;
    AuctionTester bidder2;

    DSTokenFrontend t1;
    DSTokenFrontend t2;

    DSBalanceDB db;
    DSBasicAuthority authority;
    DSTokenSupplyManager supplier;

    // use prime numbers to avoid coincidental collisions
    uint constant T1 = 5 ** 12;
    uint constant T2 = 7 ** 10;

    uint constant million = 10 ** 6;

    function DemandingReverseAuctionTest() {
        authority = new DSBasicAuthority();
        setUpTokens();
        setUpSupplier();
    }
    function setUp() {
        manager = new TestableManager();
        manager.setTime(block.timestamp);

        setUpTesters();
    }
    function setUpTokens() {
        DSBalanceDB baldb;
        bytes4 sig = bytes4(sha3("setBalance(address,uint256)"));

        setOwner( authority, factory );
        t1 = factory.installDSTokenBasicSystem(authority);
        baldb = t1.getController().getBalanceDB();

        authority.setCanCall(address(this), baldb, sig, true);
        baldb.setBalance(address(this), million * T1);
        authority.setCanCall(address(this), baldb, sig, false);

        setOwner( authority, factory );
        t2 = factory.installDSTokenBasicSystem(authority);
        baldb = t2.getController().getBalanceDB();

        authority.setCanCall(address(this), baldb, sig, true);
        baldb.setBalance(address(this), million * T2);
        authority.setCanCall(address(this), baldb, sig, false);
    }
    function setUpTesters() {
        seller = new AuctionTester();
        seller.bindManager(manager);

        beneficiary = new Tester();

        t1.transfer(seller, 200 * T1);
        seller.doApprove(manager, 200 * T1, ERC20(t1));

        bidder1 = new AuctionTester();
        bidder1.bindManager(manager);

        t2.transfer(bidder1, 1000 * T2);
        bidder1.doApprove(manager, 1000 * T2, ERC20(t2));

        bidder2 = new AuctionTester();
        bidder2.bindManager(manager);

        t2.transfer(bidder2, 1000 * T2);
        bidder2.doApprove(manager, 1000 * T2, ERC20(t2));

        t1.approve(manager, 1000 * T1);
        t2.approve(manager, 1000 * T2);
    }
    function setUpSupplier() {
        db = t1.getController().getBalanceDB();
        supplier = new DSTokenSupplyManager(db);

        // db.updateAuthority(authority, DSAuthModes.Authority);
        // ^ Fails
        authority.setCanCall(supplier, db,
                             bytes4(sha3('addBalance(address,uint256)')),
                             true);
        supplier.updateAuthority(authority, DSAuthModes.Authority);
        authority.setCanCall(this, supplier,
                             bytes4(sha3('demand(uint256)')),
                             true);
    }
    function testSetUp() {
        assertEq(t1.balanceOf(seller), 200 * T1);
        assertEq(t2.balanceOf(bidder1), 1000 * T2);
        assertEq(t2.balanceOf(bidder2), 1000 * T2);
    }
    function newDemandingAuction() returns (uint id, uint base) {
        return manager.newDemandingReverseAuction({beneficiary:  beneficiary,
                                                   supplier:     supplier,
                                                   selling:      ERC20(t1),
                                                   buying:       ERC20(t2),
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
        var balance_before = t1.balanceOf(this);
        supplier.demand(10);
        var balance_after = t1.balanceOf(this);

        assertEq(balance_after - balance_before, 10);
    }
    function testSupplyManager() {
        // check that the supply manager works as we expect it to
        var (id, base) = newDemandingAuction();
        var _supplier = manager.getSupplier(id);

        var balance_before = t1.balanceOf(this);
        _supplier.demand(10);
        var balance_after = t1.balanceOf(this);

        assertEq(balance_after - balance_before, 10);
    }
    function testBid() {
        // check that bid still works as expected
        var (id, base) = newDemandingAuction();

        var balance_before = t2.balanceOf(bidder1);
        bidder1.doBid(base, 50 * T1);
        var balance_after = t2.balanceOf(bidder1);

        assertEq(balance_before - balance_after, 100 * T2);
    }
    function set_manager_auth() {
        authority.setCanCall(address(manager), address(supplier),
                             bytes4(sha3('demand(uint256)')),
                             true);
    }
    function testManagerAuth() {
        var can_before = authority.canCall(address(manager), address(supplier),
                                           bytes4(sha3('demand(uint256)')));
        set_manager_auth();
        var can_after = authority.canCall(address(manager), address(supplier),
                                          bytes4(sha3('demand(uint256)')));

        assertFalse(can_before);
        assertTrue(can_after);
    }
    function testClaimTransfersToBidder() {
        // the claim function should still transfer to the bidder
        var (id, base) = newDemandingAuction();

        bidder1.doBid(base, 50 * T1);

        manager.forceExpire();

        var balance_before = t1.balanceOf(bidder1);
        set_manager_auth();
        bidder1.doClaim(base);
        var balance_after = t1.balanceOf(bidder1);

        assertEq(balance_after - balance_before, 50 * T1);
    }
    function testClaimInflatesSupply() {
        // bidder calling claim should inflate the supply of the
        // sell token by their winning bid
        var (id, base) = newDemandingAuction();

        bidder1.doBid(base, 50 * T1);

        manager.forceExpire();

        var balance_before = t1.totalSupply();
        set_manager_auth();
        bidder1.doClaim(base);
        var balance_after = t1.totalSupply();

        assertEq(balance_after - balance_before, 50 * T1);
    }
    function testFailClaimAgain() {
        var (id, base) = newDemandingAuction();

        bidder1.doBid(base, 50 * T1);

        manager.forceExpire();

        set_manager_auth();
        bidder1.doClaim(base);
        bidder1.doClaim(base);
    }
    function testNoReclaim() {
        var (id, base) = newDemandingAuction();

        bidder1.doBid(base, 50 * T1);

        manager.forceExpire();

        var balance_before = t1.balanceOf(seller);
        seller.doReclaim(base);
        var balance_after = t1.balanceOf(seller);

        assertEq(balance_before, balance_after);
    }
}
