# STORY-002 — Order list by status

As an operator I want `orders list --status <s>` to list the orders in one status.

1. Each line is `<id> <status> <total>`.
2. `<total>` is the amount in major units with two decimals, e.g. `12.50` for 1250 cents.
3. A status with no orders prints `no orders` and exits 0.
