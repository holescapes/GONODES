# gn_ext_ndi — NDI Video/Audio Over IP

Send and receive live video **and audio** over the network using [NDI®](https://ndi.video/) (Network Device Interface) from Vizrt.

## Operators

| Operator | Family | Description |
|---|---|---|
| **NDIInTOP** | TOP | Receive NDI video as a texture |
| **NDIOutTOP** | TOP | Send a texture as NDI video |
| **NDIAudioInCHOP** | CHOP | Receive NDI audio as channel data |
| **NDIAudioOutCHOP** | CHOP | Send channel data as NDI audio |

## NDI SDK Setup

The NDI SDK is **proprietary** (free to download, but not open-source) and
**cannot** be bundled in this repository.  You must download it yourself.

### 1  Download the SDK

Go to **<https://ndi.video/download-ndi-sdk/>** and download the
**NDI SDK** for your platform.  You may need to create a free account.

### 2  Copy SDK Files

After installing or extracting the SDK, copy the required files into:

```
addons/gn_ext_ndi/native/ndi_sdk/
├── Include/
│   └── Processing.NDI.Lib.h
├── Lib/
│   └── x64/
│       └── Processing.NDI.Lib.x64.lib    (Windows)
└── lib/
    ├── x86_64-linux/
    │   └── libndi.so                     (Linux)
    └── libndi.dylib                      (macOS)
```

**Windows** — The SDK installer typically places files in
`C:\Program Files\NDI\NDI 6 SDK\`.  Copy:
- `Include\Processing.NDI.Lib.h` → `ndi_sdk/Include/`
- `Lib\x64\Processing.NDI.Lib.x64.lib` → `ndi_sdk/Lib/x64/`

**Linux** — After running the SDK installer:
- `include/Processing.NDI.Lib.h` → `ndi_sdk/Include/`
- `lib/x86_64-linux-gnu/libndi.so` → `ndi_sdk/lib/x86_64-linux/`

**macOS** — After running the SDK installer:
- `include/Processing.NDI.Lib.h` → `ndi_sdk/Include/`
- `lib/macOS/libndi.dylib` → `ndi_sdk/lib/libndi.dylib`

### 3  Build the Extension

From the `addons/gn_ext_ndi/native/` directory:

```bash
# Windows
scons platform=windows

# Linux
scons platform=linux

# macOS
scons platform=macos
```

This uses the shared GONODES build system (`build/gn_build.py`).  Make
sure godot-cpp is already built (see `dev_docs/BUILD.md`).

### 4  Runtime DLLs

At **runtime** the NDI shared library must be loadable:

| Platform | Library | Typical location |
|---|---|---|
| Windows | `Processing.NDI.Lib.x64.dll` | Same dir as your Godot executable, or in PATH |
| Linux | `libndi.so.6` | `/usr/lib/` or `LD_LIBRARY_PATH` |
| macOS | `libndi.dylib` | `/usr/local/lib/` or `DYLD_LIBRARY_PATH` |

On Windows you can also install the **NDI Runtime** (separate from the SDK) —
it adds the DLL to the system PATH automatically.

## Audio Support

NDI carries audio alongside video on the same stream.  This extension
provides dedicated audio operators so you can route video and audio
independently through your node graph:

- **NDIAudioInCHOP** — receives audio from an NDI source.  Each audio
  channel becomes a CHOP channel (`ch0`, `ch1`, …).  Default bandwidth
  mode is "Audio Only" for efficiency when you only need sound.

- **NDIAudioOutCHOP** — sends CHOP channel data as NDI audio.  Each
  CHOP channel maps to an NDI audio channel in order.

Both audio operators support multi-channel (stereo, 5.1, 7.1, etc.)
and configurable sample rates up to 192 kHz.

## Typical Workflows

**Receive video from OBS:**
```
NDIInTOP → [any TOP chain] → WindowOUT
```

**Send GoNodes output to a hardware switcher:**
```
[any TOP chain] → NDIOutTOP
```

**Audio reactive visuals via NDI:**
```
NDIAudioInCHOP → AudioBandCHOP → CHOPtoTOP → [shader chain]
```

**Complete A/V send:**
```
[video chain] → NDIOutTOP
[audio chain] → NDIAudioOutCHOP
```

---

NDI® is a registered trademark of Vizrt NDI AB.
