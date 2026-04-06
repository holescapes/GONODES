# gn_ext_webrender — Web Render TOP (CEF)

Render web pages (HTML / CSS / JavaScript / WebGL) to a texture using the
**Chromium Embedded Framework** via the
[gdCEF](https://github.com/Lecrapouille/gdcef) GDExtension.

This is the GONODES equivalent of TouchDesigner's **Web Render TOP**.

## Operators

| Operator | Family | Description |
|----------|--------|-------------|
| WebRenderTOP | TOP | Render a web page (URL or inline HTML) to a texture |

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| Mode | Enum | URL | `URL` — load from the web; `HTML` — render inline content |
| URL | String | `https://godotengine.org` | Web page address (URL mode) |
| HTML | String | *(sample)* | Inline HTML/CSS/JS content (HTML mode) |
| Resolution | Vector2i | 1280 × 720 | Browser viewport size in pixels |
| FPS | Int | 30 | CEF render frame rate (1–120) |
| JavaScript | String | *(empty)* | JS snippet executed every cook (optional) |
| Active | Bool | true | Enable / disable rendering |

## Setup

### Option A — Automatic (recommended)

The top-level `setup_deps.py` automatically downloads prebuilt gdCEF
binaries when run without `--core`:

```bash
python setup_deps.py          # fetches all deps including gdCEF (~550 MB)
```

Or run the extension's setup script directly:

```bash
cd addons/gn_ext_webrender
python setup_cef.py            # download + extract
python setup_cef.py --force    # re-download even if present
python setup_cef.py --clean    # remove cef_artifacts/
```

The version is controlled by `GDCEF_VERSION` and `GDCEF_GODOT` in
`versions.env` at the project root.

### Option B — Manual Download

1. Download the latest **cef_artifacts** package from
   [gdCEF Releases](https://github.com/Lecrapouille/gdcef/releases).
2. Extract the `cef_artifacts/` folder into the extension directory:
   `addons/gn_ext_webrender/cef_artifacts/`
3. Done — the `.gdextension` file inside it points to the correct paths.

### Option C — Build from Source

A clone of the gdCEF repository is included under
`addons/gn_ext_webrender/native/gdcef/` for convenience.

```bash
cd addons/gn_ext_webrender/native/gdcef
pip install -r requirements.txt
python build.py
```

Then copy (or symlink) the generated `cef_artifacts/` folder to
`addons/gn_ext_webrender/cef_artifacts/`.

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Windows x86_64 | ✅ Supported | Prebuilt binaries via `setup_cef.py` |
| Linux x86_64   | ✅ Supported | Prebuilt binaries via `setup_cef.py` |
| macOS           | ❌ Not available | gdCEF doesn't ship macOS builds yet (needs upstream contributor) |
| Android / iOS   | ❌ Not possible | CEF is desktop-only — Chromium has no offscreen mobile build |

**Why no mobile?** WebRenderTOP needs **offscreen rendering** (web content → GPU
texture). CEF provides this on desktop via Chromium's headless mode. Mobile
platforms (Android WebView, iOS WKWebView) only support overlay-style rendering
— they draw on top of the app window, not into a texture. Bitmap capture hacks
exist but deliver ~5 FPS, far below what a TOP needs.

On unsupported platforms, the extension simply doesn't load —
`gn_extension.cfg` declares `platforms=["windows", "linux"]` and the
dependency guard (`GDCEF`, `GdBrowserView`) prevents registration when
the classes aren't available. No errors, no warnings — the operator
just won't appear in the palette.

## Licensing

- **This extension** (gn_ext_webrender) is part of GONODES and follows the
  project license.
- **gdCEF** is licensed under the **MIT License**.
  See [gdCEF LICENSE](https://github.com/Lecrapouille/gdcef/blob/godot-4.x/LICENSE).
- **Chromium Embedded Framework (CEF)** uses the BSD license.
  CEF bundles third-party libraries under various permissive and LGPL licenses.
  See the [gdCEF FAQ on licensing](https://github.com/Lecrapouille/gdcef/blob/godot-4.x/doc/faq.md#licensing)
  for full details.
- **Important**: If you distribute a product using CEF, you must comply with the
  LGPL requirements for the bundled third-party libraries (primarily dynamic
  linking — which CEF already does). In practice this means including the
  relevant license notices and not statically linking LGPL code.

## Troubleshooting

- **"gdCEF not available"** — The `addons/gn_ext_webrender/cef_artifacts/` folder
  is missing or the `.gdextension` file inside it doesn't match your platform.
- **CEF initialization fails** — Delete `addons/gn_ext_webrender/cef_artifacts/cache/`
  and restart.
- **Blank output** — The first frame may be blank while the page loads; the
  texture updates asynchronously via the `on_browser_paint` signal.
- **High memory usage** — Chromium is memory-hungry (~200+ MB per browser
  instance). Use the `active` toggle to disable when not needed.
