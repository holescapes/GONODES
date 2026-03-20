"""
python_config.py — Discover CPython include/lib paths for the build system.

Called by SConstruct to resolve Python development paths at build time.
Outputs JSON with: include_dir, lib_dir, lib_name, version, numpy_include.

Usage:
  python python_config.py               # Auto-detect from current interpreter
  python python_config.py --json        # Output as JSON
  PYTHON_HOME=<dir> python python_config.py   # Use specific Python install
"""

import json
import os
import sys
import sysconfig


def discover():
    info = {}

    # Python paths
    info["version"] = f"{sys.version_info.major}.{sys.version_info.minor}"
    info["version_full"] = sys.version.split()[0]
    info["include_dir"] = sysconfig.get_path("include")
    info["stdlib_dir"] = sysconfig.get_path("stdlib")

    # Library directory
    if sys.platform == "win32":
        # Windows: python3xx.lib lives next to python.exe
        base = os.path.dirname(sys.executable)
        info["lib_dir"] = os.path.join(base, "libs")
        info["lib_name"] = f"python{sys.version_info.major}{sys.version_info.minor}"
    elif sys.platform == "darwin":
        # macOS: Python.framework or Homebrew
        info["lib_dir"] = sysconfig.get_config_var("LIBDIR") or ""
        info["lib_name"] = sysconfig.get_config_var("LDLIBRARY") or ""
    else:
        # Linux: libpython3.x.so
        info["lib_dir"] = sysconfig.get_config_var("LIBDIR") or ""
        info["lib_name"] = sysconfig.get_config_var("LDLIBRARY") or ""

    # numpy include directory
    try:
        import numpy
        info["numpy_include"] = numpy.get_include()
        info["numpy_version"] = numpy.__version__
    except ImportError:
        info["numpy_include"] = ""
        info["numpy_version"] = ""

    return info


def main():
    info = discover()

    if "--json" in sys.argv:
        print(json.dumps(info, indent=2))
    else:
        for k, v in info.items():
            print(f"{k}={v}")


if __name__ == "__main__":
    main()
