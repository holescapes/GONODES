#!/usr/bin/env python3
"""
setup_python.py — Download CPython embeddable + NumPy for gn_ext_user_python.

Downloads the CPython embeddable package for the current platform, installs
pip + NumPy into it, and enables the .gdextension file.

The resulting toolchain/python/ directory is self-contained — no system
Python needed at runtime.

Usage:
  python addons/gn_ext_user_python/setup_python.py
  python addons/gn_ext_user_python/setup_python.py --python-version 3.10.11
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

PYTHON_VERSION = "3.10.11"  # Windows embeddable. DLL name is python310.dll.
# Linux and macOS ship a 3.10.x standalone build. Same ABI as 3.10.11.
PBS_TAG = "20261009"
PBS_VERSION = "3.10.22"
NUMPY_CONSTRAINT = "numpy<2"

EXT_DIR = os.path.dirname(os.path.abspath(__file__))
TOOLCHAIN_DIR = os.path.join(EXT_DIR, "toolchain", "python")
TOOLCHAIN_PARENT = os.path.join(EXT_DIR, "toolchain")
NATIVE_DIR = os.path.join(EXT_DIR, "native")
BIN_WIN64_DIR = os.path.join(EXT_DIR, "bin", "win64")


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


# ── Relocatable Linux / macOS runtime ─────────────────────────────────────────

def _host_arch():
    machine = platform.machine().lower()
    if machine in ("aarch64", "arm64"):
        return "arm64"
    return "x86_64"


def bundle_asset_name(system, arch):
    """Filename of the python-build-standalone install_only archive."""
    triples = {
        ("Linux", "x86_64"): "x86_64-unknown-linux-gnu",
        ("Linux", "arm64"): "aarch64-unknown-linux-gnu",
        ("Darwin", "x86_64"): "x86_64-apple-darwin",
        ("Darwin", "arm64"): "aarch64-apple-darwin",
    }
    triple = triples.get((system, arch))
    if not triple:
        return ""
    return (
        f"cpython-{PBS_VERSION}+{PBS_TAG}-{triple}-install_only_stripped.tar.gz"
    )


def bundle_url(system, arch):
    name = bundle_asset_name(system, arch)
    if not name:
        return ""
    from urllib.parse import quote
    return (
        "https://github.com/astral-sh/python-build-standalone/releases/download/"
        f"{PBS_TAG}/{quote(name)}"
    )


def _bundled_python_exe():
    if platform.system() == "Windows":
        return os.path.join(TOOLCHAIN_DIR, "python.exe")
    return os.path.join(TOOLCHAIN_DIR, "bin", "python3")


def _write_bundle_notice():
    notice = os.path.join(TOOLCHAIN_DIR, "GONODES_PYTHON_NOTICE.txt")
    text = (
        "This folder is an unmodified CPython build plus NumPy, shipped inside\n"
        "GONODES so Python nodes work without a separate install.\n"
        "\n"
        "CPython is under the Python Software Foundation License. Keep the\n"
        "LICENSE file in this folder with every copy.\n"
        "NumPy is BSD 3-Clause. Its license is in the numpy *.dist-info folder.\n"
        "\n"
        "GONODES does not change CPython. Do not use the Python name, or the\n"
        "Python Software Foundation name, to endorse GONODES.\n"
    )
    with open(notice, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def setup_standalone(system, arch, skip_numpy):
    """Download a relocatable CPython 3.10 prefix and install NumPy into it."""
    exe = _bundled_python_exe()
    if os.path.isfile(exe):
        log(f"Bundled Python already present at {TOOLCHAIN_DIR}")
        if not skip_numpy:
            _install_numpy_prefix(exe)
        _write_bundle_notice()
        return True

    url = bundle_url(system, arch)
    if not url:
        log(f"No redistributable CPython build for {system} {arch}.")
        return False

    archive_name = bundle_asset_name(system, arch)
    tmp_archive = os.path.join(EXT_DIR, "toolchain", archive_name)
    if not download(url, tmp_archive, f"CPython {PBS_VERSION} ({system} {arch})"):
        return False

    log(f"Extracting {archive_name}...")
    os.makedirs(TOOLCHAIN_PARENT, exist_ok=True)
    if os.path.isdir(TOOLCHAIN_DIR):
        shutil.rmtree(TOOLCHAIN_DIR)
    with tarfile.open(tmp_archive, "r:gz") as archive:
        archive.extractall(TOOLCHAIN_PARENT)
    os.remove(tmp_archive)

    if not os.path.isfile(exe):
        log(f"Python executable missing after extract: {exe}")
        return False

    if not skip_numpy and not _install_numpy_prefix(exe):
        return False
    _write_bundle_notice()
    return True


def _install_numpy_prefix(python_exe):
    result = subprocess.run(
        [python_exe, "-c",
         "import numpy; v=tuple(int(x) for x in numpy.__version__.split('.')[:2]); "
         "raise SystemExit(0 if v < (2, 0) else 1)"],
        capture_output=True, text=True,
    )
    if result.returncode == 0:
        shown = subprocess.run(
            [python_exe, "-c", "import numpy; print(numpy.__version__)"],
            capture_output=True, text=True,
        )
        log(f"NumPy already installed (compatible): {shown.stdout.strip()}")
        return True

    log(f"Installing {NUMPY_CONSTRAINT}...")
    pip = subprocess.run(
        [python_exe, "-m", "pip", "install", NUMPY_CONSTRAINT,
         "--no-warn-script-location"],
        capture_output=True, text=True,
    )
    if pip.returncode != 0:
        boot = subprocess.run(
            [python_exe, "-m", "ensurepip", "--upgrade"],
            capture_output=True, text=True,
        )
        if boot.returncode != 0:
            log(f"NumPy install failed: {pip.stderr}")
            return False
        pip = subprocess.run(
            [python_exe, "-m", "pip", "install", NUMPY_CONSTRAINT,
             "--no-warn-script-location"],
            capture_output=True, text=True,
        )
        if pip.returncode != 0:
            log(f"NumPy install failed: {pip.stderr}")
            return False
    shown = subprocess.run(
        [python_exe, "-c", "import numpy; print(numpy.__version__)"],
        capture_output=True, text=True,
    )
    if shown.returncode == 0:
        log(f"NumPy installed: {shown.stdout.strip()}")
    return shown.returncode == 0


# ── Ship the runtime beside an export, or pack it for CI ─────────────────────

_RUNTIME_LIB_NAMES = {
    "python3.dll",
    "python310.dll",
    "vcruntime140.dll",
    "vcruntime140_1.dll",
    "libffi-8.dll",
    "libpython3.10.so.1.0",
    "libpython3.10.dylib",
}


def _runtime_lib_dirs():
    return [
        os.path.join(EXT_DIR, "bin", "win64"),
        os.path.join(EXT_DIR, "bin", "linux64"),
        os.path.join(EXT_DIR, "bin", "macos"),
        os.path.join(EXT_DIR, "native", "bin", "linux64"),
        os.path.join(EXT_DIR, "native", "bin", "macos"),
    ]


def _copy_runtime_lib(src, dest_dir):
    os.makedirs(dest_dir, exist_ok=True)
    dest = os.path.join(dest_dir, os.path.basename(src))
    shutil.copy2(src, dest)
    if platform.system() == "Darwin" and dest.endswith(".dylib"):
        subprocess.run(
            ["install_name_tool", "-id", "@rpath/libpython3.10.dylib", dest],
            capture_output=True,
        )
    log(f"Copied {os.path.basename(src)} -> {dest_dir}")


def export_runtime(dest_dir):
    """Copy the bundled tree into dest_dir for a CI artifact."""
    if not os.path.isdir(TOOLCHAIN_DIR):
        log(f"Nothing to export. {TOOLCHAIN_DIR} is missing.")
        return False
    python_dest = os.path.join(dest_dir, "toolchain", "python")
    if os.path.isdir(python_dest):
        shutil.rmtree(python_dest)
    shutil.copytree(TOOLCHAIN_DIR, python_dest)
    for folder in _runtime_lib_dirs():
        if not os.path.isdir(folder):
            continue
        rel = os.path.relpath(folder, EXT_DIR)
        out_dir = os.path.join(dest_dir, rel)
        for name in os.listdir(folder):
            if name not in _RUNTIME_LIB_NAMES:
                continue
            os.makedirs(out_dir, exist_ok=True)
            shutil.copy2(os.path.join(folder, name), os.path.join(out_dir, name))
    log(f"Exported Python runtime to {dest_dir}")
    return True


def _find_python_tree(src_dir):
    direct = os.path.join(src_dir, "toolchain", "python")
    if os.path.isdir(direct):
        return direct
    for root, _dirs, _files in os.walk(src_dir):
        if os.path.basename(root) != "python":
            continue
        if (os.path.isfile(os.path.join(root, "python.exe"))
                or os.path.isfile(os.path.join(root, "bin", "python3"))):
            return root
    return ""


def import_runtime(src_dir):
    """Copy a CI artifact back into this extension."""
    python_src = _find_python_tree(src_dir)
    if not python_src:
        log(f"No toolchain/python in {src_dir}")
        return False
    if os.path.isdir(TOOLCHAIN_DIR):
        shutil.rmtree(TOOLCHAIN_DIR)
    shutil.copytree(python_src, TOOLCHAIN_DIR)
    for dirpath, _dirnames, filenames in os.walk(src_dir):
        for name in filenames:
            if name not in _RUNTIME_LIB_NAMES:
                continue
            rel_dir = os.path.relpath(dirpath, src_dir)
            if rel_dir == "." or rel_dir.startswith("toolchain"):
                continue
            _copy_runtime_lib(
                os.path.join(dirpath, name),
                os.path.join(EXT_DIR, rel_dir),
            )
    log(f"Imported Python runtime from {src_dir}")
    return True


def _ignore_stage(directory, names):
    skip = {"include", "libs", "__pycache__", "test", "tests"}
    return [name for name in names if name in skip or name.endswith(".pdb")]


def stage_runtime(export_path):
    """Place the runtime at <exe_dir>/python so an exported player can see it."""
    if not os.path.isdir(TOOLCHAIN_DIR):
        log("No bundled Python to stage. Run with --bundle first.")
        return False
    path = os.path.abspath(export_path)
    if path.lower().endswith(".zip") and os.path.isfile(path):
        return _stage_into_zip(path)
    dest = _stage_destination(path)
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    shutil.copytree(TOOLCHAIN_DIR, dest, ignore=_ignore_stage)
    log(f"Staged Python runtime at {dest}")
    return True


def _stage_destination(path):
    if path.endswith(".app") and os.path.isdir(path):
        return os.path.join(path, "Contents", "MacOS", "python")
    if os.path.isdir(path):
        apps = [name for name in os.listdir(path) if name.endswith(".app")]
        if len(apps) == 1:
            return os.path.join(path, apps[0], "Contents", "MacOS", "python")
        return os.path.join(path, "python")
    return os.path.join(os.path.dirname(path), "python")


def _stage_into_zip(zip_path):
    import tempfile
    tmp = tempfile.mkdtemp(prefix="gonodes-python-stage-")
    try:
        with zipfile.ZipFile(zip_path) as archive:
            archive.extractall(tmp)
        dest = _stage_destination(tmp)
        # A zip of one .app extracts to tmp/<Name>.app
        apps = []
        for root, dirs, _files in os.walk(tmp):
            for name in dirs:
                if name.endswith(".app"):
                    apps.append(os.path.join(root, name))
        if len(apps) == 1:
            dest = os.path.join(apps[0], "Contents", "MacOS", "python")
        if os.path.isdir(dest):
            shutil.rmtree(dest)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copytree(TOOLCHAIN_DIR, dest, ignore=_ignore_stage)
        tmp_zip = zip_path + ".staging"
        with zipfile.ZipFile(tmp_zip, "w", compression=zipfile.ZIP_DEFLATED) as out:
            for folder, _dirs, files in os.walk(tmp):
                for name in files:
                    full = os.path.join(folder, name)
                    out.write(full, os.path.relpath(full, tmp))
        os.replace(tmp_zip, zip_path)
        log(f"Staged Python runtime inside {zip_path}")
        return True
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


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
    """Copy libpython next to the extension binary.

    Godot loads the GDExtension before any script runs. The loader finds
    libpython beside that binary ($ORIGIN / the Windows DLL directory), and
    Python home points at the full prefix for the standard library.
    """
    system = platform.system()
    if system == "Windows":
        dll_names = ["python3.dll", "python310.dll", "vcruntime140.dll",
                     "vcruntime140_1.dll", "libffi-8.dll"]
        if not any(os.path.isfile(os.path.join(TOOLCHAIN_DIR, n)) for n in dll_names):
            return
        os.makedirs(BIN_WIN64_DIR, exist_ok=True)
        for dll_name in dll_names:
            src = os.path.join(TOOLCHAIN_DIR, dll_name)
            if not os.path.isfile(src):
                continue
            dst = os.path.join(BIN_WIN64_DIR, dll_name)
            if (not os.path.isfile(dst)
                    or os.path.getmtime(src) > os.path.getmtime(dst)):
                shutil.copy2(src, dst)
                log(f"Copied {dll_name} -> bin/win64/")
        return

    if system == "Linux":
        src = os.path.join(TOOLCHAIN_DIR, "lib", "libpython3.10.so.1.0")
        dests = [
            os.path.join(EXT_DIR, "bin", "linux64"),
            os.path.join(EXT_DIR, "native", "bin", "linux64"),
        ]
    elif system == "Darwin":
        src = os.path.join(TOOLCHAIN_DIR, "lib", "libpython3.10.dylib")
        dests = [
            os.path.join(EXT_DIR, "bin", "macos"),
            os.path.join(EXT_DIR, "native", "bin", "macos"),
        ]
    else:
        return
    if not os.path.isfile(src):
        return
    for dest in dests:
        _copy_runtime_lib(src, dest)


# ── Verify ────────────────────────────────────────────────────────────────────

def verify_toolchain() -> int:
    """Check that the bundled Python toolchain is present and functional."""
    ok = True

    if not os.path.isdir(TOOLCHAIN_DIR):
        log(f"[X] toolchain/python/ — MISSING")
        log(f"    Run without --verify to download.")
        return 1

    python_exe = _bundled_python_exe()

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
        for dll_name in ["python3.dll", "python310.dll"]:
            dll_path = os.path.join(BIN_WIN64_DIR, dll_name)
            if os.path.isfile(dll_path):
                size_mb = os.path.getsize(dll_path) / (1024 * 1024)
                log(f"[+] bin/win64/{dll_name} ({size_mb:.1f} MB)")
            else:
                log(f"[X] bin/win64/{dll_name} — MISSING (Godot can't load the extension)")
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
    parser.add_argument("--bundle", action="store_true",
                        help="Download a redistributable CPython + NumPy for this OS")
    parser.add_argument("--print-bundle-url", action="store_true",
                        help="Print the standalone archive URL and exit")
    parser.add_argument("--export-runtime", metavar="DIR",
                        help="Copy the bundled runtime into DIR for a CI artifact")
    parser.add_argument("--import-runtime", metavar="DIR",
                        help="Copy a CI runtime artifact back into this extension")
    parser.add_argument("--stage", metavar="EXPORT",
                        help="Copy the runtime next to an exported player or into a .app/.zip")
    args = parser.parse_args()

    print("=" * 60)
    print("GONODES gn_ext_user_python — Automated Setup")
    print("=" * 60)

    if args.print_bundle_url:
        url = bundle_url(platform.system(), _host_arch())
        if not url:
            log("This OS uses the Windows embeddable package, or has no bundle.")
            return 0 if platform.system() == "Windows" else 1
        print(url)
        return 0

    if args.verify:
        return verify_toolchain()

    if args.export_runtime:
        return 0 if export_runtime(args.export_runtime) else 1
    if args.import_runtime:
        return 0 if import_runtime(args.import_runtime) else 1
    if args.stage:
        return 0 if stage_runtime(args.stage) else 1

    system = platform.system()
    ok = False

    if args.bundle and system in ("Linux", "Darwin"):
        log(f"Platform: {system} (redistributable CPython {PBS_VERSION})")
        ok = setup_standalone(system, _host_arch(), args.skip_numpy)
    elif system == "Windows":
        log("Platform: Windows (embeddable package)")
        ok = setup_windows(args.python_version, args.skip_numpy)
    elif system == "Linux":
        log("Platform: Linux (system Python)")
        ok = setup_linux(args.python_version, args.skip_numpy)
    elif system == "Darwin":
        log("Platform: macOS")
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

    # Copy libpython next to the extension binary.
    if ok:
        link_python_dlls()
        if os.path.isfile(_bundled_python_exe()):
            _write_bundle_notice()

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
