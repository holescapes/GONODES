#!/usr/bin/env python3
"""Leave unsupported native extensions out of one platform's player export.

Godot loads every .gdextension packed into the player. A config that only has
a Windows library still produces "library not found" on Linux ARM64. This
script adds those extension folders to the export preset's exclude filter
for the platform being built. The project tree is not edited. The original
export_presets.cfg is kept beside it and put back by --restore.

An extension stays in the export when its library for that OS and architecture
is on disk at export time. A library installed only on the target machine is
not used: the player opens the file named in the .gdextension, which has to
be copied into the export.
"""

from __future__ import annotations

import argparse
import configparser
import re
import shutil
import sys
from pathlib import Path


# Keys Godot will actually select for that export. Arch-specific.
# A bare "linux=" entry is not treated as ARM64: that file is the other arch.
PLATFORM_KEYS: dict[str, list[str]] = {
    "windows_x86_64": [
        "windows.x86_64.release", "windows.x86_64.debug",
        "windows.release.x86_64", "windows.debug.x86_64",
    ],
    "windows_arm64": [
        "windows.arm64.release", "windows.arm64.debug",
        "windows.release.arm64", "windows.debug.arm64",
    ],
    "linux_x86_64": [
        "linux.x86_64.release", "linux.x86_64.debug",
        "linux.release.x86_64", "linux.debug.x86_64",
    ],
    "linux_arm64": [
        "linux.arm64.release", "linux.arm64.debug",
        "linux.release.arm64", "linux.debug.arm64",
    ],
    "macos": [
        "macos.release", "macos.debug", "macos",
        "macos.arm64.release", "macos.x86_64.release",
        "macos.release.arm64", "macos.release.x86_64",
        "macos.arm64.debug", "macos.x86_64.debug",
    ],
    "android": [
        "android.release.arm64", "android.arm64.release",
        "android.debug.arm64", "android.arm64.debug",
    ],
    "ios": [
        "ios.release", "ios.debug",
        "ios.release.arm64", "ios.arm64.release",
        "ios.debug.arm64", "ios.arm64.debug",
    ],
    "web": ["web.release", "web.debug", "web"],
}


def _library_file_exists(project: Path, raw_value: str) -> bool:
    value = raw_value.strip().strip('"').strip("'")
    if not value:
        return False
    if value.startswith("res://"):
        value = value[len("res://"):]
    return (project / value).is_file()


def _read_libraries(config_path: Path) -> dict[str, str]:
    cfg = configparser.RawConfigParser()
    try:
        cfg.read(config_path, encoding="utf-8")
    except configparser.Error:
        return {}
    if not cfg.has_section("libraries"):
        return {}
    return {key: cfg.get("libraries", key) for key in cfg.options("libraries")}


def extension_supports_platform(config_path: Path, project: Path, platform: str) -> bool:
    keys = PLATFORM_KEYS.get(platform, [])
    libraries = _read_libraries(config_path)
    for key in keys:
        if key in libraries and _library_file_exists(project, libraries[key]):
            return True
    return False


def _addon_name(addons: Path, config_path: Path) -> str:
    rel = config_path.resolve().relative_to(addons.resolve())
    return rel.parts[0]


def folders_to_omit(project: Path, platform: str) -> list[str]:
    """Addon folders that must not be packed for this platform.

    A folder is omitted when every native extension in it lacks a library
    for the platform, or when the build already removed the .gdextension
    (mode none, or an addon that was not on the allow list).
    """
    addons = project / "addons"
    if not addons.is_dir():
        return []

    by_folder: dict[str, dict[str, object]] = {}
    candidates: list[Path] = []
    candidates.extend(p for p in addons.rglob("*") if p.is_file() and (
        p.name.endswith(".gdextension") or p.name.endswith(".gdextension.bak")))
    for path in candidates:
        if "godot-cpp" in path.parts:
            continue
        if path.name.endswith(".gdextension.bak"):
            original = path
            live = Path(str(path)[:-4])
        else:
            bak = Path(str(path) + ".bak")
            original = bak if bak.is_file() else path
            live = path
        folder = _addon_name(addons, original)
        entry = by_folder.setdefault(folder, {"configs": [], "live": False})
        configs: list[Path] = entry["configs"]  # type: ignore[assignment]
        if original not in configs:
            configs.append(original)
        if live.is_file():
            entry["live"] = True

    omitted: list[str] = []
    for folder, entry in sorted(by_folder.items()):
        configs = entry["configs"]
        if entry["live"] and any(
            extension_supports_platform(cfg, project, platform) for cfg in configs  # type: ignore[union-attr]
        ):
            continue
        omitted.append(folder)
    return omitted


def exclude_patterns(folders: list[str]) -> str:
    parts = ["export_presets.cfg"]
    for folder in folders:
        parts.append(f"addons/{folder}/*")
        parts.append(f"res://addons/{folder}/*")
    return ",".join(parts)


_PRESET_RE = re.compile(
    r'(\[preset\.\d+\]\s+name="(?P<name>[^"]+)"\s+.*?^exclude_filter=")([^"]*)(")',
    re.MULTILINE | re.DOTALL,
)


def set_preset_exclude(text: str, preset_name: str, exclude_value: str) -> str:
    found = False

    def replacer(match: re.Match[str]) -> str:
        nonlocal found
        if match.group("name") != preset_name:
            return match.group(0)
        found = True
        return f"{match.group(1)}{exclude_value}{match.group(3)}"

    updated = _PRESET_RE.sub(replacer, text)
    if not found:
        raise SystemExit(f"export preset not found: {preset_name}")
    return updated


def backup_path_for(presets: Path) -> Path:
    return presets.with_name(presets.name + ".gdextbak")


def apply_filter(presets: Path, preset_name: str, exclude_value: str) -> None:
    backup = backup_path_for(presets)
    if not backup.is_file():
        shutil.copy2(presets, backup)
    original = backup.read_text(encoding="utf-8")
    updated = set_preset_exclude(original, preset_name, exclude_value)
    presets.write_text(updated, encoding="utf-8", newline="\n")


def restore_presets(presets: Path) -> None:
    backup = backup_path_for(presets)
    if not backup.is_file():
        return
    shutil.move(str(backup), str(presets))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--platform", default="")
    parser.add_argument("--preset", default="")
    parser.add_argument("--presets", type=Path, default=None)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--restore", action="store_true")
    args = parser.parse_args(argv)

    project = args.project.resolve()
    presets = args.presets or (project / "export_presets.cfg")

    if args.restore:
        restore_presets(presets)
        return 0

    if args.platform not in PLATFORM_KEYS:
        print(f"unknown platform: {args.platform}", file=sys.stderr)
        return 2

    folders = folders_to_omit(project, args.platform)
    print(f"OMIT {args.platform} ({len(folders)}): {', '.join(folders)}")

    if args.apply:
        if not args.preset:
            print("--apply requires --preset", file=sys.stderr)
            return 2
        apply_filter(presets, args.preset, exclude_patterns(folders))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
