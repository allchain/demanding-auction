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

An example of this usage is in Maker, during the [debt auction][whitepaper].  
In this auction, Maker seeks to acquire a fixed quantity of Dai in
return for as little MKR as possible. The Dai is used to pay off
debt incurred in liquidating an underwater CDP; the MKR is provided
by inflating the total MKR supply.

[token-auction]: https://github.com/rainbeam/token-auction
[debt-auction]: https://makerdao.github.io/docs/
