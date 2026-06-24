#!/usr/bin/env python3
"""Scaffold descriptor generator for future directed and random testing."""

import argparse


def main() -> None:
    # keep the cli shape in place now so the real generator can grow behind it later
    parser = argparse.ArgumentParser(description="Generate DMA descriptors.")
    parser.add_argument("--count", type=int, default=1, help="descriptor count")
    args = parser.parse_args()

    print(f"Descriptor generation scaffold: count={args.count}")  # visible proof the args arrived


if __name__ == "__main__":
    main()
