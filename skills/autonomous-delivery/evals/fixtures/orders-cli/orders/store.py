ORDERS: list[dict] = [
    {"id": 1001, "status": "paid", "total_cents": 1250},
    {"id": 1002, "status": "pending", "total_cents": 800},
    {"id": 1003, "status": "shipped", "total_cents": 4999},
    {"id": 1004, "status": "paid", "total_cents": 300},
    {"id": 1005, "status": "cancelled", "total_cents": 1500},
    {"id": 1006, "status": "paid", "total_cents": 12000},
]


def get(order_id: int) -> dict | None:
    for order in ORDERS:
        if order["id"] == order_id:
            return order
    return None
