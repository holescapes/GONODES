"""Add VectorPathTOP chain with both inputs to ALL_CORE_TOPs.gnpatch."""
import json, sys

PATCH = r"c:\MeOwn\Gonodes\tests\manual\top\ALL_CORE_TOPs.gnpatch"

with open(PATCH, "r", encoding="utf-8") as f:
    data = json.load(f)

# ── New nodes ──────────────────────────────────────────────────────────
# Chain: WaveCHOP (points) + TableDAT (SVG commands) → VectorPathTOP → CompositeTOP (over noise) → NullTOP
# Y baseline = 2700 (below current max of 2400)
Y = 2700.0

new_nodes = {
    # WaveCHOP generates animated x,y point data for the path
    "wave_vp": {
        "type": "WaveCHOP",
        "position": [0.0, Y],
        "parameters": {
            "wave_type": {"value": 0},
            "channels": {"value": "x0 y0 x1 y1 x2 y2 x3 y3"},
            "frequency": {"value": 0.5},
            "amplitude": {"value": 200.0},
            "offset": {"value": 256.0},
            "phase": {"value": 0.0}
        }
    },
    # TableDAT provides SVG-like path commands to draw a bezier curve
    "table_vp": {
        "type": "TableDAT",
        "position": [0.0, Y + 200.0],
        "parameters": {
            "rows": {"value": 5},
            "cols": {"value": 2},
            "data": {
                "value": "cmd,val\nM,0\nC,0\nC,0\nZ,0"
            }
        }
    },
    # VectorPathTOP renders the path — uses BOTH inputs
    "vector_path1": {
        "type": "VectorPathTOP",
        "position": [400.0, Y],
        "parameters": {
            "resolution": {
                "value": {"_type": "Vector2i", "x": 512, "y": 512}
            },
            "shape": {"value": 4},
            "stroke_color": {
                "value": {"_type": "Color", "r": 0.2, "g": 0.8, "b": 1.0, "a": 1.0}
            },
            "stroke_width": {"value": 3.0},
            "fill": {"value": True},
            "fill_color": {
                "value": {"_type": "Color", "r": 0.1, "g": 0.3, "b": 0.6, "a": 0.4}
            },
            "bg_color": {
                "value": {"_type": "Color", "r": 0.0, "g": 0.0, "b": 0.0, "a": 0.0}
            },
            "antialiased": {"value": True}
        }
    },
    # NoiseTOP as background layer for the composite
    "noise_vp_bg": {
        "type": "NoiseTOP",
        "position": [400.0, Y + 200.0],
        "parameters": {
            "resolution": {
                "value": {"_type": "Vector2i", "x": 512, "y": 512}
            },
            "seed": {"value": 7},
            "octaves": {"value": 3},
            "amplitude": {"value": 0.4}
        }
    },
    # CompositeTOP layers vector graphics over noise background
    "comp_vp": {
        "type": "CompositeTOP",
        "position": [800.0, Y],
        "parameters": {
            "operation": {"value": 0}
        }
    },
    # NullTOP as chain output
    "OUTChainVP": {
        "type": "NullTOP",
        "position": [1200.0, Y],
        "parameters": {}
    }
}

# ── New connections ────────────────────────────────────────────────────
new_connections = [
    # CHOP points → VectorPathTOP port 0
    {"from": "wave_vp", "from_port": 0, "to": "vector_path1", "to_port": 0},
    # DAT commands → VectorPathTOP port 1
    {"from": "table_vp", "from_port": 0, "to": "vector_path1", "to_port": 1},
    # VectorPathTOP → CompositeTOP port 0 (foreground)
    {"from": "vector_path1", "from_port": 0, "to": "comp_vp", "to_port": 0},
    # NoiseTOP → CompositeTOP port 1 (background)
    {"from": "noise_vp_bg", "from_port": 0, "to": "comp_vp", "to_port": 1},
    # CompositeTOP → NullTOP output
    {"from": "comp_vp", "from_port": 0, "to": "OUTChainVP", "to_port": 0},
]

# ── Apply ──────────────────────────────────────────────────────────────
data["nodes"].update(new_nodes)
data["connections"].extend(new_connections)

with open(PATCH, "w", encoding="utf-8", newline="") as f:
    json.dump(data, f, indent="\t", ensure_ascii=False)

n_nodes = len(data["nodes"])
n_conn = len(data["connections"])
print(f"Done. Patch now has {n_nodes} nodes, {n_conn} connections.")
print("Added: wave_vp, table_vp, vector_path1, noise_vp_bg, comp_vp, OUTChainVP")
