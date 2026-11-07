# STORY-001 — Order count by status

As an operator I want `orders count` to print how many orders are in each status.

1. Statuses are printed in this fixed order: pending, paid, shipped, cancelled.
2. Each line is `<status>: <n>`.
3. A status with no orders is still printed, with `0`.
4. `orders count --status <s>` prints only that status's line; an unknown status prints `unknown status: <s>` to stderr and exits with code 2.
