#!/usr/bin/env python3
"""
gn_ext_webrender — CEF Artifact Setup

Downloads prebuilt gdCEF binaries from the official GitHub release into
addons/gn_ext_webrender/cef_artifacts/.  The version is read from
versions.env at the project root.

Run standalone:
    python setup_cef.py               # download + extract
    python setup_cef.py --no-enable   # (same — called by setup_deps.py)
    python setup_cef.py --force       # re-download even if already present
    python setup_cef.py --clean       # remove cef_artifacts/ directory

Called by setup_deps.py and by GitHub Actions from the setup line in
native/build.cfg. That file is download_only, so nothing here is compiled.
"""
import argparse
import io
import os
import platform
import shutil
import sys
import urllib.request
import zipfile

# ── Paths ──────────────────────────────────────────────────────────────────
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
CEF_DIR = os.path.join(SCRIPT_DIR, "cef_artifacts")


def _load_versions_env() -> dict:
    """Read key=value pairs from versions.env at project root."""
    env_file = os.path.join(PROJECT_ROOT, "versions.env")
    vals = {}
    if os.path.isfile(env_file):
        with open(env_file, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    k, v = line.split("=", 1)
                    vals[k.strip()] = v.strip()
    return vals


def _current_version() -> str | None:
    """Read the installed gdCEF version from cef_artifacts/VERSION."""
    ver_file = os.path.join(CEF_DIR, "VERSION")
    if not os.path.isfile(ver_file):
        return None
    with open(ver_file, encoding="utf-8") as f:
        for line in f:
            if line.startswith("gdCEF Version:"):
                return line.split(":", 1)[1].strip()
    return None


def download_and_extract(version: str, godot_ver: str, force: bool = False) -> bool:
    """Download the gdCEF release zip and extract cef_artifacts/.

    Returns True if artifacts were installed, False if skipped.
    """
    # Check if already present and up-to-date
    installed = _current_version()
    if installed == version and not force:
        print(f"  [skip] gdCEF {version} already installed at {os.path.relpath(CEF_DIR, PROJECT_ROOT)}")
        return True

    if installed and installed != version:
        print(f"  Upgrading gdCEF {installed} → {version}")

    # Construct download URL
    # Pattern: https://github.com/Lecrapouille/gdcef/releases/download/v{VER}-godot4/gdcef-{VER}_godot-{GODOT}.zip
    tag = f"v{version}-godot4"
    zip_name = f"gdcef-{version}_godot-{godot_ver}.zip"
    url = f"https://github.com/Lecrapouille/gdcef/releases/download/{tag}/{zip_name}"

    print(f"  Downloading gdCEF {version} from:")
    print(f"    {url}")
    print(f"  This download is ~550 MB — please be patient...")

    try:
        req = urllib.request.Request(url, headers={"User-Agent": "GONODES-setup/1.0"})
        with urllib.request.urlopen(req, timeout=600) as response:
            data = response.read()
    except urllib.error.HTTPError as e:
        print(f"  [ERROR] Download failed: HTTP {e.code} — {e.reason}")
        print(f"  URL: {url}")
        print(f"  Check that gdCEF version {version} exists at:")
        print(f"    https://github.com/Lecrapouille/gdcef/releases")
        return False
    except Exception as e:
        print(f"  [ERROR] Download failed: {e}")
        return False

    print(f"  Downloaded {len(data) / (1024 * 1024):.1f} MB — extracting...")

    # The zip contains: gdcef/cef_artifacts/{files}
    # We want to extract to: addons/gn_ext_webrender/cef_artifacts/{files}
    # Preserve our .gdextension.disabled naming (upstream ships .gdextension)
    with zipfile.ZipFile(io.BytesIO(data)) as zf:
        # Find the cef_artifacts prefix inside the zip
        prefix = None
        for name in zf.namelist():
            # Look for the VERSION file to identify the root
            if name.endswith("cef_artifacts/VERSION"):
                prefix = name[: name.index("cef_artifacts/") + len("cef_artifacts/")]
                break

        if prefix is None:
            print("  [ERROR] Could not find cef_artifacts/ in zip — unexpected archive format")
            return False

        # Remove old artifacts (but keep .gdextension.disabled if present)
        had_disabled = os.path.isfile(os.path.join(CEF_DIR, "gdcef.gdextension.disabled"))
        if os.path.isdir(CEF_DIR):
            shutil.rmtree(CEF_DIR)
        os.makedirs(CEF_DIR, exist_ok=True)

        # Extract matching entries
        for info in zf.infolist():
            if not info.filename.startswith(prefix):
                continue
            # Compute destination relative path
            rel = info.filename[len(prefix):]
            if not rel:
                continue
            dest = os.path.join(CEF_DIR, rel)
            if info.is_dir():
                os.makedirs(dest, exist_ok=True)
            else:
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                with zf.open(info) as src, open(dest, "wb") as dst:
                    shutil.copyfileobj(src, dst)
                # Preserve executable bit on Unix
                if platform.system() != "Windows":
                    unix_attrs = info.external_attr >> 16
                    if unix_attrs and (unix_attrs & 0o111):
                        os.chmod(dest, 0o755)

    # Rename .gdextension → .gdextension.disabled so auto-activation handles it
    active_ext = os.path.join(CEF_DIR, "gdcef.gdextension")
    disabled_ext = os.path.join(CEF_DIR, "gdcef.gdextension.disabled")
    if os.path.isfile(active_ext):
        # We need to patch the paths in the .gdextension to point to our location
        _patch_gdextension_paths(active_ext)
        os.rename(active_ext, disabled_ext)

    print(f"  [done] gdCEF {version} installed to {os.path.relpath(CEF_DIR, PROJECT_ROOT)}")
    print(f"         .gdextension saved as .disabled — Godot auto-activation will enable it")
    return True


def _patch_gdextension_paths(ext_path: str) -> None:
    """Rewrite library paths in the .gdextension to point to our extension folder.

    Upstream ships paths like res://cef_artifacts/windows/libgdcef.dll.
    We need res://addons/gn_ext_webrender/cef_artifacts/windows/libgdcef.dll.
    """
    with open(ext_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Replace the generic cef_artifacts/ prefix with our extension-local path
    patched = content.replace(
        '"res://cef_artifacts/',
        '"res://addons/gn_ext_webrender/cef_artifacts/',
    )

    with open(ext_path, "w", encoding="utf-8", newline="") as f:
        f.write(patched)


def clean():
    """Remove the cef_artifacts directory entirely."""
    if os.path.isdir(CEF_DIR):
        print(f"  Removing {os.path.relpath(CEF_DIR, PROJECT_ROOT)} ...")
        shutil.rmtree(CEF_DIR)
        print("  [done] cef_artifacts removed")
    else:
        print("  [skip] cef_artifacts not present")


def main():
    parser = argparse.ArgumentParser(description="Download gdCEF prebuilt binaries")
    parser.add_argument("--force", action="store_true", help="Re-download even if already present")
    parser.add_argument("--clean", action="store_true", help="Remove cef_artifacts directory")
    parser.add_argument("--no-enable", action="store_true", help="(Unused — kept for setup_deps.py compat)")
    args = parser.parse_args()

    if args.clean:
        clean()
        return

    versions = _load_versions_env()
    gdcef_ver = versions.get("GDCEF_VERSION")
    gdcef_godot = versions.get("GDCEF_GODOT")

    if not gdcef_ver or not gdcef_godot:
        print("  [ERROR] GDCEF_VERSION or GDCEF_GODOT not found in versions.env")
        print("  Expected entries:")
        print("    GDCEF_VERSION=0.19.2")
        print("    GDCEF_GODOT=4.5")
        sys.exit(1)

    if not download_and_extract(gdcef_ver, gdcef_godot, force=args.force):
        sys.exit(1)


if __name__ == "__main__":
    main()
