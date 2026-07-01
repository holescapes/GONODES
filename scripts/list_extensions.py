#!/usr/bin/env python3
"""
list_extensions.py — Show discovered native extensions and build plan.

Uses the same planner as build/SConstruct (no SCons required).

Usage:
  python scripts/list_extensions.py
  python scripts/list_extensions.py --tier core
  python scripts/list_extensions.py --defaults
  python scripts/list_extensions.py --platform windows
"""

import argparse
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "build"))

from gn_ext_plan import (  # noqa: E402
    discover_extensions,
    format_extension_table_row,
    parse_build_cfg,
    plan_extensions,
    detect_host_platform,
)


def main() -> int:
    parser = argparse.ArgumentParser(description="List GONODES native extensions")
    parser.add_argument("--platform", default="", help="windows | linux | macos")
    parser.add_argument("--tier", default="", help="core | extension | optional | all")
    parser.add_argument("--exts", default="", help="Comma-separated extension names")
    parser.add_argument("--defaults", action="store_true",
                        help="Show plan for default=true extensions only")
    args = parser.parse_args()

    plat = args.platform or detect_host_platform()
    tier = args.tier
    if args.defaults:
        tier = ""

    extensions = discover_extensions(os.path.join(ROOT, "addons"))

    print(f"\n=== GONODES native extensions (platform={plat}) ===\n")
    hdr = (
        f"  {'Extension':<30} {'Tier':<10} {'Default':<8} {'Opt':<8} "
        f"{'SDK':<8} {'Library':<20} Platforms"
    )
    print(hdr)
    print(f"  {'-'*30} {'-'*10} {'-'*8} {'-'*8} {'-'*8} {'-'*20} {'-'*20}")
    for ext_name, native_dir, cfg_path in extensions:
        cfg = parse_build_cfg(cfg_path)
        print(format_extension_table_row(ext_name, cfg, plat, native_dir))

    defaults_only = args.defaults and not tier and not args.exts
    to_build, skipped = plan_extensions(
        extensions, plat,
        tier=tier if tier != "all" else "all",
        exts=args.exts,
        defaults_only=defaults_only,
    )

    print(f"\n  gn_ext_native — tier=core (built via godot-cpp SConstruct)")
    print(f"\n  Plan: {len(to_build)} would build, {len(skipped)} skipped")
    if to_build:
        print("\n  Would build:")
        for name, _, _, cfg in to_build:
            print(f"    + {name} ({cfg['lib_name']})")
    if skipped:
        print("\n  Skipped:")
        for name, reason in skipped:
            print(f"    - {name}: {reason}")
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
