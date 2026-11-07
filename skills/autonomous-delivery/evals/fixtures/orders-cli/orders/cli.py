import argparse
import sys

from orders import store


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="orders")
    sub = parser.add_subparsers(dest="command", required=True)
    show = sub.add_parser("show")
    show.add_argument("id", type=int)
    args = parser.parse_args(argv)

    if args.command == "show":
        order = store.get(args.id)
        if order is None:
            print(f"order not found: {args.id}", file=sys.stderr)
            return 1
        print(f"{order['id']} {order['status']} {order['total_cents']}")
    return 0
