# Python Toolchain

This directory holds the bundled Python embeddable package used by
`gn_ext_user_python`. It is **optional** — if absent, the extension
falls back to system Python or the `GONODES_PYTHON_HOME` environment variable.

## Setup

### Windows

Download the **Python embeddable package** (not the installer) from
https://www.python.org/downloads/ :

```
python-3.12.x-embed-amd64.zip
```

Extract into this directory so the layout is:

```
toolchain/python/
  python3.dll
  python312.dll
  python312.zip
  python.exe   (optional)
  ...
```

Then install NumPy into the embeddable:

```powershell
# Uncomment "import site" in python312._pth
.\python\python.exe -m ensurepip
.\python\python.exe -m pip install numpy
```

### Linux

Symlink or copy the Python shared library and stdlib:

```bash
ln -s /usr/lib/python3.12 toolchain/python/lib
ln -s /usr/lib/x86_64-linux-gnu/libpython3.12.so toolchain/python/
```

### macOS

Use the Python.framework or Homebrew installation:

```bash
ln -s /opt/homebrew/Frameworks/Python.framework/Versions/3.12 toolchain/python
```

## Version Requirements

- **Minimum**: Python 3.10
- **Recommended**: Python 3.12+
- **NumPy**: 1.24+ (for the C API compatibility)

## Size Budget

| Component | Size |
|-----------|------|
| Python embeddable (Windows) | ~15 MB |
| NumPy | ~30 MB |
| Total | ~45 MB |

For release builds, consider using `numpy` only (no scipy/pandas) to
keep the bundle size reasonable.

## Environment Variable

Instead of bundling, users can set:

```
GONODES_PYTHON_HOME=C:\Python312
```

The extension checks this before falling back to system PATH.
