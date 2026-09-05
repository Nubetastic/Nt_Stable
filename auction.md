# Horse Auction System

## Goal

Add a player-to-player horse market inside the stable menu. Players can list a horse for a fixed-price direct sale or a timed auction, browse and preview listed horses, and safely receive purchased or returned horses when they have an open stable slot.

The auction system holds listed horses outside normal player stables. A listed horse does not consume the seller's stable slots and cannot be ridden, trained, customized, sold to the stable, assigned to a wagon, or listed a second time.

## Stable Menu

Add a **Horse Auction** button to the main stable menu. It opens an auction home screen with:

- Buy Horse
- Sell Horse
- Horses Held

**Horses Held** is greyed out when the player has no active listings and no horses waiting to be added back to their stable.

**Horses Held** combines both sides of the player's auction activity:

- Horses the player currently has listed for direct sale or auction.
- Horses the player bought and still needs to add to their stable.
- Unsold, expired, cancelled, or returned horses waiting to be added back to their stable.

## Selling a Horse

### Select Horse

The seller selects **Sell Horse** and receives a list of their horses. Selecting a horse:

- Spawns it in the existing stable preview area.
- Shows its name, breed, gender, level, age, and all calculated stats.
- Shows wild horse modifiers when the horse is wild.
- Uses the same components, gender, stat calculation, and preview behavior as the existing horse manager.

The player selects **Sell Horse** to continue to the listing form.

The server must confirm that the horse:

- Belongs to the seller.
- Is not already listed or waiting to be received.
- Is not in a pending death state.
- Can be removed safely from active riding and wagon assignment state.

If the horse is active, its saddlebag contents must be moved to the seller's stable storage before the listing is created. If that inventory transfer fails, nothing changes and the listing is not created.

### Listing Type

The seller chooses one of two listing types.

#### Direct Sale

- Seller enters the purchase price.
- Seller enters the listing duration in whole days.
- The first player whose server-confirmed purchase succeeds owns the horse.

#### Auction

- Seller enters the starting bid.
- Seller enters the auction duration in whole days.
- Players place increasing bids until the listing expires.
- The highest valid bidder wins when the auction expires.
- If there are no bids, the listing fails and the horse is returned to the seller's receive list.

### Listing Fee

- Listing fee is `$1 x number of listing days`.
- The full listing fee is charged when the listing is created.
- The fee is not refunded if the horse sells, the listing expires, or the seller cancels the listing.
- Listing creation and payment must be handled as one server-controlled operation. If the fee cannot be removed, the horse remains in the seller's stable.

### Moving to Auction Storage

After all validation and payment succeed:

- Remove the horse from the seller's normal `player_horses` ownership list.
- Clear its active state.
- Remove its wagon assignments and clear an incomplete active wagon when required.
- Store a complete snapshot of the horse in the auction record, including its model, name, gender, age/birth value, XP, dirt, components, wild status, and wild stat modifiers.
- Record the seller's `citizenid`, listing type, prices, start time, and exact expiration time.

The database operation should be transactional so a horse cannot be duplicated or lost between the stable and auction storage.

## Buying a Horse

### Search Options

The buyer first selects:

- Direct Sale
- Auction

Optional filters:

- Minimum and maximum level
- Minimum and maximum values for each displayed horse stat
- Minimum and maximum price

For direct sales, the price filter applies to the purchase price. For auctions, it applies to the current bid, or the starting bid when no bid has been placed.

The player selects **View Horses** to load matching active listings.

### Browse Results

The buyer can move forward and backward through the matching horses. Each selected listing:

- Spawns the listed horse in the existing stable preview area.
- Applies its stored components and gender.
- Displays name, breed, gender, level, age, all calculated stats, price information, seller name, and time remaining.
- Displays the stored wild horse modifiers when applicable.

Direct listings show the fixed purchase price and a **Buy Horse** button.

Auction listings show:

- Starting bid
- Current highest bid
- Minimum next bid
- Time remaining
- **Place Bid** button

Expired listings must never be purchasable or accept another bid, even if a player's auction screen still displays stale information.

### Direct Purchase

The server performs the purchase atomically:

1. Lock and re-read the listing.
2. Confirm it is still active, is a direct sale, has not expired, and is not owned by the buyer.
3. Confirm the buyer has enough money.
4. Remove the full purchase price from the buyer.
5. Mark the horse as sold and place it in the buyer's receive list.
6. Credit the seller with the sale proceeds minus the stable cut.

Only one buyer can win a direct-sale race. A stable slot is not required at purchase time because the horse remains safely held until it is received.

### Auction Bids

Auction bids are server authoritative. The server must confirm:

- The listing is active and has not expired.
- The bidder is not the seller.
- The new bid meets the minimum next bid.
- The bidder has enough money.

Bid money should be held in escrow when a bid is placed. When a bidder is outbid, their held money is returned immediately. Re-bidding by the current highest bidder should only charge the difference between their previous bid and new bid.

The minimum bid-increase rule needs to be configurable before implementation. Until a different rule is chosen, use a simple `$1` minimum increase.

When the auction expires:

- With a valid highest bidder, mark the horse as sold and place it in the winner's receive list.
- With no bids, mark the listing as failed and place the horse in the seller's receive list.
- Finalize the seller's proceeds only once.

Auction completion must work from server time and database state. It cannot depend on either player being online or having the auction menu open.

## Stable Cut and Seller Payment

- The stable keeps `5%` of the final sale price.
- Seller proceeds are `final price - 5%`, rounded consistently to whole cents.
- The `$1 per day` listing fee is separate from the 5% stable cut.
- The seller should receive proceeds whether online or offline.

The exact offline-money method should use the existing RSG banking/player-money contract available in this server. If direct offline credit is not reliable, store proceeds as claimable auction funds and show a **Collect Proceeds** action inside **Horses Held**. This decision must be confirmed before implementation.

## Horses Held

The **Horses Held** window lists two kinds of records in one place. They should be visually separated so players can immediately tell whether a horse is currently for sale or waiting for them.

### Currently Selling

This section lists every active horse the player is selling. Each entry shows:

- Horse name and preview
- Direct sale or auction
- Asking price, starting bid, or current bid
- Time remaining
- Current listing status
- Cancel Listing button

The seller can cancel any listing that has not already sold or completed. Cancellation is server authoritative:

- Lock and re-read the listing to confirm it is still active.
- Mark the listing cancelled so no purchase or bid can complete afterward.
- For an auction with a current bid, refund the held bid to the bidder.
- Move the horse into the seller's held receive list.
- Do not refund the original `$1 per day` listing fee.
- Do not charge the 5% stable cut because no sale occurred.

Cancelling does not insert the horse directly into `player_horses`. The seller must use **Add to Stable**, which preserves the deferred stable-slot check.

### Waiting for Stable

A horse enters the receive list when:

- A player wins an auction.
- A player completes a direct purchase.
- The seller's listing expires without a bid.
- The seller cancels an unsold listing.
- A listing is administratively returned or otherwise fails after the horse entered auction storage.

The player selects a waiting horse under **Horses Held**, reviews its preview and stats, then selects **Add to Stable**.

Only at this point does the server check stable capacity.

- If a slot is available, insert the complete horse record into `player_horses`, remove it from the receive list, and refresh the stable and auction menus.
- If no slot is available, display that another horse slot is required. Do not change ownership or remove the horse from the receive list.
- The player can leave, purchase another stable slot through the existing slot system, and return later.

Receiving must be transactional and idempotent. Repeated clicks, reconnects, or callback retries cannot create duplicate horses or remove a held horse without inserting it into `player_horses`.

Received horses should enter the stable as inactive. They should retain their original name, model, gender, age, XP/level, components, wild status, and wild modifiers.

## Wild Horse Modifier Display

Wild horse modifiers must be shown in every horse stat window for clarity, including:

- Existing owned-horse management
- Sell-horse selection
- Direct-sale browsing
- Auction browsing
- Horses Held selling and receiving selections
- Wild horse registration

Each affected stat should show both the final calculated value and its wild modifier, for example `Speed: 6 (+2 Wild)`. Non-wild horses should not show a modifier label. The display must use the stored `stat_modifiers` data and the existing shared horse-stat calculation so the shown values match actual horse behavior.

## Database Design

Use dedicated auction tables rather than temporarily changing a horse's `citizenid` to a fake auction owner.

### `nt_stable_horse_listings`

One record per listed horse:

- Listing ID
- Seller `citizenid`
- Seller display name snapshot
- Listing type: `direct` or `auction`
- Status: `active`, `sold`, `expired`, `returned`, or `cancelled`
- Direct price or starting bid
- Current highest bid and bidder
- Listing fee
- Stable cut
- Created timestamp
- Expiration timestamp
- Completed timestamp
- Complete horse data snapshot

The horse snapshot can use explicit columns matching `player_horses` or a JSON payload. Explicit columns are preferable for values used by filtering; JSON is suitable for components and stat modifiers.

### `nt_stable_horse_bids`

Bid history and escrow tracking:

- Bid ID
- Listing ID
- Bidder `citizenid`
- Bid amount
- Bid timestamp
- Escrow/refund state

### `nt_stable_horse_receiving`

Horses waiting to enter a player's stable:

- Receive ID
- Listing ID
- Recipient `citizenid`
- Reason: `purchased`, `auction_won`, `expired`, `cancelled`, or `returned`
- Created timestamp
- Received timestamp/status
- Complete horse data snapshot, or a protected reference to an immutable listing snapshot

### Optional `nt_stable_auction_funds`

Use only if seller proceeds cannot be safely credited offline through the existing framework money system.

## Server Authority and Safety

All prices, durations, ownership, balances, status changes, bids, expiration, fees, cuts, and slot checks must be recalculated or validated on the server. NUI values are requests only.

Important protections:

- Database transactions and row locking for listing, purchase, bid, expiration, and receiving operations.
- A unique relationship between a horse/listing and its active auction or receive state.
- Server timestamps for all expiration checks.
- No self-purchase or self-bidding.
- No negative, zero, malformed, or out-of-range prices and durations.
- Configurable minimum/maximum price and listing-day limits.
- No client-supplied horse snapshot data when listing or receiving.
- Cleanup that safely resolves active horses, saddlebags, and wagon assignments before listing.
- Cancellation that locks the listing, refunds any held bid, and returns the horse exactly once.
- No deletion of completed records until payments, refunds, and horse receipt state are settled.
- Startup and periodic server processing for expired auctions, with an idempotent completion path.

## Configuration

Add auction settings to the existing stable configuration:

- Listing fee per day: `$1`
- Stable sale cut: `5%`
- Minimum and maximum listing days
- Minimum and maximum direct price
- Minimum and maximum starting bid
- Minimum bid increase: `$1` unless changed
- Expiration processing interval
- Seller cancellation behavior and bidder refunds

## Current Decisions

- Auctions are accessed from the stable menu.
- Both fixed-price direct sales and timed auctions are supported.
- Listing duration is selected in whole days.
- The listing fee is `$1` per day and is paid up front.
- The stable takes `5%` of a successful sale.
- Listed horses leave the seller's normal stable immediately.
- **Horses Held** lists both the player's active sale listings and horses waiting for stable placement.
- Sellers can cancel a listing any time before it is sold or completed; any held auction bid is refunded.
- Purchased, expired, cancelled, and returned horses wait in the held receive list.
- Stable capacity is checked only when the recipient adds the horse to their stable.
- A failed slot check does not alter the waiting horse.
- Wild modifiers appear in every horse stat window.

## Decisions Still Needed Before Coding

- Allowed minimum and maximum listing duration.
- Allowed minimum and maximum sale prices.
- Whether seller proceeds go directly to bank/offline money or are manually collected.
- Whether buyers may retract bids; the safe default is no.
- Whether listing filters should include breed, gender, age, wild status, and horse name in addition to the requested stat and price ranges.
- Whether completed sale history should remain visible under **Horses Held**, and for how long.

## Suggested Implementation Order

1. Confirm the remaining product decisions and money behavior.
2. Add configuration and database tables.
3. Add server-side listing, escrow, expiration, purchase, payout, and receive operations.
4. Add the auction home, selling flow, browsing filters, listings, and receive screens to the existing stable NUI.
5. Reuse the current horse preview and shared stat calculation for every auction screen.
6. Add wild modifier details to every existing and new horse stat window.
7. Validate duplicate-click, simultaneous-buy, simultaneous-bid, disconnect, restart, expired-listing, insufficient-funds, full-stable, active-horse, saddlebag, and wagon-assignment scenarios in live RedM.
