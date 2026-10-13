# GONODES

Real-time node-based visual programming, built on [Godot 4.7](https://godotengine.org). Inspired by [TouchDesigner](https://derivative.ca) and [Houdini](https://www.sidefx.com).

Wire operators together, change them while they run, and see the result immediately. Then ship the patch as a standalone app.

> **Image slot `hero`** — wide shot of the editor with a patch on screen.
> Save the file as `docs/images/hero.png`, then replace this note with `![Hero](docs/images/hero.png)`.

## What it is

GONODES is for people who already think in nodes: TouchDesigner, Houdini, Max, vvvv, Vuo. Data moves along wires. The picture updates while you edit.

- Ship the patch as a standalone app on Windows, macOS, Linux, Android, iOS, and the web. No runtime license.
- Rendering is Godot's: Vulkan, Metal, D3D12, and OpenGL.
- A patch can also run inside another program through LibGodot.
- The source is open. MIT license.

> **Image slot `patch`** — a few operators wired together, parameters visible.
> Save as `docs/images/patch.png`.

Godot already renders, exports, and runs scripts. GONODES adds the operator graph, the cook, and the parameters. When Godot gains a renderer or a platform, this project follows.

## On the Shoulders of Giants

GONODES does not replace Godot. It completes it for a different audience. Every capability we needed, we asked whether Godot already did it. Almost always, yes.

**Rendering.** Godot's `RenderingDevice` and `RenderingServer` handle every pixel. TOP textures are Godot `RID` handles. The 3D pipeline runs in a live `SubViewport`. GPU particles use Godot's compute pipeline. When Godot ships a new rendering feature, GONODES gets it for free.

**Editor.** The node graph is a Godot `GraphEdit`. The inspector is a `Control` tree. Theming, input handling, font rendering, and accessibility are inherited.

**Export.** Godot's export system is untouched. A GONODES patch becomes a standalone app through the same templates any Godot game uses. LibGodot means a patch can be embedded in a VJ host, an installation controller, or a broadcast graphics engine.

**Scripting.** Expressions compile and run on Godot's GDScript VM. That virtual machine is production-grade, sandboxed, and hot-reloadable.

**Native code.** GDExtension gives access to FFmpeg, RtMidi, Spout, and custom C++ operators through Godot's stable ABI.

Godot's roadmap is our roadmap. Renderer improvements, WebAssembly, and XR integration become available to GONODES when Godot ships them. We focus on the operator model, the cook engine, and the parameter system, and borrow everything else from one of the most active open-source engines in the world.

Building on Godot is not a constraint. It is the point.

## What you can wire

| Family | What moves on the wire |
|--------|------------------------|
| TOP | GPU textures |
| IMG | CPU images |
| CHOP | Channels, signals, and audio |
| DAT | Tables and text |
| SOP | 3D surfaces |
| MAT | Materials |
| COMP | 3D scenes |
| POP | GPU particles |
| VOL | Volumes |
| UI | On-screen controls |
| SDF | Signed distance fields |
| FIX | LED fixtures |
| OUT | Windows, files, and devices |
| SCRIPT | GDScript, Python, and C++ |
| NET | Subnetworks and the host bridge |

A GPU texture becomes a CPU image only through `TOPtoIMG` and `ImgToTOP`. Counts live in [docs/OPERATORS.md](docs/OPERATORS.md).

Any parameter can be a live expression. Rename a node and every expression that names it updates.

```gdscript
chop("lfo1", "out") * 10.0
```

- Drop a wire on empty canvas and the palette offers only operators that fit.
- Ctrl+G groups a selection into a subnetwork. Enter dives in. Backspace comes back out.
- Spare parameters and saved presets stay with the patch. A subnetwork can be saved as a `.gnasset` and appear in the palette.
- Build writes a standalone app. Each WindowOUT can open its own display.
- Every operator has a **?** button. It opens that node's docs, and an example patch opens beside your work.

Extensions add MIDI, Spout, Syphon, NDI, OpenCV, and FFmpeg, along with video capture, machine learning, depth sensors, and projection mapping. What each one needs is in [Extensions](addons/gonodes/help/extensions.md).

## Developed with agentic coding

GONODES was developed with the help of agentic coding.

Agentic coding is a sound way to build a tool and to tune an idea. It is a poor substitute for the creative work itself. GONODES is a tool for that work, so building it with agents is a fair use of them. An agent can also draft a patch. The patch is still only the means. What the work is for stays with the person.

This project is not slop. From the first design to this beta took about a year. A human designed it, architected it, and reconsidered it at every step, for other humans.

Point an agent at [`ai/README.md`](ai/README.md) and it can learn the project. That folder is the shared brief for any model, whether it is helping change GONODES or helping write a patch. The patch brief itself is [`llms.txt`](llms.txt).

## Start

**Use a release.** Download the editor for your system from the [GitHub releases](https://github.com/holescapes/GONODES/releases). Godot is already inside it. You do not install Godot to author a patch or to run a show. The first time you build a player for another platform, the editor downloads that player. Android and iOS are a manual build. Details are in [Building](addons/gonodes/help/building.md).

> **Image slot `player`** — the standalone player on a display, no editor chrome.
> Save as `docs/images/player.png`.

**Or work from the source.**

```bash
git clone https://github.com/holescapes/GONODES.git
cd GONODES
```

Open the folder in [Godot 4.7.2](https://godotengine.org/download) and run `scenes/gn_editor.tscn`. The core operators are GDScript and run without a C++ build. Native extensions (MIDI, video, OpenCV, and the rest) are compiled from [the build guide](dev_docs/BUILD.md). The shorter steps are in [Building](addons/gonodes/help/building.md).

The first patch, the editor, expressions, and export are in the in-editor help, starting at [Getting Started](addons/gonodes/help/getting_started.md).

## Where to read next

| You want | Read |
|----------|------|
| Use the editor | [Getting Started](addons/gonodes/help/getting_started.md), [Editor](addons/gonodes/help/editor.md) |
| Expressions, scripts, subnetworks | [Expressions](addons/gonodes/help/expressions.md), [Scripting](addons/gonodes/help/scripting.md), [Sub-networks](addons/gonodes/help/sub_networks.md) |
| Run a finished patch | [Player](addons/gonodes/help/player.md) |
| Build or export | [Building](addons/gonodes/help/building.md). Internals: [dev_docs/BUILD.md](dev_docs/BUILD.md) |
| Extensions and custom operators | [Extensions](addons/gonodes/help/extensions.md), [Custom assets](addons/gonodes/help/custom_assets.md) |
| Embed GONODES in another app | [libgonodes/README.md](libgonodes/README.md), [Integration](dev_docs/INTEGRATION.md) |
| Operator reference | The **?** button on a node. Snapshot: [docs/OPERATORS.md](docs/OPERATORS.md) |
| Change the engine | [Contributing](dev_docs/CONTRIBUTING.md), [dev docs](dev_docs/README.md), [architecture](GONODES_CONTEXT.md) |
| Roadmap | [dev_docs/ROADMAP.md](dev_docs/ROADMAP.md) |
| Brief a language model | [ai/README.md](ai/README.md). Patches: [llms.txt](llms.txt) |

> **Image slot `display`** — the same patch on a projector or an LED wall.
> Save as `docs/images/display.png`.

The slot names and file paths are listed again in [docs/images/README.md](docs/images/README.md).

Two limits, so they are not a surprise. Shadertoy import is single-pass, the Image tab only. Multi-pass buffer tabs are not converted. GLSL multi-render-target mode does not carry `SCREEN_TEXTURE` or custom varyings. Split those shaders by hand.

## Contributing

Read [GONODES_CONTEXT.md](GONODES_CONTEXT.md) for the architecture and [dev_docs/CONTRIBUTING.md](dev_docs/CONTRIBUTING.md) for the rules, then open an issue.

## License

MIT. See [LICENSE](LICENSE). Personal work, paid work, installations, and embedded apps are allowed. No royalties.

Godot and godot-cpp are MIT. FFmpeg, used by the video extension, is LGPL 2.1 or later and is linked dynamically. Other extensions keep their own licenses in `addons/gn_ext_*/`.

## Acknowledgments

- [Houdini](https://www.sidefx.com) — procedural nodes, digital assets, and a cook that only runs what changed.
- [TouchDesigner](https://derivative.ca) — real-time operator families, wires, and live parameters.
- [Godot](https://godotengine.org) — the engine underneath.
- [Vuo](https://vuo.org), [Max](https://cycling74.com), and [vvvv](https://vvvv.org) — node-based work for live media.
