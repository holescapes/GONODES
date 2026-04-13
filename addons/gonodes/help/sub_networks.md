# Sub-Networks

Sub-networks let you encapsulate a group of nodes into a single container
node, keeping your patch clean and reusable. Double-click to dive in,
Backspace to navigate back out.

---

## Overview

A **SubNetworkNode** (COMP family) contains a nested node graph. From the
outside it looks like a single node with custom inputs and outputs. Inside,
**InTunnel** and **OutTunnel** operators bridge data between the outer and
inner graphs.

---

## Creating a Sub-Network

### Method 1: Group Selected Nodes

1. Select the nodes you want to group
2. Press **Ctrl+G** (or right-click → **Group into Sub-Network**)
3. GONODES automatically:
   - Creates a SubNetworkNode at the centroid of the selection
   - Moves selected nodes inside
   - Creates InTunnels for incoming connections
   - Creates OutTunnels for outgoing connections
   - Remaps all wires correctly

### Method 2: Create Empty

1. Press **Alt+A** → type "SubNetwork" → add it
2. Double-click to dive in
3. Build your inner graph from scratch
4. Add InTunnel / OutTunnel nodes manually for inputs and outputs

---

## Navigation

### Diving In

- **Double-click** the SubNetworkNode, or
- Select it and press **Enter**

The graph editor switches to show the inner network. A **breadcrumb bar**
appears above the graph showing your navigation path.

### Navigating Back

- Press **Backspace**, or
- Click any level in the breadcrumb bar

View state (scroll position, zoom, selected viewer node) is saved and
restored at each level.

### Breadcrumb Bar

When inside a sub-network, the breadcrumb shows:

```
Root  ▸  subnet1  ▸  inner_subnet
```

Click "Root" to jump directly to the top level. Click any intermediate
level to navigate there. The breadcrumb is hidden when at the root level.

---

## Tunnels

Tunnels define the external ports of a sub-network.

### InTunnel

- Placed **inside** the sub-network
- Receives data from the outer graph
- Parameters:
  - `index` (Int, 0–32): Which external input port this tunnel maps to
  - `family` (Enum): Data type — TOP, IMG, CHOP, SOP, POP, DAT, MAT, COMP
  - `label` (String): Port label shown on the outer node

### OutTunnel

- Placed **inside** the sub-network
- Sends data to the outer graph
- Same parameters as InTunnel (index, family, label)
- Marked as a **sink** — the inner cook engine treats it as an output

### Port Syncing

When you add, remove, or change tunnels inside the sub-network, the
external ports on the SubNetworkNode update automatically. The outer
node's port count and types always reflect the current InTunnel/OutTunnel
configuration.

---

## How Cooking Works

When the cook engine reaches a SubNetworkNode:

1. Upstream data is injected into each InTunnel's cached output
2. The inner cook engine runs one `cook_frame()` cycle
3. OutTunnel results are read back as the SubNetworkNode's output
4. Timing context (elapsed_time, delta, frame_count) is propagated to
   the inner engine

This means sub-networks cook as part of the normal frame — no extra
overhead beyond the cost of the inner nodes themselves.

---

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `label` | String | "Subnet" | Display label on the outer node |

---

## Serialization

Sub-networks serialize their entire inner graph inside the parent
`.gnpatch` file. The `to_dict()` output embeds the inner network's
nodes, connections, and annotations. Loading restores everything,
including nested sub-networks (sub-networks inside sub-networks).

---

## Tips

- Use sub-networks to **reuse** common patterns — build once, copy
  the SubNetworkNode elsewhere.
- Sub-networks can be **nested** — a sub-network can contain other
  sub-networks, with unlimited depth.
- The **Ctrl+G** shortcut is the fastest way to clean up a messy patch.
- Name your tunnels descriptively (e.g., "texture_in", "geo_out") —
  the labels appear on the outer node's ports.
- You can have multiple InTunnels and OutTunnels of different families
  in the same sub-network (e.g., a CHOP input + SOP input → TOP output).
- To make a sub-network reusable across patches, promote it to a
  **custom asset** — see the Custom Assets guide.
