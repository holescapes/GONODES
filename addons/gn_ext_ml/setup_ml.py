#!/usr/bin/env python3
"""
setup_ml.py — Download ONNX Runtime SDK and pre-trained models for gn_ext_ml.

Downloads the ONNX Runtime C API library for the current platform, extracts
it into native/onnxruntime/, and can download the permissive ONNX models
into models/. The build calls this script with --sdk-only, so a normal
build does not fetch weights. models/ is gitignored.

Usage:
  python addons/gn_ext_ml/setup_ml.py                # SDK + all models
  python addons/gn_ext_ml/setup_ml.py --sdk-only      # SDK only, skip models
  python addons/gn_ext_ml/setup_ml.py --models-only    # Models only, skip SDK
  python addons/gn_ext_ml/setup_ml.py --version 1.19.2 # Specific ORT version

Requirements: Python 3.8+, internet connection. No extra packages needed.
"""

import argparse
import hashlib
import io
import os
import platform
import shutil
import sys
import tarfile
import urllib.request
import zipfile

# ── Configuration ─────────────────────────────────────────────────────────────

ONNXRUNTIME_VERSION = "1.19.2"

# Map (os, machine) → (archive_name_template, lib_paths_to_extract)
PLATFORM_MAP = {
    ("Windows", "AMD64"): {
        "archive": "onnxruntime-win-x64-{ver}.zip",
        "url_base": "https://github.com/microsoft/onnxruntime/releases/download/v{ver}/",
        "strip_prefix": "onnxruntime-win-x64-{ver}",
        "libs": {
            "x86_64-windows": [
                ("lib/onnxruntime.dll", "onnxruntime.dll"),
                ("lib/onnxruntime.lib", "onnxruntime.lib"),
            ],
        },
    },
    ("Linux", "x86_64"): {
        "archive": "onnxruntime-linux-x64-{ver}.tgz",
        "url_base": "https://github.com/microsoft/onnxruntime/releases/download/v{ver}/",
        "strip_prefix": "onnxruntime-linux-x64-{ver}",
        "libs": {
            "x86_64-linux": [
                ("lib/libonnxruntime.so.{ver}", "libonnxruntime.so"),
            ],
        },
    },
    ("Darwin", "x86_64"): {
        "archive": "onnxruntime-osx-universal2-{ver}.tgz",
        "url_base": "https://github.com/microsoft/onnxruntime/releases/download/v{ver}/",
        "strip_prefix": "onnxruntime-osx-universal2-{ver}",
        "libs": {
            "": [
                ("lib/libonnxruntime.{ver}.dylib", "libonnxruntime.dylib"),
            ],
        },
    },
    ("Darwin", "arm64"): {
        "archive": "onnxruntime-osx-universal2-{ver}.tgz",
        "url_base": "https://github.com/microsoft/onnxruntime/releases/download/v{ver}/",
        "strip_prefix": "onnxruntime-osx-universal2-{ver}",
        "libs": {
            "": [
                ("lib/libonnxruntime.{ver}.dylib", "libonnxruntime.dylib"),
            ],
        },
    },
}

# ONNX models with a real ONNX download. Google does not publish the
# MediaPipe landmark or selfie models as ONNX, so those are not fetched.
# Ultralytics YOLOv8 weights are AGPL-3.0 and are not fetched either.
NOT_FETCHED = [
    (
        "pose_landmark_lite.onnx",
        "MediaPipe does not publish BlazePose as ONNX. Convert it yourself and place the file here.",
    ),
    (
        "hand_landmark_lite.onnx",
        "MediaPipe does not publish the hand landmarker as ONNX. Convert it yourself and place the file here.",
    ),
    (
        "face_landmark.onnx",
        "MediaPipe does not publish the face landmarker as ONNX. Convert it yourself and place the file here.",
    ),
    (
        "selfie_segmentation.onnx",
        "MediaPipe does not publish the selfie segmenter as ONNX. Convert it yourself and place the file here.",
    ),
    (
        "yolov8n.onnx",
        "Ultralytics YOLOv8 weights are AGPL-3.0. This script does not download them. Supply your own YOLO ONNX file.",
    ),
]

MODELS = [
    {
        "file": "midas_v21_small_256.onnx",
        "url": "https://github.com/isl-org/MiDaS/releases/download/v2_1/model-small.onnx",
        "description": "MiDaS v2.1 Small — monocular depth estimation (MIT)",
    },
    {
        "file": "style_mosaic.onnx",
        "url": "https://huggingface.co/onnxmodelzoo/mosaic-9/resolve/main/mosaic-9.onnx",
        "description": "Fast neural style — mosaic (BSD-3-Clause)",
    },
    {
        "file": "style_candy.onnx",
        "url": "https://huggingface.co/onnxmodelzoo/candy-9/resolve/main/candy-9.onnx",
        "description": "Fast neural style — candy (BSD-3-Clause)",
    },
    {
        "file": "style_udnie.onnx",
        "url": "https://huggingface.co/onnxmodelzoo/udnie-9/resolve/main/udnie-9.onnx",
        "description": "Fast neural style — udnie (BSD-3-Clause)",
    },
    {
        "file": "style_rain_princess.onnx",
        "url": "https://huggingface.co/onnxmodelzoo/rain-princess-9/resolve/main/rain-princess-9.onnx",
        "description": "Fast neural style — rain princess (BSD-3-Clause)",
    },
    {
        "file": "style_pointilism.onnx",
        "url": "https://huggingface.co/onnxmodelzoo/pointilism-9/resolve/main/pointilism-9.onnx",
        "description": "Fast neural style — pointillism (BSD-3-Clause)",
    },
]

# ── Helpers ───────────────────────────────────────────────────────────────────

EXT_DIR = os.path.dirname(os.path.abspath(__file__))
NATIVE_DIR = os.path.join(EXT_DIR, "native")
ORT_DIR = os.path.join(NATIVE_DIR, "onnxruntime")
MODELS_DIR = os.path.join(EXT_DIR, "models")


def log(msg):
    print(f"  [ML] {msg}")


def download(url, dest_path, description=""):
    """Download a URL to a local file with progress."""
    label = description or os.path.basename(dest_path)
    log(f"Downloading {label}...")
    log(f"  URL: {url}")

    try:
        req = urllib.request.Request(url, headers={"User-Agent": "GONODES-Setup/1.0"})
        with urllib.request.urlopen(req, timeout=120) as resp:
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
                    sys.stdout.write(f"\r  [ML]   {mb:.1f} MB ({pct}%)")
                    sys.stdout.flush()

            if total:
                print()  # newline after progress

        os.makedirs(os.path.dirname(dest_path), exist_ok=True)
        with open(dest_path, "wb") as f:
            f.write(data)
        size_mb = len(data) / (1024 * 1024)
        log(f"  Saved: {dest_path} ({size_mb:.1f} MB)")
        return True
    except Exception as e:
        log(f"  ERROR: {e}")
        return False


def detect_platform():
    """Return platform key for PLATFORM_MAP."""
    system = platform.system()
    machine = platform.machine()
    # Normalize
    if machine in ("x86_64", "x64"):
        machine = "AMD64" if system == "Windows" else "x86_64"
    key = (system, machine)
    if key not in PLATFORM_MAP:
        log(f"Unsupported platform: {system}/{machine}")
        log(f"Supported: {list(PLATFORM_MAP.keys())}")
        return None
    return key


# ── SDK Setup ─────────────────────────────────────────────────────────────────

def setup_sdk(version):
    """Download and extract ONNX Runtime SDK."""
    pkey = detect_platform()
    if pkey is None:
        return False

    pinfo = PLATFORM_MAP[pkey]
    archive_name = pinfo["archive"].format(ver=version)
    url = pinfo["url_base"].format(ver=version) + archive_name

    # Check if already set up
    include_dir = os.path.join(ORT_DIR, "include")
    if os.path.isdir(include_dir) and os.listdir(include_dir):
        log(f"ONNX Runtime SDK already present at {ORT_DIR}")
        log(f"  Delete {ORT_DIR} and re-run to force re-download.")
        return True

    # Download to temp
    tmp_archive = os.path.join(NATIVE_DIR, archive_name)
    if not download(url, tmp_archive, f"ONNX Runtime {version}"):
        return False

    # Extract
    log(f"Extracting {archive_name}...")
    strip_prefix = pinfo["strip_prefix"].format(ver=version)

    os.makedirs(ORT_DIR, exist_ok=True)
    os.makedirs(os.path.join(ORT_DIR, "include"), exist_ok=True)

    if archive_name.endswith(".zip"):
        with zipfile.ZipFile(tmp_archive) as zf:
            # Extract include/ headers
            for member in zf.namelist():
                if f"{strip_prefix}/include/" in member:
                    rel = member.split(f"{strip_prefix}/include/", 1)[-1]
                    if rel and not member.endswith("/"):
                        dest = os.path.join(ORT_DIR, "include", rel)
                        os.makedirs(os.path.dirname(dest), exist_ok=True)
                        with zf.open(member) as src, open(dest, "wb") as dst:
                            dst.write(src.read())

            # Extract libs per platform
            for subdir, lib_pairs in pinfo["libs"].items():
                lib_dir = os.path.join(ORT_DIR, "lib", subdir) if subdir else os.path.join(ORT_DIR, "lib")
                os.makedirs(lib_dir, exist_ok=True)
                for src_rel, dest_name in lib_pairs:
                    src_path = f"{strip_prefix}/{src_rel}".format(ver=version)
                    try:
                        with zf.open(src_path) as src, open(os.path.join(lib_dir, dest_name), "wb") as dst:
                            dst.write(src.read())
                        log(f"  Extracted: {dest_name}")
                    except KeyError:
                        log(f"  WARNING: {src_path} not found in archive")

    elif archive_name.endswith(".tgz"):
        with tarfile.open(tmp_archive, "r:gz") as tf:
            for member in tf.getmembers():
                if f"{strip_prefix}/include/" in member.name and member.isfile():
                    rel = member.name.split(f"{strip_prefix}/include/", 1)[-1]
                    dest = os.path.join(ORT_DIR, "include", rel)
                    os.makedirs(os.path.dirname(dest), exist_ok=True)
                    with tf.extractfile(member) as src, open(dest, "wb") as dst:
                        dst.write(src.read())

            for subdir, lib_pairs in pinfo["libs"].items():
                lib_dir = os.path.join(ORT_DIR, "lib", subdir) if subdir else os.path.join(ORT_DIR, "lib")
                os.makedirs(lib_dir, exist_ok=True)
                for src_rel, dest_name in lib_pairs:
                    src_path = f"{strip_prefix}/{src_rel}".format(ver=version)
                    matches = [m for m in tf.getmembers() if m.name == src_path]
                    if matches:
                        with tf.extractfile(matches[0]) as src, open(os.path.join(lib_dir, dest_name), "wb") as dst:
                            dst.write(src.read())
                        log(f"  Extracted: {dest_name}")
                    else:
                        log(f"  WARNING: {src_path} not found in archive")

    # Cleanup temp archive
    os.remove(tmp_archive)

    # Ensure Godot ignores the SDK directory
    gdignore = os.path.join(ORT_DIR, ".gdignore")
    if not os.path.isfile(gdignore):
        open(gdignore, "w").close()

    log("SDK setup complete.")
    return True


# ── Models Setup ──────────────────────────────────────────────────────────────

def setup_models():
    """Download pre-trained ONNX models."""
    os.makedirs(MODELS_DIR, exist_ok=True)
    success = 0
    skipped = 0
    failed = 0

    for model in MODELS:
        dest = os.path.join(MODELS_DIR, model["file"])
        if os.path.isfile(dest):
            log(f"Already present: {model['file']}")
            skipped += 1
            continue
        if download(model["url"], dest, model["description"]):
            success += 1
        else:
            failed += 1

    for filename, reason in NOT_FETCHED:
        log(f"Not downloaded: {filename}")
        log(f"  {reason}")

    log(f"Models: {success} downloaded, {skipped} already present, {failed} failed (optional)")
    if failed:
        log("Some optional models failed to download — ML operators using those models won't work.")
    return True


# ── Enable .gdextension ──────────────────────────────────────────────────────

def enable_gdextension():
    """Rename .gdextension.disabled → .gdextension."""
    disabled = os.path.join(NATIVE_DIR, "gn_ml.gdextension.disabled")
    enabled = os.path.join(NATIVE_DIR, "gn_ml.gdextension")
    if os.path.isfile(enabled):
        log("gn_ml.gdextension already enabled.")
        return True
    if os.path.isfile(disabled):
        os.rename(disabled, enabled)
        log("Enabled gn_ml.gdextension")
        return True
    log("WARNING: Neither .gdextension nor .gdextension.disabled found")
    return False


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Setup ONNX Runtime SDK and models for gn_ext_ml")
    parser.add_argument("--sdk-only", action="store_true",
                        help="Download SDK only, skip models")
    parser.add_argument("--models-only", action="store_true",
                        help="Download models only, skip SDK")
    parser.add_argument("--version", default=ONNXRUNTIME_VERSION,
                        help=f"ONNX Runtime version (default: {ONNXRUNTIME_VERSION})")
    parser.add_argument("--no-enable", action="store_true",
                        help="Don't rename .gdextension.disabled")
    args = parser.parse_args()

    print("=" * 60)
    print("GONODES gn_ext_ml — Automated Setup")
    print("=" * 60)

    ok = True

    if not args.models_only:
        log("Phase 1: ONNX Runtime SDK")
        if not setup_sdk(args.version):
            ok = False

    if not args.sdk_only:
        print()
        log("Phase 2: Pre-trained ONNX Models")
        setup_models()

    if not args.no_enable and not args.models_only:
        print()
        log("Phase 3: Enable GDExtension")
        enable_gdextension()

    print()
    if ok:
        log("Setup complete. Build the extension with:")
        log("  cd addons/gn_ext_ml/native && scons platform=<your_platform>")
    else:
        log("Setup completed with errors — check output above.")

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
