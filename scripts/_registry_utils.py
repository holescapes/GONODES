"""Shared registry utilities for GONODES build/tooling scripts.

Provides dynamic family discovery from operator_registry.json so that
tooling scripts never need hardcoded family lists (Rule 25.33).
Extension families (SDF, user families) are automatically included.
"""
from pathlib import Path
import json

_SCRIPT_DIR = Path(__file__).resolve().parent
_REGISTRY_PATH = _SCRIPT_DIR / "operator_registry.json"

# Registry family names whose GDScript class-name suffix differs from the
# name itself.  All other families use family.upper() as the suffix.
_SUFFIX_OVERRIDES = {"output": "OUT"}

# Fallback list used when operator_registry.json doesn't exist yet
# (e.g., on a fresh clone before scan_operators.py has been run).
_FALLBACK_FAMILIES = [
    "chop", "comp", "dat", "img", "mat", "net", "output", "pop",
    "script", "sdf", "sop", "top", "ui", "vol",
]


def get_all_families(registry_path=None) -> list:
    """Return sorted list of all family names from operator_registry.json.

    Includes core AND extension families (e.g. 'sdf', 'net').
    Falls back to _FALLBACK_FAMILIES if the registry file is missing.
    """
    path = Path(registry_path) if registry_path else _REGISTRY_PATH
    if path.exists():
        try:
            ops = json.loads(path.read_text(encoding="utf-8"))
            fams = sorted({op["family"] for op in ops if op.get("family")})
            if fams:
                return fams
        except Exception:
            pass
    return list(_FALLBACK_FAMILIES)


def family_to_suffix(family: str) -> str:
    """Convert a registry family name to its GDScript class-name suffix.

    e.g. 'output' -> 'OUT', 'chop' -> 'CHOP', 'sdf' -> 'SDF'
    """
    return _SUFFIX_OVERRIDES.get(family, family.upper())


def get_all_suffixes(registry_path=None) -> list:
    """Return sorted list of GDScript class-name suffixes derived from all families.

    e.g. ['CHOP', 'COMP', 'DAT', 'IMG', 'MAT', 'NET', 'OUT', ...]
    """
    return sorted({family_to_suffix(f) for f in get_all_families(registry_path)})
