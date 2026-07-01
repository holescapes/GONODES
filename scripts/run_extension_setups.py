#!/usr/bin/env python3
"""
GONODES — Run extension SDK setup scripts from build.cfg

Downloads / installs external dependencies declared in each extension's
native/build.cfg (`setup`, `vendor_clone`) before compiling.

Usage:
  python scripts/run_extension_setups.py
  python scripts/run_extension_setups.py --for-build --tier shipped
  python scripts/run_extension_setups.py --for-build --tier all
  python scripts/run_extension_setups.py --list
  python scripts/run_extension_setups.py --no-optional-setups
"""
from __future__ import annotations

import argparse
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD_DIR = os.path.join(ROOT, "build")
if BUILD_DIR not in sys.path:
    sys.path.insert(0, BUILD_DIR)

from gn_ext_plan import detect_host_platform  # noqa: E402
from gn_ext_setup import configure_stdio_utf8, run_extension_setups  # noqa: E402


def main() -> int:
    configure_stdio_utf8()

    parser = argparse.ArgumentParser(
        description="Run extension setup scripts declared in build.cfg",
    )
    parser.add_argument(
        "--for-build",
        action="store_true",
        help="Match the upcoming scons tier/ext filter (default tier: all)",
    )
    parser.add_argument(
        "--tier",
        default="",
        help="Tier filter: shipped, core, extension, optional, all, minimal",
    )
    parser.add_argument("--ext", default="", help="Single extension name")
    parser.add_argument("--exts", default="", help="Comma-separated extension names")
    parser.add_argument(
        "--platform",
        default="",
        help="Target platform (default: host)",
    )
    parser.add_argument(
        "--no-optional-setups",
        action="store_true",
        help="Skip optional-tier setup scripts (faster; opencv/ml not downloaded)",
    )
    parser.add_argument(
        "--no-fallback-glob",
        action="store_true",
        help="Only run scripts declared in build.cfg (skip setup_*.py glob)",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="Show planned setup steps without running them",
    )
    args = parser.parse_args()

    plat = args.platform or detect_host_platform()
    tier = args.tier
    if args.for_build and not tier and not args.ext and not args.exts:
        tier = "all"

    print(f"\n{'-' * 60}")
    mode = "for-build" if args.for_build else "all matching"
    tier_label = tier or "all"
    print(f"  Extension setups ({mode}, tier={tier_label}, platform={plat})")
    print(f"{'-' * 60}")

    ok, failed = run_extension_setups(
        ROOT,
        plat,
        tier=tier,
        ext=args.ext,
        exts=args.exts,
        for_build=args.for_build,
        include_optional_setups=not args.no_optional_setups,
        fallback_glob=not args.no_fallback_glob,
        dry_run=args.list,
    )

    if args.list:
        return 0

    print(f"\n  Setups finished: {ok} ok, {failed} failed (failures are non-fatal)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
