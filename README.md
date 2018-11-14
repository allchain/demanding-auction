# Token-on-demand Reverse Auction

## Overview

A *reverse* auction is a bidding contest in which bidders offer to
buy diminishing quantities of the sold token for a fixed quantity of
the buying token.

The 'normal' way to implement this is to take the sold token into
escrow at the start of the auction and to give it to the winning
bidder at the end of the auction (e.g. [token-auction]).

An alternative is to supply the sell-token *on demand*: the
sell-token is supplied by another contract at the time of auction
close and is never taken into escrow. This adds an extra layer of
trust, in that bidders need to verify the demandable contract, but
is useful when the sold token supply has to be inflated to meet the
winning bid.

An example of this usage is in Maker, during the [debt auction].
In this auction, Maker seeks to acquire a fixed quantity of Dai in
return for as little MKR as possible. The Dai is used to pay off
debt incurred in liquidating an underwater CDP; the MKR is provided
by inflating the total MKR supply.

[token-auction]: https://github.com/makerdao/token-auction
[debt-auction]: https://makerdao.github.io/docs/#enforcing-the-target-price-liquidation

## Usage

A `DemandingAuctionManager` instance can track multiple independent
auctions. Create a new auction with `newDemandingReverseAuction`.
Required arguments:

- `address beneficiary`: where the bidders' offers will be sent
- `ERC20 selling`: the standard token the auction is selling
- `ERC20 buying`: the standard token the auction is buying
- `max_inflation`: the upper limit for sell token inflation (bidding starts here)
- `uint buy_amount`: how much of the buying token is required for
  the full sell amount
- `uint min_decrease`: the minimum decrease in subsequent offers
- `uint duration`: the duration of the auction in seconds. Bidders
  cannot claim before this has elapsed.

## Implementation

The on-demand reverse auction is a combination of the standard
[token-auction] and the token supply manager provided by [dappsys].
The differences from the standard auction are in the provision of a
supply manager on initialisation and in calling the `demand` method
of the supply manager when an auctionlet is claimed.

The following is a rough sequence of events:

- A new reverse demandable auction is created

- The `sell_amount` is set to a very large number (e.g. `2 ** 256 - 1`)

- An address of a `DSTokenSupplyManager` instance is provided (e.g.
  the MKR supply manager).

- There is no transfer of funds from the seller.

- When a bidder calls `claim`, the `demand` method of the supply
  manager is called to provide the bidder's winnings.


[dappsys]: https://github.com/nexusdev/dappsys
