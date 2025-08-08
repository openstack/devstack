#!/usr/bin/env python3

import argparse
import ipaddress
import sys

def main():
    parser = argparse.ArgumentParser(
        description="Check if a given string is a valid IPv6 address.",
        formatter_class=argparse.RawTextHelpFormatter,
    )
    parser.add_argument(
        "address",
        help=(
            "The IPv6 address string to validate.\n"
            "Examples:\n"
            "  2001:0db8:85a3:0000:0000:8a2e:0370:7334\n"
            "  2001:db8::1\n"
            "  ::1\n"
            "  fe80::1%eth0 (scope IDs are handled)"
        ),
    )
    args = parser.parse_args()

    try:
        # try to create a IPv6Address: if we fail to parse or get an
        # IPv4Address then die
        ip_obj = ipaddress.ip_address(args.address.strip('[]'))
        if isinstance(ip_obj, ipaddress.IPv6Address):
            sys.exit(0)
        else:
            sys.exit(1)
    except ValueError:
        sys.exit(1)
    except Exception as e:
        print(f"An unexpected error occurred during validation: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
