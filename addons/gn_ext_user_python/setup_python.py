#!/usr/bin/env python3
"""
setup_python.py — Download CPython embeddable + NumPy for gn_ext_user_python.

Downloads the CPython embeddable package for the current platform, installs
pip + NumPy into it, and enables the .gdextension file.

The resulting toolchain/python/ directory is self-contained — no system
Python needed at runtime.

Usage:
  python addons/gn_ext_user_python/setup_python.py
  python addons/gn_ext_user_python/setup_python.py --python-version 3.12.8
  python addons/gn_ext_user_python/setup_python.py --skip-numpy
  python addons/gn_ext_user_python/setup_python.py --verify

Requirements: Python 3.8+ (for running this script), internet connection.
"""

import argparse
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import urllib.request
import zipfile

# ── Configuration ─────────────────────────────────────────────────────────────

PYTHON_VERSION = "3.10.11"  # Must match libgn_python.dll — compiled against Python 3.10

EXT_DIR = os.path.dirname(os.path.abspath(__file__))
TOOLCHAIN_DIR = os.path.join(EXT_DIR, "toolchain", "python")
TOOLCHAIN_PARENT = os.path.join(EXT_DIR, "toolchain")
NATIVE_DIR = os.path.join(EXT_DIR, "native")


def log(msg):
    print(f"  [PY] {msg}")


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
                    sys.stdout.write(f"\r  [PY]   {mb:.1f} MB ({pct}%)")
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


# ── Windows: Embeddable Package ───────────────────────────────────────────────

def setup_windows(version, skip_numpy):
    """Download CPython embeddable + dev headers + pip + NumPy on Windows."""
    major, minor, patch = version.split(".")
    ver_short = f"{major}{minor}"

    # Check if already set up
    python_exe = os.path.join(TOOLCHAIN_DIR, "python.exe")
    if os.path.isfile(python_exe):
        log(f"Python already present at {TOOLCHAIN_DIR}")
        log(f"  Delete {TOOLCHAIN_DIR} and re-run to force re-download.")
        # Still try to install numpy if missing
        if not skip_numpy:
            _install_numpy_windows(python_exe, ver_short)
        return True

    # Download embeddable zip
    archive_name = f"python-{version}-embed-amd64.zip"
    url = f"https://www.python.org/ftp/python/{version}/{archive_name}"

    tmp_archive = os.path.join(EXT_DIR, "toolchain", archive_name)
    if not download(url, tmp_archive, f"CPython {version} embeddable (amd64)"):
        return False

    # Extract
    log(f"Extracting {archive_name} to {TOOLCHAIN_DIR}...")
    os.makedirs(TOOLCHAIN_DIR, exist_ok=True)
    with zipfile.ZipFile(tmp_archive) as zf:
        zf.extractall(TOOLCHAIN_DIR)
    os.remove(tmp_archive)

    # Download NuGet dev package for headers + libs
    log("Downloading Python dev headers + libs (NuGet package)...")
    nuget_name = f"python.{version}.nupkg"
    nuget_url = f"https://www.nuget.org/api/v2/package/python/{version}"
    tmp_nuget = os.path.join(EXT_DIR, "toolchain", nuget_name)
    if download(nuget_url, tmp_nuget, f"Python {version} NuGet (dev headers + libs)"):
        # NuGet packages are just zip files — extract include/ and libs/
        with zipfile.ZipFile(tmp_nuget) as nf:
            for member in nf.namelist():
                # Extract tools/include/* → toolchain/python/include/
                if member.startswith("tools/include/") and not member.endswith("/"):
                    rel = member[len("tools/include/"):]
                    dest = os.path.join(TOOLCHAIN_DIR, "include", rel)
                    os.makedirs(os.path.dirname(dest), exist_ok=True)
                    with nf.open(member) as src, open(dest, "wb") as dst:
                        dst.write(src.read())
                # Extract tools/libs/* → toolchain/python/libs/
                elif member.startswith("tools/libs/") and not member.endswith("/"):
                    rel = member[len("tools/libs/"):]
                    dest = os.path.join(TOOLCHAIN_DIR, "libs", rel)
                    os.makedirs(os.path.dirname(dest), exist_ok=True)
                    with nf.open(member) as src, open(dest, "wb") as dst:
                        dst.write(src.read())

        os.remove(tmp_nuget)
        python_h = os.path.join(TOOLCHAIN_DIR, "include", "Python.h")
        python_lib = os.path.join(TOOLCHAIN_DIR, "libs", f"python{ver_short}.lib")
        if os.path.isfile(python_h):
            log(f"  Dev headers extracted: include/Python.h")
        else:
            log(f"  WARNING: Python.h not found after extraction")
        if os.path.isfile(python_lib):
            log(f"  Dev library extracted: libs/python{ver_short}.lib")
        else:
            log(f"  WARNING: python{ver_short}.lib not found after extraction")
    else:
        log("WARNING: Could not download dev package. Build will need system Python dev files.")

    # Patch ._pth file to enable site-packages (required for pip/numpy)
    pth_file = os.path.join(TOOLCHAIN_DIR, f"python{ver_short}._pth")
    if os.path.isfile(pth_file):
        log(f"Patching {os.path.basename(pth_file)} to enable import site...")
        text = open(pth_file, "r", encoding="utf-8").read()
        text = text.replace("#import site", "import site")
        if "import site" not in text:
            text += "\nimport site\n"
        open(pth_file, "w", encoding="utf-8").write(text)

    # Install pip via get-pip.py
    log("Installing pip via get-pip.py...")
    getpip_path = os.path.join(TOOLCHAIN_DIR, "get-pip.py")
    if not download(
        "https://bootstrap.pypa.io/get-pip.py",
        getpip_path,
        "get-pip.py"
    ):
        return False

    result = subprocess.run(
        [python_exe, getpip_path, "--no-warn-script-location"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        log(f"pip install failed: {result.stderr}")
        return False
    log("pip installed successfully.")
    os.remove(getpip_path)

    # Install numpy
    if not skip_numpy:
        _install_numpy_windows(python_exe, ver_short)

    return True


def _install_numpy_windows(python_exe, ver_short):
    """Install NumPy into the embeddable Python.

    libgn_python.dll was compiled against the NumPy 1.x C API (NPY_1_7_API_VERSION).
    NumPy 2.0 restructured its internal C module (numpy.core → numpy._core) in a
    way that hard-crashes old import_array() calls instead of raising a Python
    exception.  Pin to <2 until the extension is rebuilt against NumPy 2.x headers.
    """
    NUMPY_CONSTRAINT = "numpy<2"

    # Check if already installed at a compatible version
    result = subprocess.run(
        [python_exe, "-c",
         "import numpy; v=tuple(int(x) for x in numpy.__version__.split('.')[:2]); "
         "exit(0 if v < (2, 0) else 1)"],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        ver_result = subprocess.run(
            [python_exe, "-c", "import numpy; print(numpy.__version__)"],
            capture_output=True, text=True
        )
        log(f"NumPy already installed (compatible): {ver_result.stdout.strip()}")
        return True

    log(f"Installing {NUMPY_CONSTRAINT}...")
    result = subprocess.run(
        [python_exe, "-m", "pip", "install", NUMPY_CONSTRAINT,
         "--no-warn-script-location"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        log(f"NumPy install failed: {result.stderr}")
        return False

    # Verify
    result = subprocess.run(
        [python_exe, "-c", "import numpy; print(numpy.__version__)"],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        log(f"NumPy installed: {result.stdout.strip()}")
    return True


# ── Linux ─────────────────────────────────────────────────────────────────────

def setup_linux(version, skip_numpy):
    """Set up Python on Linux using system packages or building from source."""
    major, minor, _ = version.split(".")

    # Check system Python first
    for cmd in [f"python{major}.{minor}", "python3", "python"]:
        py = shutil.which(cmd)
        if py:
            result = subprocess.run(
                [py, "-c", f"import sys; assert sys.version_info >= ({major},{minor})"],
                capture_output=True
            )
            if result.returncode == 0:
                log(f"System Python found: {py}")
                # Check for dev headers
                result = subprocess.run(
                    [py, "-c", "import sysconfig; print(sysconfig.get_path('include'))"],
                    capture_output=True, text=True
                )
                inc_dir = result.stdout.strip()
                python_h = os.path.join(inc_dir, "Python.h")
                if os.path.isfile(python_h):
                    log(f"Python dev headers found: {inc_dir}")
                    if not skip_numpy:
                        _ensure_numpy_system(py)
                    _write_toolchain_env(py)
                    return True
                else:
                    log(f"Python dev headers NOT found at {inc_dir}")
                    log(f"  Install: sudo apt install python{major}.{minor}-dev")
                    log(f"  Or: sudo dnf install python{major}.{minor}-devel")
                    return False

    log(f"Python {major}.{minor}+ not found on system.")
    log(f"  Install: sudo apt install python{major}.{minor} python{major}.{minor}-dev python3-numpy")
    return False


def _ensure_numpy_system(py_exe):
    """Ensure NumPy is installed for the system Python."""
    result = subprocess.run(
        [py_exe, "-c", "import numpy; print(numpy.__version__)"],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        log(f"NumPy already installed: {result.stdout.strip()}")
        return True
    log("Installing NumPy...")
    result = subprocess.run(
        [py_exe, "-m", "pip", "install", "numpy", "--user"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        log(f"NumPy install failed. Try: sudo apt install python3-numpy")
        return False
    log("NumPy installed.")
    return True


# ── macOS ─────────────────────────────────────────────────────────────────────

def setup_macos(version, skip_numpy):
    """Set up Python on macOS via Homebrew or system Python."""
    major, minor, _ = version.split(".")

    for cmd in [f"python{major}.{minor}", f"python{major}", "python3"]:
        py = shutil.which(cmd)
        if py:
            result = subprocess.run(
                [py, "-c", f"import sys; assert sys.version_info >= ({major},{minor})"],
                capture_output=True
            )
            if result.returncode == 0:
                log(f"Python found: {py}")
                if not skip_numpy:
                    _ensure_numpy_system(py)
                _write_toolchain_env(py)
                return True

    log(f"Python {major}.{minor}+ not found.")
    log(f"  Install: brew install python@{major}.{minor} numpy")
    return False


# ── Helpers ───────────────────────────────────────────────────────────────────

def _write_toolchain_env(py_exe):
    """Write a toolchain/python_env.json with discovered paths for the build."""
    try:
        result = subprocess.run(
            [py_exe, os.path.join(NATIVE_DIR, "python_config.py"), "--json"],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            env_path = os.path.join(EXT_DIR, "toolchain", "python_env.json")
            os.makedirs(os.path.dirname(env_path), exist_ok=True)
            with open(env_path, "w", encoding="utf-8") as f:
                f.write(result.stdout)
            log(f"Wrote Python environment info to {env_path}")
    except Exception as e:
        log(f"Could not write python_env.json: {e}")


def enable_gdextension():
    """Rename .gdextension.disabled → .gdextension."""
    disabled = os.path.join(EXT_DIR, "gn_python.gdextension.disabled")
    enabled = os.path.join(EXT_DIR, "gn_python.gdextension")
    if os.path.isfile(enabled):
        log("gn_python.gdextension already enabled.")
    elif os.path.isfile(disabled):
        os.rename(disabled, enabled)
        log("Enabled gn_python.gdextension")
    else:
        log("WARNING: Neither .gdextension nor .gdextension.disabled found")
        return False
    # Always ensure Python DLLs are linked
    link_python_dlls()
    return True


def link_python_dlls():
    """Copy Python DLLs next to the extension binary so Windows can find them.

    Godot loads the .gdextension DLL at engine startup, before any GDScript
    runs. The DLL is linked against python312.lib, so Windows needs python312.dll
    in the DLL's own directory (or on PATH). We copy from toolchain/python/.
    """
    if platform.system() != "Windows":
        return  # Linux/macOS use rpath or system library paths

    bin_dir = os.path.join(NATIVE_DIR, "bin", "win64")
    if not os.path.isdir(bin_dir):
        return  # Extension not built yet

    for dll_name in ["python3.dll", "python312.dll"]:
        src = os.path.join(TOOLCHAIN_DIR, dll_name)
        dst = os.path.join(bin_dir, dll_name)
        if os.path.isfile(src) and not os.path.isfile(dst):
            shutil.copy2(src, dst)
            log(f"Copied {dll_name} \u2192 native/bin/win64/")
        elif os.path.isfile(dst):
            # Check if toolchain version is newer
            if os.path.isfile(src) and os.path.getmtime(src) > os.path.getmtime(dst):
                shutil.copy2(src, dst)
                log(f"Updated {dll_name} \u2192 native/bin/win64/")


# ── Verify ────────────────────────────────────────────────────────────────────

def verify_toolchain() -> int:
    """Check that the bundled Python toolchain is present and functional."""
    ok = True

    if not os.path.isdir(TOOLCHAIN_DIR):
        log(f"[X] toolchain/python/ — MISSING")
        log(f"    Run without --verify to download.")
        return 1

    # Check python executable
    if platform.system() == "Windows":
        python_exe = os.path.join(TOOLCHAIN_DIR, "python.exe")
    else:
        python_exe = os.path.join(TOOLCHAIN_DIR, "bin", "python3")

    if os.path.isfile(python_exe):
        result = subprocess.run(
            [python_exe, "--version"],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            log(f"[+] Python: {result.stdout.strip()}")
        else:
            log(f"[X] Python executable found but failed to run")
            ok = False
    else:
        log(f"[X] Python executable not found at {python_exe}")
        ok = False

    # Check NumPy
    if os.path.isfile(python_exe):
        result = subprocess.run(
            [python_exe, "-c", "import numpy; print(numpy.__version__)"],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            log(f"[+] NumPy: {result.stdout.strip()}")
        else:
            log(f"[X] NumPy — NOT INSTALLED")
            ok = False

    # Check .gdextension
    gdext = os.path.join(EXT_DIR, "gn_python.gdextension")
    if os.path.isfile(gdext):
        log(f"[+] gn_python.gdextension enabled")
    else:
        disabled = gdext + ".disabled"
        if os.path.isfile(disabled):
            log(f"[!] gn_python.gdextension.disabled — not enabled")
        else:
            log(f"[X] gn_python.gdextension — MISSING")
            ok = False

    # Check Python DLLs next to extension binary (Windows only)
    if platform.system() == "Windows":
        bin_dir = os.path.join(NATIVE_DIR, "bin", "win64")
        for dll_name in ["python3.dll", "python312.dll"]:
            dll_path = os.path.join(bin_dir, dll_name)
            if os.path.isfile(dll_path):
                size_mb = os.path.getsize(dll_path) / (1024 * 1024)
                log(f"[+] native/bin/win64/{dll_name} ({size_mb:.1f} MB)")
            else:
                log(f"[X] native/bin/win64/{dll_name} — MISSING (Godot can't load the extension)")
                log(f"    Run: python setup_python.py  (copies from toolchain/)")
                ok = False

    print("-" * 50)
    if ok:
        log("Toolchain ready!")
    else:
        log("Toolchain incomplete — run without --verify to install.")
    return 0 if ok else 1


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Setup CPython + NumPy for gn_ext_user_python")
    parser.add_argument("--python-version", default=PYTHON_VERSION,
                        help=f"Python version (default: {PYTHON_VERSION})")
    parser.add_argument("--skip-numpy", action="store_true",
                        help="Skip NumPy installation")
    parser.add_argument("--no-enable", action="store_true",
                        help="Don't rename .gdextension.disabled")
    parser.add_argument("--verify", action="store_true",
                        help="Check existing toolchain only, don't install")
    args = parser.parse_args()

    print("=" * 60)
    print("GONODES gn_ext_user_python — Automated Setup")
    print("=" * 60)

    if args.verify:
        return verify_toolchain()

    system = platform.system()
    ok = False

    if system == "Windows":
        log(f"Platform: Windows (embeddable package)")
        ok = setup_windows(args.python_version, args.skip_numpy)
    elif system == "Linux":
        log(f"Platform: Linux (system Python)")
        ok = setup_linux(args.python_version, args.skip_numpy)
    elif system == "Darwin":
        log(f"Platform: macOS")
        ok = setup_macos(args.python_version, args.skip_numpy)
    else:
        log(f"Unsupported platform: {system}")
        return 1

    # Ensure Godot ignores the toolchain directory
    if ok and os.path.isdir(TOOLCHAIN_PARENT):
        gdignore = os.path.join(TOOLCHAIN_PARENT, ".gdignore")
        if not os.path.isfile(gdignore):
            open(gdignore, "w").close()
            log("Created toolchain/.gdignore")

    if not args.no_enable and ok:
        print()
        log("Enabling GDExtension...")
        enable_gdextension()

    # Copy Python DLLs next to extension binary (even if already enabled)
    if ok:
        link_python_dlls()

    # Set GONODES_PYTHON_HOME for Windows embeddable
    if system == "Windows" and ok and os.path.isdir(TOOLCHAIN_DIR):
        print()
        log(f"Set environment variable for builds:")
        log(f"  $env:GONODES_PYTHON_HOME = \"{TOOLCHAIN_DIR}\"")

    print()
    if ok:
        log("Setup complete. Build the extension with:")
        log("  scons ext=gn_ext_user_python platform=<your_platform>")
    else:
        log("Setup incomplete — check output above for required steps.")

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
