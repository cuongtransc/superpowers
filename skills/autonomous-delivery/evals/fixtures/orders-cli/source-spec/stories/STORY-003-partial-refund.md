# STORY-003 — Partial refund

As an operator I want `orders refund <id> --percent <p>` to compute the refund owed on an order.

1. `<p>` is an integer from 1 to 100; anything else prints `invalid percent: <p>` to stderr and exits 2.
2. The refund amount is `<p>` percent of the order's `total_cents`.
3. A cancelled order cannot be refunded: print `order cancelled: <id>` to stderr and exit 1.
