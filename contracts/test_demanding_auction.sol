contract DemandingReverseAuctionTest {
    function testNewDemandingAuction() {
        // create a new demanding auction
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
