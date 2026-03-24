#!/usr/bin/env python3
"""Generate human-assisted manual test .gnpatch files for GPU/visual families.

One patch per operator so failures can be isolated to a single node.
Each patch has a sticky note explaining what the human tester should verify.
Patches are written to tests/manual/<family>/.
"""

import json
import os
import shutil

PATCH_DIR = os.path.join(os.path.dirname(__file__), "..", "tests", "manual")


def ann(text, x=-120.0, y=-140.0, w=480.0, h=130.0):
    return {
        "id": "ann_1", "type": "note",
        "text": text,
        "position": [x, y], "size": [w, h],
        "color": [1.0, 1.0, 0.6, 0.9],
    }


def node(class_name, nid, x=0.0, y=0.0, params=None):
    d = {"class_name": class_name, "position": [x, y], "parameters": params or {}}
    return nid, d


def conn(from_id, fp, to_id, tp):
    return {"from": from_id, "from_port": fp, "to": to_id, "to_port": tp}


def patch(nodes, connections, annotation_text):
    nd = {nid: d for nid, d in nodes}
    return {
        "version": "1.0.0",
        "generator": "GONODES_manual_test",
        "nodes": nd,
        "connections": connections,
        "annotations": [ann(annotation_text)] if annotation_text else [],
    }


def write(family, name, data):
    d = os.path.join(PATCH_DIR, family)
    os.makedirs(d, exist_ok=True)
    fp = os.path.join(d, name + ".gnpatch")
    with open(fp, "w", encoding="utf-8", newline="") as f:
        json.dump(data, f, indent=4)
    return fp


# ═══════════════════════════════════════════════════════════════════════════════
# Operator registry — one entry per operator, one patch per entry
# ═══════════════════════════════════════════════════════════════════════════════
#
# Each entry: (class_name, upstream_class_or_None, verify_text)
# upstream_class is a minimal source node so the operator has input to process.
# If None, the operator is a generator or doesn't need input.

# --- Upstream source helpers ---
NOISE_TOP = "NoiseTOP"
CONST_TOP = "ConstantTOP"
RENDER_TOP = "RenderTOP"
NOISE_IMG = "NoiseIMG"
SOURCE_POP = "SourcePOP"
NOISE_VOL = "NoiseVOL"
BOX_SOP = "BoxSOP"


TOP_OPS = [
    ("AnalyzeTOP",          NOISE_TOP,  "Verify: outputs analysis data (min/max/average) of input texture"),
    ("AntiAliasTOP",        NOISE_TOP,  "Verify: edges appear smoother than the raw NoiseTOP input"),
    ("BlurTOP",             NOISE_TOP,  "Verify: output is visibly blurred compared to the noise input"),
    ("CacheTOP",            NOISE_TOP,  "Verify: output matches input; tweak delay param and confirm caching"),
    ("ChannelMixTOP",       NOISE_TOP,  "Verify: color channels are remapped (e.g., R↔B swap visible)"),
    ("CHOPtoTOP",           None,       "Verify: converts CHOP channel data into a texture visualization"),
    ("ChromaKeyTOP",        CONST_TOP,  "Verify: keyed color becomes transparent; set key_color to match ConstantTOP"),
    ("CircleTOP",           None,       "Verify: renders a circle/ellipse shape on a transparent or solid background"),
    ("ColorMapTOP",         NOISE_TOP,  "Verify: applies a color LUT/gradient map to the noise input"),
    ("CompositeTOP",        NOISE_TOP,  "Verify: composites two inputs (connect a second source manually to input 1)"),
    ("CompositorEffectTOP", None,       "Verify: applies a compositor effect to the rendered scene"),
    ("ComputeShaderTOP",    None,       "Verify: compute shader runs and outputs a texture (check for errors)"),
    ("ConstantTOP",         None,       "Verify: outputs a solid color texture; change color_r/g/b params"),
    ("ConvolutionTOP",      NOISE_TOP,  "Verify: applies a convolution kernel (sharpen, edge, blur) to input"),
    ("CornerPinTOP",        NOISE_TOP,  "Verify: texture is perspective-warped by the four corner positions"),
    ("CropTOP",             NOISE_TOP,  "Verify: output is a cropped region of the input (smaller than input)"),
    ("CrossTOP",            NOISE_TOP,  "Verify: crossfades between two inputs (connect second source to input 1)"),
    ("CustomShaderTOP",     None,       "Verify: custom GLSL shader compiles and renders output; check error log"),
    ("DeformTOP",           NOISE_TOP,  "Verify: input texture is deformed/warped based on deformation map"),
    ("DepthTOP",            RENDER_TOP, "Verify: outputs a depth buffer visualization (grayscale near→far)"),
    ("DilateErodeTOP",      NOISE_TOP,  "Verify: bright regions expand (dilate) or shrink (erode) vs input"),
    ("DisplaceTOP",         NOISE_TOP,  "Verify: pixels are displaced based on a displacement map"),
    ("EdgeTOP",             NOISE_TOP,  "Verify: outputs only the detected edges from the noise input"),
    ("EmbossTOP",           NOISE_TOP,  "Verify: output shows an embossed/raised appearance of the input"),
    ("FeedbackTOP",         NOISE_TOP,  "Verify: output shows previous frame (trailing/smearing effect over time)"),
    ("FitTOP",              NOISE_TOP,  "Verify: output is resized/fitted to the target resolution"),
    ("FlipTOP",             NOISE_TOP,  "Verify: output is flipped horizontally and/or vertically vs input"),
    ("Fluid2DTOP",          None,       "Verify: 2D fluid simulation runs; inject velocity and see motion over time"),
    ("GeometryBufferTOP",   RENDER_TOP, "Verify: outputs G-buffer channels (normals, albedo, depth) as textures"),
    ("GlueTOP",             None,       "Verify: assembles multiple textures into a combined layout/atlas"),
    ("HostInTOP",           None,       "Verify: receives texture from a host application (needs host connection)"),
    ("HSVAdjustTOP",        NOISE_TOP,  "Verify: hue/saturation/value shifts are visible compared to input"),
    ("LayoutTOP",           NOISE_TOP,  "Verify: arranges multiple inputs in a grid/layout (connect more inputs)"),
    ("LensDistortTOP",      NOISE_TOP,  "Verify: barrel or pincushion distortion visible compared to input"),
    ("LevelTOP",            NOISE_TOP,  "Verify: brightness/contrast/gamma adjustments visible vs input"),
    ("LookupTOP",           NOISE_TOP,  "Verify: maps input values through a lookup table/gradient"),
    ("LumaBlurTOP",         NOISE_TOP,  "Verify: blur amount varies by luminance (bright areas more/less blurred)"),
    ("MatteTOP",            NOISE_TOP,  "Verify: extracts or applies an alpha matte from/to the input"),
    ("MonoTOP",             NOISE_TOP,  "Verify: output is grayscale/monochrome version of the color input"),
    ("MovieFileInTOP",      None,       "Verify: set a video file path; frames should play back in the output"),
    ("MultiBufferRenderTOP", None,      "Verify: renders scene into multiple render targets simultaneously"),
    ("NoiseTOP",            None,       "Verify: generates procedural noise texture; change seed/scale params"),
    ("NormalMapTOP",        NOISE_TOP,  "Verify: output is a normal map (blueish tint) derived from input heights"),
    ("NullTOP",             NOISE_TOP,  "Verify: output is identical to input (pure passthrough)"),
    ("OpticalFlowTOP",      NOISE_TOP,  "Verify: outputs motion vectors between frames (needs animated input)"),
    ("PaletteTOP",          NOISE_TOP,  "Verify: remaps input colors to a limited palette"),
    ("PanelTOP",            None,       "Verify: renders a UI panel or capture area as a texture"),
    ("PatternTOP",          None,       "Verify: generates a procedural pattern (stripes, checkers, etc.)"),
    ("PointCloudRenderTOP", None,       "Verify: renders point cloud data as a texture (needs POP/SOP input)"),
    ("PosterizeTOP",        NOISE_TOP,  "Verify: reduces color levels (visible color banding/posterization)"),
    ("PremultiplyTOP",      NOISE_TOP,  "Verify: premultiplies or un-premultiplies alpha in the texture"),
    ("ProjectionTOP",       NOISE_TOP,  "Verify: projects a texture onto geometry (needs 3D scene context)"),
    ("RadialBlurTOP",       NOISE_TOP,  "Verify: blur radiates from a center point (zoom/spin blur effect)"),
    ("RampTOP",             None,       "Verify: generates a linear or radial gradient ramp texture"),
    ("ReactionDiffusionTOP", None,      "Verify: Turing pattern evolves over time (organic spots/stripes)"),
    ("RectangleTOP",        None,       "Verify: renders a rectangular shape with configurable size/color"),
    ("RemapTOP",            NOISE_TOP,  "Verify: remaps input value range to a new range"),
    ("RenderTOP",           None,       "Verify: captures the 3D scene as a texture (may need CameraCOMP/LightCOMP)"),
    ("ReorderTOP",          NOISE_TOP,  "Verify: changes color channel order (e.g., RGBA → BGRA)"),
    ("ResolutionTOP",       NOISE_TOP,  "Verify: output resolution matches the set target (not input resolution)"),
    ("SharpenTOP",          NOISE_TOP,  "Verify: output is visibly sharper/crisper than the noise input"),
    ("SlopeTOP",            NOISE_TOP,  "Verify: outputs slope/derivative of the input (edge-like visualization)"),
    ("SnapshotTOP",         NOISE_TOP,  "Verify: captures a single frame on trigger; output freezes until next trigger"),
    ("SVGTOP",              None,       "Verify: renders an SVG vector graphic as a rasterized texture"),
    ("SwitchTOP",           NOISE_TOP,  "Verify: index param selects which input to pass through"),
    ("TextTOP",             None,       "Verify: renders text string as a texture; change text/font/size params"),
    ("ThresholdTOP",        NOISE_TOP,  "Verify: output is binary black/white at the threshold cutoff"),
    ("TileTOP",             NOISE_TOP,  "Verify: input texture is repeated/tiled across the output"),
    ("TimeMachineTOP",      NOISE_TOP,  "Verify: outputs delayed frames from a time buffer"),
    ("TransformTOP",        NOISE_TOP,  "Verify: input is translated/rotated/scaled in 2D"),
    ("TriangleTOP",         None,       "Verify: renders a triangle shape with configurable vertices/color"),
    ("VectorPathTOP",       None,       "Verify: renders vector path/curve data as a rasterized texture"),
]

COMP_OPS = [
    ("AnimationCOMP",    None, "Verify: drives keyframed animation on connected nodes; play timeline"),
    ("AreaCOMP",         None, "Verify: creates a trigger area in 3D space; objects entering emit signal"),
    ("CameraCOMP",       None, "Verify: adds a camera to the scene tree with configurable FOV/position"),
    ("EnginesCOMP",      None, "Verify: manages sub-engine instances (check scene tree for child engines)"),
    ("EnvironmentCOMP",  None, "Verify: sets scene environment (sky, fog, ambient light, tonemap)"),
    ("GenericScriptNode", None, "Verify: runs a user GDScript; check output and error log"),
    ("GeometryCOMP",     None, "Verify: creates a mesh in 3D viewport (default cube or assigned SOP)"),
    ("InstanceCOMP",     None, "Verify: creates multiple instances of a source geometry at positions"),
    ("InTunnel",         None, "Verify: receives data from an OutTunnel (sub-network input port)"),
    ("JointCOMP",        None, "Verify: creates a physics joint between two rigid bodies"),
    ("LightCOMP",        None, "Verify: adds a light to the scene (directional/point/spot); shadows work"),
    ("MergeCOMP",        None, "Verify: merges multiple component subtrees into one scene branch"),
    ("NullCOMP",         None, "Verify: passes through the component subtree unchanged"),
    ("OutTunnel",        None, "Verify: sends data to an InTunnel (sub-network output port)"),
    ("ReplicatorCOMP",   None, "Verify: replicates child components N times with offset transforms"),
    ("RigidBodyCOMP",    None, "Verify: adds physics simulation; object falls under gravity / collides"),
    ("SoftBodyCOMP",     None, "Verify: mesh deforms under physics; soft-body simulation visible"),
    ("StaticBodyCOMP",   None, "Verify: creates a static collision shape (floor/wall) for physics"),
    ("SubNetworkNode",   None, "Verify: encapsulates a sub-network; double-click to enter, inputs/outputs work"),
    ("SwitchCOMP",       None, "Verify: index param selects which child component is active"),
]

UI_OPS = [
    ("ButtonUI",             None, "Verify: renders a clickable button; click emits CHOP pulse output"),
    ("CheckBoxUI",           None, "Verify: renders a checkbox; toggle changes CHOP output 0/1"),
    ("ColorPickerUI",        None, "Verify: renders a color picker widget; selected color outputs as CHOP r/g/b"),
    ("ColorRectUI",          None, "Verify: renders a solid colored rectangle"),
    ("ContainerUI",          None, "Verify: groups child UI widgets; check layout arrangement"),
    ("DropdownUI",           None, "Verify: renders a dropdown menu; selection outputs CHOP index value"),
    ("ItemListUI",           None, "Verify: renders a scrollable list of items; selection emits output"),
    ("KnobUI",               None, "Verify: renders a rotatable knob; drag to change CHOP output value"),
    ("LabelUI",              None, "Verify: displays text label; change text param and confirm update"),
    ("LineEditUI",           None, "Verify: renders a text input field; typed text outputs as DAT"),
    ("LinkButtonUI",         None, "Verify: renders a clickable text link; click emits CHOP pulse"),
    ("MarginContainerUI",    None, "Verify: adds configurable margins around child UI elements"),
    ("MenuButtonUI",         None, "Verify: renders a button that opens a popup menu on click"),
    ("NinePatchRectUI",      None, "Verify: renders a 9-patch scalable texture (corners don't stretch)"),
    ("PanelContainerUI",     None, "Verify: renders a panel background behind child UI elements"),
    ("ProgressBarUI",        None, "Verify: renders a progress bar; connect CHOP to drive fill amount"),
    ("RichTextLabelUI",      None, "Verify: renders formatted text (BBCode bold/italic/color)"),
    ("ScrollContainerUI",    None, "Verify: provides scrollable viewport for child UI content"),
    ("SeparatorUI",          None, "Verify: renders a horizontal or vertical separator line"),
    ("SliderUI",             None, "Verify: renders a draggable slider; value outputs as CHOP"),
    ("SpinBoxUI",            None, "Verify: renders a numeric input with up/down buttons"),
    ("SplitContainerUI",     None, "Verify: splits area between two children with draggable divider"),
    ("TabBarUI",             None, "Verify: renders tab labels; clicking a tab outputs its index"),
    ("TabContainerUI",       None, "Verify: renders tabbed panels; switching tabs shows different content"),
    ("TextureButtonUI",      None, "Verify: renders a clickable button with a custom texture"),
    ("TextureProgressBarUI", None, "Verify: renders a progress bar with custom fill texture"),
    ("TextureRectUI",        None, "Verify: displays a texture image in the UI"),
    ("TextEditUI",           None, "Verify: renders a multi-line text editor; edited text outputs as DAT"),
    ("ToggleUI",             None, "Verify: renders an on/off toggle switch; state outputs as CHOP 0/1"),
    ("TreeUI",               None, "Verify: renders a hierarchical tree widget; selection emits output"),
    ("XYPadUI",              None, "Verify: renders a 2D touchpad; drag outputs X/Y as CHOP channels"),
]

POP_OPS = [
    ("AdvectPOP",       SOURCE_POP, "Verify: particles follow a velocity field (not just falling straight)"),
    ("AttractPOP",      SOURCE_POP, "Verify: particles curve toward the attractor position"),
    ("BoidsPOP",        SOURCE_POP, "Verify: particles exhibit flocking behavior (alignment, cohesion, separation)"),
    ("CollisionPOP",    SOURCE_POP, "Verify: particles bounce off collision geometry instead of passing through"),
    ("ForcePOP",        SOURCE_POP, "Verify: particles accelerate in the force direction (gravity, wind)"),
    ("InstancePOP",     SOURCE_POP, "Verify: mesh instances appear at each particle position"),
    ("LimitPOP",        SOURCE_POP, "Verify: particles are confined within the bounding box/sphere"),
    ("NullPOP",         SOURCE_POP, "Verify: particles pass through unchanged (same count, positions)"),
    ("ParticleStateTOP", SOURCE_POP, "Verify: outputs particle state (position/velocity/age) as a texture"),
    ("RenderPOP",       SOURCE_POP, "Verify: particles are rendered as sprites/points in the texture output"),
    ("SourcePOP",       None,       "Verify: particles emit at the configured rate; adjust emit_rate and count"),
    ("TurbulencePOP",   SOURCE_POP, "Verify: particles exhibit chaotic/noisy motion (not smooth paths)"),
]

VOL_OPS = [
    ("AnalyzeVOL",         NOISE_VOL, "Verify: outputs volume statistics (min/max/average density values)"),
    ("BlendVOL",           NOISE_VOL, "Verify: blends two volumes (connect second source to input 1)"),
    ("BlurVOL",            NOISE_VOL, "Verify: volume field is smoother/softer than the noise input"),
    ("CHOPtoVOL",          None,      "Verify: converts CHOP channel data into a 3D volume field"),
    ("DisplaceVOL",        NOISE_VOL, "Verify: volume is warped/displaced compared to the input"),
    ("FluidVOL",           None,      "Verify: 3D fluid simulation evolves over time; inject velocity to see flow"),
    ("GPUMarchingCubesVOL", NOISE_VOL, "Verify: extracts isosurface mesh on GPU; compare with CPU MarchingCubesVOL"),
    ("MarchingCubesVOL",   NOISE_VOL, "Verify: extracts an isosurface mesh (outputs SOP geometry)"),
    ("NoiseVOL",           None,      "Verify: generates a 3D noise volume; change seed/frequency params"),
    ("NullVOL",            NOISE_VOL, "Verify: passes volume through unchanged"),
    ("PyroVOL",            None,      "Verify: fire/smoke simulation runs; combustion visible over time"),
    ("RaymarchVOL",        NOISE_VOL, "Verify: raymarched visualization shows volumetric clouds/density"),
    ("SOPtoVOL",           None,      "Verify: converts SOP mesh into a voxelized volume field"),
]

MAT_OPS = [
    ("ConstantMAT",    None, "Verify: flat unlit color on geometry; change color param and confirm"),
    ("DepthMAT",       None, "Verify: renders geometry as grayscale depth (near=white, far=black)"),
    ("FluidSurfaceMAT", None, "Verify: renders a reflective/refractive fluid surface material"),
    ("LineMAT",        None, "Verify: renders edges/wireframe with configurable line width and color"),
    ("NormalMapMAT",   None, "Verify: visualizes surface normals as RGB colors on geometry"),
    ("NullMAT",        None, "Verify: passes material through unchanged to downstream"),
    ("PbrMAT",         None, "Verify: physically-based shading; adjust roughness/metallic and confirm"),
    ("PointSpriteMAT", None, "Verify: renders points as textured sprites (needs POP or point geometry)"),
    ("ShaderMAT",      None, "Verify: custom shader compiles and applies to geometry; check error log"),
    ("WireframeMAT",   None, "Verify: renders geometry as wireframe only (no filled faces)"),
]

IMG_OPS = [
    ("BlurIMG",          NOISE_IMG, "Verify: output is blurred compared to the noise input"),
    ("CheckerboardIMG",  None,      "Verify: generates a checkerboard pattern; change tile_size params"),
    ("EdgeDetectIMG",    NOISE_IMG, "Verify: outputs only detected edges from the noise input"),
    ("ImageFileInIMG",   None,      "Verify: set a valid image file path; image loads and displays"),
    ("ImageSequenceIMG", None,      "Verify: set a folder of numbered images; frames play back in sequence"),
    ("ImgToTOP",         NOISE_IMG, "Verify: converts CPU Image to GPU Texture (TOP); check output in viewer"),
    ("NoiseIMG",         None,      "Verify: generates CPU-based procedural noise; change seed/scale params"),
    ("NullIMG",          NOISE_IMG, "Verify: output is identical to input (pure passthrough)"),
    ("PixelSortIMG",     NOISE_IMG, "Verify: glitch-art pixel sorting visible; column/row streaks appear"),
    ("ScreenGrabIMG",    None,      "Verify: captures current screen/window content as an image"),
    ("ScriptIMG",        None,      "Verify: runs GDScript to generate an image; check output and error log"),
    ("TOPtoIMG",         None,      "Verify: converts GPU Texture (TOP) to CPU Image; needs TOP input"),
    ("WebcamIMG",        None,      "Verify: captures webcam feed (needs camera hardware connected)"),
]

OUTPUT_OPS = [
    ("AudioDeviceOUT", None, "Verify: routes audio to an output device; connect CHOP audio source"),
    ("FFmpegOUT",      None, "Verify: encodes output to video file via FFmpeg; check file on disk"),
    ("HostOutCHOP",    None, "Verify: sends CHOP data to host application (needs host connection)"),
    ("HostOutDAT",     None, "Verify: sends DAT data to host application (needs host connection)"),
    ("HostOutTOP",     None, "Verify: sends TOP texture to host application (needs host connection)"),
    ("ImageSaveOUT",   None, "Verify: saves input image/texture to disk; check output file exists"),
    ("MovieOUT",       None, "Verify: records texture frames to a video file; check file after stop"),
    ("OscOUT",         None, "Verify: sends OSC messages to target IP:port (use OSC monitor to confirm)"),
    ("RecordOUT",      None, "Verify: records CHOP/DAT data to disk; check output file"),
    ("TableSaveOUT",   None, "Verify: saves DAT table to CSV/TSV file; check file contents"),
    ("TextureSaveOUT", None, "Verify: saves texture to an image file; check file on disk"),
    ("WindowOUT",      None, "Verify: opens a window displaying the input texture; verify visual output"),
]


# ═══════════════════════════════════════════════════════════════════════════════
# Patch builder — one per operator
# ═══════════════════════════════════════════════════════════════════════════════

# Map of upstream class → human-readable label for the sticky note
UPSTREAM_LABELS = {
    "NoiseTOP":   "NoiseTOP → ",
    "ConstantTOP": "ConstantTOP → ",
    "RenderTOP":  "RenderTOP → ",
    "NoiseIMG":   "NoiseIMG → ",
    "SourcePOP":  "SourcePOP → ",
    "NoiseVOL":   "NoiseVOL → ",
    "BoxSOP":     "BoxSOP → ",
}


def make_patch(cls, upstream, verify_text, family):
    """Build one .gnpatch for a single operator under test."""
    nodes_list = []
    conns = []

    if upstream:
        prefix = UPSTREAM_LABELS.get(upstream, upstream + " → ")
        nodes_list.append(node(upstream, "src", 0, 0))
        nodes_list.append(node(cls, "test", 350, 0))
        conns.append(conn("src", 0, "test", 0))
        title = f"MANUAL TEST: {prefix}{cls}"
    else:
        nodes_list.append(node(cls, "test", 0, 0))
        title = f"MANUAL TEST: {cls}"

    note = f"{title}\n\n{verify_text}"
    return patch(nodes_list, conns, note)


def gen_family(family_label, ops_list):
    """Generate one patch per operator in a family. Returns count."""
    count = 0
    for cls, upstream, verify_text in ops_list:
        name = f"test_{cls.lower()}"
        p = make_patch(cls, upstream, verify_text, family_label)
        write(family_label, name, p)
        count += 1
    return count


# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    # Clean old patches first
    if os.path.isdir(PATCH_DIR):
        shutil.rmtree(PATCH_DIR)
    os.makedirs(PATCH_DIR, exist_ok=True)

    total = 0
    families = [
        ("top", TOP_OPS), ("comp", COMP_OPS), ("ui", UI_OPS), ("pop", POP_OPS),
        ("vol", VOL_OPS), ("mat", MAT_OPS), ("img", IMG_OPS), ("output", OUTPUT_OPS),
    ]
    print("Generating 1:1 manual test patches...")
    for label, ops in families:
        n = gen_family(label, ops)
        print(f"  {label}: {n} patches")
        total += n
    print(f"Total: {total} patches (one per operator)")

