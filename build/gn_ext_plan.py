"""
gn_ext_plan.py — Extension build discovery and planning (no SCons dependency).

Shared by build/SConstruct, scripts/check_env.py, and build/gn_build.py.
"""

from __future__ import annotations

import configparser
import os
import platform as _platform

ALL_PLATFORMS = ["windows", "macos", "linux"]

VALID_TIERS = ("core", "extension", "optional")
SHIPPED_TIERS = ("core", "extension")


def detect_host_platform() -> str:
    if _platform.system() == "Windows":
        return "windows"
    if _platform.system() == "Darwin":
        return "macos"
    return "linux"


def parse_build_cfg(cfg_path: str) -> dict:
    """Parse a build.cfg into a typed dictionary."""
    cp = configparser.ConfigParser()
    cp.read(cfg_path, encoding="utf-8")

    def get_list(section: str, key: str, fallback: str = "") -> list[str]:
        if not cp.has_section(section):
            return []
        raw = cp.get(section, key, fallback=fallback).strip()
        if not raw:
            return []
        return [s.strip() for s in raw.split(",") if s.strip()]

    tier = "extension"
    if cp.has_section("library") and cp.has_option("library", "tier"):
        tier = cp.get("library", "tier", fallback="extension").strip().lower()
        if tier not in VALID_TIERS:
            tier = "extension"

    optional = (
        cp.getboolean("library", "optional", fallback=False)
        if cp.has_section("library") else False
    )
    if tier == "optional":
        optional = True

    if cp.has_section("library") and cp.has_option("library", "default"):
        default_build = cp.getboolean("library", "default")
    else:
        if tier == "optional" or optional:
            default_build = False
        else:
            default_build = True

    setup = ""
    vendor_clone = ""
    if cp.has_section("library"):
        setup = cp.get("library", "setup", fallback="").strip()
        if not setup:
            setup = cp.get("library", "vendor_setup", fallback="").strip()
        vendor_clone = cp.get("library", "vendor_clone", fallback="").strip()

    cfg = {
        "lib_name": cp.get("library", "name", fallback="") if cp.has_section("library") else "",
        "entry_symbol": cp.get("library", "entry_symbol", fallback="") if cp.has_section("library") else "",
        "tier": tier,
        "default": default_build,
        "optional": optional,
        "setup": setup,
        "vendor_clone": vendor_clone,
        "platforms": get_list("library", "platforms") or list(ALL_PLATFORMS),
        "library_dest": cp.get("library", "library_dest", fallback="").strip() if cp.has_section("library") else "",
        "sources": get_list("sources", "cpp", "src/*.cpp"),
        "c_sources": get_list("sources", "c"),
        "objcxx_sources": get_list("sources", "objcxx"),
        "thirdparty_cpp": get_list("sources", "thirdparty_cpp"),
        "thirdparty_c": get_list("sources", "thirdparty_c"),
        "thirdparty_cc": get_list("sources", "thirdparty_cc"),
        "include_dirs": get_list("sources", "include_dirs"),
    }

    base_keys = {"libs", "lib_dirs", "frameworks", "defines", "objcxx_sources", "include_dirs"}

    for plat in ALL_PLATFORMS:
        cfg[plat] = {
            "libs": get_list(plat, "libs"),
            "lib_dirs": get_list(plat, "lib_dirs"),
            "include_dirs": get_list(plat, "include_dirs"),
            "frameworks": get_list(plat, "frameworks"),
            "defines": get_list(plat, "defines"),
            "objcxx_sources": get_list(plat, "objcxx_sources"),
            "runtime_dlls": get_list(plat, "runtime_dlls"),
            "runtime_dlls_dest": cp.get(plat, "runtime_dlls_dest", fallback="").strip() if cp.has_section(plat) else "",
            "probe": get_list(plat, "probe"),
            "optional_sdks": {},
        }

        if not cp.has_section(plat):
            continue

        for key, _raw in cp.items(plat):
            for base in base_keys:
                prefix = base + "_"
                if key.startswith(prefix) and key != base:
                    suffix = key[len(prefix):]
                    sdk = cfg[plat]["optional_sdks"].setdefault(suffix, {})
                    sdk[base] = get_list(plat, key)
                    break

    return cfg


def _resolve_path(native_dir: str, rel: str) -> str:
    return rel if os.path.isabs(rel) else os.path.join(native_dir, rel)


def get_effective_probes(cfg: dict, plat: str, native_dir: str) -> list[str]:
    """Return probe paths (relative to native_dir), explicit or auto-derived."""
    explicit = cfg.get(plat, {}).get("probe", [])
    if explicit:
        return explicit

    plat_cfg = cfg.get(plat, {})
    lib_dirs = plat_cfg.get("lib_dirs", [])
    libs = plat_cfg.get("libs", [])
    if not lib_dirs or not libs:
        return []

    probes: list[str] = []
    for lib_dir in lib_dirs:
        for lib in libs:
            if plat == "windows":
                probes.append(f"{lib_dir}/{lib}.lib")
            elif plat == "linux":
                probes.append(f"{lib_dir}/lib{lib}.so")
            else:
                probes.append(f"{lib_dir}/lib{lib}.dylib")
    return probes


def check_probes(probes: list[str], native_dir: str) -> list[str]:
    """Return probe paths (relative) that are missing on disk."""
    missing: list[str] = []
    for probe_rel in probes:
        if not os.path.isfile(_resolve_path(native_dir, probe_rel)):
            missing.append(probe_rel)
    return missing


def probe_status(cfg: dict, plat: str, native_dir: str) -> str:
    """Human-readable SDK probe status: ready | missing | n/a."""
    probes = get_effective_probes(cfg, plat, native_dir)
    if not probes:
        return "n/a"
    missing = check_probes(probes, native_dir)
    return "missing" if missing else "ready"


def _parse_exts(exts: str) -> set[str]:
    return {e.strip() for e in exts.split(",") if e.strip()}


def should_build_extension(
    ext_name: str,
    cfg: dict,
    plat: str,
    native_dir: str,
    *,
    tier: str = "",
    ext: str = "",
    exts: str = "",
    defaults_only: bool = False,
) -> tuple[bool, str]:
    """
    Decide whether an extension should be compiled.

    Returns (should_build, reason).
    """
    if ext and ext_name != ext:
        return False, f"filtered (ext={ext})"

    if exts:
        allowed = _parse_exts(exts)
        if ext_name not in allowed:
            return False, "not in exts list"

    ext_tier = cfg.get("tier", "extension")

    if tier and tier != "all":
        if tier == "shipped" and ext_tier not in ("core", "extension"):
            return False, f"tier={ext_tier} (not in shipped set)"
        if tier == "core" and ext_tier != "core":
            return False, f"tier={ext_tier} (need core)"
        if tier == "extension" and ext_tier not in ("extension", "core"):
            return False, f"tier={ext_tier} (need extension)"
        if tier == "optional" and ext_tier != "optional":
            return False, f"tier={ext_tier} (need optional)"
        if tier == "minimal" and not cfg.get("default", True):
            return False, "default=false"

    if defaults_only and not ext and not exts and not tier:
        if not cfg.get("default", True):
            return False, "default=false"

    if plat not in cfg.get("platforms", ALL_PLATFORMS):
        return False, f"platform '{plat}' not supported"

    probes = get_effective_probes(cfg, plat, native_dir)
    missing = check_probes(probes, native_dir)
    if missing:
        label = "optional SDK missing" if cfg.get("optional") else "SDK missing"
        return False, f"{label}: {', '.join(missing)}"

    return True, "ready"


def discover_extensions(addons_dir: str = "addons") -> list[tuple[str, str, str]]:
    """
    Scan addons/ for gn_ext_*/native/build.cfg files.
    Returns (ext_name, native_dir, cfg_path) tuples.
    gn_ext_native is excluded — it uses godot-cpp's SConstruct directly.
    """
    extensions: list[tuple[str, str, str]] = []
    if not os.path.isdir(addons_dir):
        return extensions

    for entry in sorted(os.listdir(addons_dir)):
        if not entry.startswith("gn_ext_") or entry == "gn_ext_native":
            continue
        native_dir = os.path.join(addons_dir, entry, "native")
        cfg_path = os.path.join(native_dir, "build.cfg")
        if os.path.isfile(cfg_path):
            extensions.append((entry, native_dir, cfg_path))
            continue
        if os.path.isdir(native_dir):
            for sub in sorted(os.listdir(native_dir)):
                sub_native = os.path.join(native_dir, sub)
                sub_cfg = os.path.join(sub_native, "build.cfg")
                if os.path.isfile(sub_cfg):
                    extensions.append((f"{entry}/{sub}", sub_native, sub_cfg))

    return extensions


def plan_extensions(
    extensions: list[tuple[str, str, str]],
    plat: str,
    *,
    tier: str = "",
    ext: str = "",
    exts: str = "",
    defaults_only: bool = False,
) -> tuple[list[tuple[str, str, str, dict]], list[tuple[str, str, str]]]:
    """
    Partition extensions into (to_build, skipped).

    to_build entries: (ext_name, native_dir, cfg_path, cfg)
    skipped entries: (ext_name, reason)
    """
    to_build: list[tuple[str, str, str, dict]] = []
    skipped: list[tuple[str, str]] = []

    for ext_name, native_dir, cfg_path in extensions:
        cfg = parse_build_cfg(cfg_path)
        ok, reason = should_build_extension(
            ext_name, cfg, plat, native_dir,
            tier=tier, ext=ext, exts=exts, defaults_only=defaults_only,
        )
        if ok:
            to_build.append((ext_name, native_dir, cfg_path, cfg))
        else:
            skipped.append((ext_name, reason))

    return to_build, skipped


def format_extension_table_row(
    ext_name: str,
    cfg: dict,
    plat: str,
    native_dir: str,
    width_name: int = 30,
) -> str:
    """Format one line for --list-extensions."""
    platforms = ", ".join(cfg.get("platforms", []))
    tier = cfg.get("tier", "extension")
    default = "yes" if cfg.get("default") else "no"
    optional = "yes" if cfg.get("optional") else "no"
    sdk = probe_status(cfg, plat, native_dir)
    return (
        f"  {ext_name:<{width_name}} "
        f"{tier:<10} "
        f"def={default:<3} "
        f"opt={optional:<3} "
        f"sdk={sdk:<7} "
        f"{cfg.get('lib_name', ''):<20} "
        f"{platforms}"
    )
