#!/usr/bin/env python3
"""
setup_opencv.py — Download OpenCV SDK for gn_ext_opencv (Windows).

On Windows, downloads the official OpenCV self-extracting archive, extracts it
into native/opencv_sdk/, and verifies headers + import library are present.

On Linux/macOS, prints package-manager instructions (system OpenCV is linked
at build time — no SDK files are placed in the repo).

Usage:
  python addons/gn_ext_opencv/setup_opencv.py
  python addons/gn_ext_opencv/setup_opencv.py --version 4.10.0
  python addons/gn_ext_opencv/setup_opencv.py --verify
  python addons/gn_ext_opencv/setup_opencv.py --no-enable

Requirements: Python 3.8+, internet connection (Windows download only).
"""

import argparse
import os
import platform
import shutil
import subprocess
import sys
import urllib.request

OPENCV_VERSION = "4.10.0"

EXT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(EXT_DIR))
NATIVE_DIR = os.path.join(EXT_DIR, "native")
SDK_ROOT = os.path.join(NATIVE_DIR, "opencv_sdk")
SDK_OPENCV = os.path.join(SDK_ROOT, "opencv")

# Relative to native/ — must match build.cfg [windows] probe path.
WIN_PROBE_REL = "opencv_sdk/opencv/build/x64/vc16/lib/opencv_world4100.lib"
WIN_DLL_REL = "opencv_sdk/opencv/build/x64/vc16/bin/opencv_world4100.dll"


def log(msg: str) -> None:
    print(f"  [CV] {msg}")


def _probe_ok() -> bool:
    probe = os.path.join(NATIVE_DIR, WIN_PROBE_REL)
    return os.path.isfile(probe)


def download(url: str, dest_path: str, description: str = "") -> bool:
    label = description or os.path.basename(dest_path)
    log(f"Downloading {label}...")
    log(f"  URL: {url}")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "GONODES-Setup/1.0"})
        with urllib.request.urlopen(req, timeout=300) as resp:
            total = resp.headers.get("Content-Length")
            total = int(total) if total else None
            data = bytearray()
            chunk_size = 256 * 1024
            while True:
                chunk = resp.read(chunk_size)
                if not chunk:
                    break
                data.extend(chunk)
                if total:
                    pct = len(data) * 100 // total
                    mb = len(data) / (1024 * 1024)
                    sys.stdout.write(f"\r  [CV]   {mb:.1f} MB ({pct}%)")
                    sys.stdout.flush()
            if total:
                print()
        os.makedirs(os.path.dirname(dest_path), exist_ok=True)
        with open(dest_path, "wb") as f:
            f.write(data)
        log(f"  Saved: {dest_path} ({len(data) / (1024 * 1024):.1f} MB)")
        return True
    except Exception as e:
        log(f"  ERROR: {e}")
        return False


def _ensure_gdignore(directory: str) -> None:
    marker = os.path.join(directory, ".gdignore")
    if not os.path.isfile(marker):
        os.makedirs(directory, exist_ok=True)
        open(marker, "w").close()


def setup_windows(version: str) -> bool:
    if _probe_ok():
        log(f"OpenCV SDK already present ({WIN_PROBE_REL})")
        return True

    archive_name = f"opencv-{version}-windows.exe"
    url = f"https://github.com/opencv/opencv/releases/download/{version}/{archive_name}"
    archive_path = os.path.join(NATIVE_DIR, archive_name)
    extract_dir = os.path.join(NATIVE_DIR, "opencv_extract")

    if not os.path.isfile(archive_path):
        if not download(url, archive_path, f"OpenCV {version} Windows"):
            return False

    log(f"Extracting {archive_name}...")
    os.makedirs(extract_dir, exist_ok=True)
    try:
        subprocess.run(
            [archive_path, f"-o{extract_dir}", "-y"],
            check=True,
            timeout=600,
        )
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError) as e:
        log(f"  ERROR: extraction failed: {e}")
        return False

    extracted_opencv = os.path.join(extract_dir, "opencv")
    if not os.path.isdir(extracted_opencv):
        log(f"  ERROR: expected {extracted_opencv} after extraction")
        return False

    if os.path.isdir(SDK_OPENCV):
        log("Removing stale opencv_sdk/opencv/ ...")
        shutil.rmtree(SDK_OPENCV)

    os.makedirs(SDK_ROOT, exist_ok=True)
    shutil.copytree(extracted_opencv, SDK_OPENCV)
    _ensure_gdignore(SDK_ROOT)

    if not _probe_ok():
        log(f"  ERROR: probe file missing after setup: {WIN_PROBE_REL}")
        log("  The archive may use a different MSVC folder (vc17 vs vc16).")
        log("  See addons/gn_ext_opencv/README.md for manual placement.")
        return False

    dll_src = os.path.join(NATIVE_DIR, WIN_DLL_REL)
    if os.path.isfile(dll_src):
        bin_dir = os.path.join(NATIVE_DIR, "bin", "win64")
        os.makedirs(bin_dir, exist_ok=True)
        dll_dst = os.path.join(bin_dir, os.path.basename(dll_src))
        if not os.path.isfile(dll_dst):
            shutil.copy2(dll_src, dll_dst)
            log(f"  Copied runtime DLL to {os.path.relpath(dll_dst, EXT_DIR)}")

    log("Windows OpenCV SDK setup complete.")
    return True


def setup_unix() -> bool:
    system = platform.system()
    if system == "Linux":
        log("Linux: install system OpenCV development packages, then build:")
        log("  sudo apt install libopencv-dev        # Debian/Ubuntu")
        log("  sudo dnf install opencv-devel         # Fedora")
    else:
        log("macOS: install OpenCV via Homebrew, then build:")
        log("  brew install opencv")
    log("No SDK files are copied into native/opencv_sdk/ on this platform.")
    return True


def enable_gdextension() -> bool:
    disabled = os.path.join(EXT_DIR, "gn_opencv.gdextension.disabled")
    enabled = os.path.join(EXT_DIR, "gn_opencv.gdextension")
    if os.path.isfile(enabled):
        log("gn_opencv.gdextension already enabled.")
        return True
    if os.path.isfile(disabled):
        os.rename(disabled, enabled)
        log("Enabled gn_opencv.gdextension (build the native library to load it).")
        return True
    log("WARNING: Neither .gdextension nor .gdextension.disabled found")
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description="Setup OpenCV SDK for gn_ext_opencv")
    parser.add_argument("--version", default=OPENCV_VERSION,
                        help=f"OpenCV version (default: {OPENCV_VERSION})")
    parser.add_argument("--verify", action="store_true",
                        help="Only verify SDK presence; exit 1 if missing (Windows)")
    parser.add_argument("--no-enable", action="store_true",
                        help="Do not rename .gdextension.disabled")
    args = parser.parse_args()

    print("=" * 60)
    print("GONODES gn_ext_opencv — OpenCV SDK Setup")
    print("=" * 60)

    if args.verify:
        if platform.system() == "Windows":
            ok = _probe_ok()
            if ok:
                log("OpenCV SDK probe OK")
            else:
                log(f"OpenCV SDK missing — run: python addons/gn_ext_opencv/setup_opencv.py")
            return 0 if ok else 1
        log("Verify skipped on non-Windows (system OpenCV)")
        return 0

    ok = setup_windows(args.version) if platform.system() == "Windows" else setup_unix()

    if ok and not args.no_enable and platform.system() == "Windows":
        print()
        enable_gdextension()

    print()
    if ok:
        log("Next: build the extension:")
        log("  cd build && scons ext=gn_ext_opencv platform=<your_platform> -j8")
        return 0
    log("Setup failed — see messages above or README.md for manual steps.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
