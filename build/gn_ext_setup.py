"""
gn_ext_setup.py — Run extension SDK downloaders from build.cfg (no SCons).

Reads `setup` and `vendor_clone` from each extension's native/build.cfg, then
runs the declared scripts / git clones before compile. Shared by setup_deps.py,
scripts/run_extension_setups.py, and scripts/build_windows.ps1.
"""

from __future__ import annotations

import glob
import os
import subprocess
import sys

from gn_ext_plan import (
    SHIPPED_TIERS,
    VALID_TIERS,
    discover_extensions,
    parse_build_cfg,
)


def extension_root(ext_name: str, native_dir: str) -> str:
    """Extension addon root (parent of native/)."""
    return os.path.dirname(native_dir)


def parse_setup_line(setup: str) -> tuple[str, list[str]]:
    parts = setup.split()
    if not parts:
        return "", []
    return parts[0], parts[1:]


def parse_vendor_clone(vendor_clone: str) -> tuple[str, str] | None:
    parts = vendor_clone.split()
    if len(parts) < 2:
        return None
    return parts[0], parts[1]


def ensure_gdignore(directory: str) -> None:
    marker = os.path.join(directory, ".gdignore")
    if not os.path.isfile(marker):
        os.makedirs(directory, exist_ok=True)
        open(marker, "w").close()


def clone_vendor_repo(url: str, dest: str) -> bool:
    if os.path.isdir(dest) and os.listdir(dest):
        rel = os.path.relpath(dest)
        print(f"  [skip] vendor already present at {rel}")
        return True

    parent = os.path.dirname(dest)
    os.makedirs(parent, exist_ok=True)
    print(f"  Cloning {url} -> {os.path.relpath(dest)} ...")
    subprocess.run(
        ["git", "clone", "--depth", "1", url, dest],
        check=True,
    )
    ensure_gdignore(dest)
    print(f"  [done] vendor clone")
    return True


def run_vendor_clone(native_dir: str, ext_name: str, vendor_clone: str) -> bool:
    parsed = parse_vendor_clone(vendor_clone)
    if not parsed:
        print(f"  [warn] {ext_name}: invalid vendor_clone: {vendor_clone!r}")
        return False
    url, rel_dest = parsed
    dest = os.path.join(native_dir, rel_dest)
    try:
        return clone_vendor_repo(url, dest)
    except subprocess.CalledProcessError as exc:
        print(f"  [warn] {ext_name}: vendor clone failed (exit {exc.returncode})")
        return False


def resolve_setup_script(ext_root: str, script_name: str) -> str | None:
    path = os.path.join(ext_root, script_name)
    return path if os.path.isfile(path) else None


def find_fallback_setup_scripts(ext_root: str) -> list[str]:
    return sorted(glob.glob(os.path.join(ext_root, "setup_*.py")))


def _parse_exts(exts: str) -> set[str]:
    return {e.strip() for e in exts.split(",") if e.strip()}


def should_run_setup(
    ext_name: str,
    cfg: dict,
    plat: str,
    *,
    tier: str = "",
    ext: str = "",
    exts: str = "",
    for_build: bool = False,
    include_optional_setups: bool = True,
) -> bool:
    """Whether this extension's setup/vendor_clone should run for the current plan."""
    if ext and ext_name != ext:
        return False
    if exts and ext_name not in _parse_exts(exts):
        return False

    platforms = cfg.get("platforms", [])
    if plat not in platforms:
        return False

    ext_tier = cfg.get("tier", "extension")
    if tier and tier != "all":
        if tier == "shipped":
            if ext_tier not in SHIPPED_TIERS:
                if not (include_optional_setups and cfg.get("setup")):
                    return False
        elif tier == "core" and ext_tier != "core":
            return False
        elif tier == "extension" and ext_tier not in ("extension", "core"):
            return False
        elif tier == "optional" and ext_tier != "optional":
            return False
        elif tier in VALID_TIERS and tier != ext_tier:
            if not (include_optional_setups and cfg.get("setup")):
                return False

    if for_build and tier == "minimal" and not cfg.get("default", True):
        return False

    return True


def collect_setup_jobs(
    extensions: list[tuple[str, str, str]],
    plat: str,
    *,
    tier: str = "",
    ext: str = "",
    exts: str = "",
    for_build: bool = False,
    include_optional_setups: bool = True,
    fallback_glob: bool = True,
) -> list[tuple[str, str, str, str, str]]:
    """
    Collect setup work items.

    Returns list of (ext_name, ext_root, native_dir, kind, payload) where kind is
    'clone' or 'setup' and payload is the build.cfg value or script path.
    """
    jobs: list[tuple[str, str, str, str, str]] = []
    seen_setup: set[tuple[str, str]] = set()

    for ext_name, native_dir, cfg_path in extensions:
        cfg = parse_build_cfg(cfg_path)
        if not should_run_setup(
            ext_name, cfg, plat,
            tier=tier, ext=ext, exts=exts,
            for_build=for_build,
            include_optional_setups=include_optional_setups,
        ):
            continue

        ext_root = extension_root(ext_name, native_dir)

        if cfg.get("vendor_clone"):
            jobs.append((ext_name, ext_root, native_dir, "clone", cfg["vendor_clone"]))

        if cfg.get("setup"):
            key = (ext_name, cfg["setup"])
            if key not in seen_setup:
                seen_setup.add(key)
                jobs.append((ext_name, ext_root, native_dir, "setup", cfg["setup"]))
        elif fallback_glob:
            for script_path in find_fallback_setup_scripts(ext_root):
                script_name = os.path.basename(script_path)
                default_cmd = f"{script_name} --no-enable"
                key = (ext_name, default_cmd)
                if key not in seen_setup:
                    seen_setup.add(key)
                    jobs.append((ext_name, ext_root, native_dir, "setup", default_cmd))

    return jobs


def run_setup_jobs(
    jobs: list[tuple[str, str, str, str, str]],
    *,
    dry_run: bool = False,
) -> tuple[int, int]:
    """Run collected jobs. Returns (success_count, failure_count). Non-fatal per job."""
    ok = 0
    failed = 0

    for ext_name, ext_root, native_dir, kind, payload in jobs:
        label = f"{ext_name} ({kind})"
        if dry_run:
            print(f"  [plan] {label}: {payload}")
            continue

        success = False
        if kind == "clone":
            success = run_vendor_clone(native_dir, ext_name, payload)
        elif kind == "setup":
            script_name, args = parse_setup_line(payload)
            script_path = resolve_setup_script(ext_root, script_name)
            if not script_path:
                print(f"  [warn] {ext_name}: setup script not found: {script_name}")
            else:
                cmd = [sys.executable, script_path] + args
                print(f"  Running {ext_name}/{script_name} {' '.join(args)} ...")
                result = subprocess.run(cmd, cwd=ext_root)
                if result.returncode == 0:
                    print(f"  [done] {ext_name}/{script_name}")
                    success = True
                else:
                    print(
                        f"  [warn] {ext_name}/{script_name} exited {result.returncode} "
                        "(non-fatal)"
                    )

        if success:
            ok += 1
        else:
            failed += 1

    return ok, failed


def run_extension_setups(
    root: str,
    plat: str,
    *,
    tier: str = "",
    ext: str = "",
    exts: str = "",
    for_build: bool = False,
    include_optional_setups: bool = True,
    fallback_glob: bool = True,
    dry_run: bool = False,
) -> tuple[int, int]:
    """Discover extensions and run their build.cfg setup steps."""
    addons_dir = os.path.join(root, "addons")
    extensions = discover_extensions(addons_dir)
    jobs = collect_setup_jobs(
        extensions, plat,
        tier=tier, ext=ext, exts=exts,
        for_build=for_build,
        include_optional_setups=include_optional_setups,
        fallback_glob=fallback_glob,
    )
    return run_setup_jobs(jobs, dry_run=dry_run)


def configure_stdio_utf8() -> None:
    if sys.platform == "win32":
        if hasattr(sys.stdout, "reconfigure"):
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        if hasattr(sys.stderr, "reconfigure"):
            sys.stderr.reconfigure(encoding="utf-8", errors="replace")
