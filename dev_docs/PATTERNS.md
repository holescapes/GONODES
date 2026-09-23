# Pattern Matching & Replacement

> **Date:** 2026-04-09
> Global pattern language used across all GONODES operators for filtering,
> selecting, renaming, and expanding names and indices.
>
> **Class:** `GNPattern` (`addons/gonodes/core/gn_pattern.gd`)
>
> **Used by:** SelectCHOP, DeleteCHOP, RenameCHOP, OPFindDAT, FolderDAT,
> and any future operator with name/index filtering.

---

## Table of Contents

1. [Name Matching](#1-name-matching)
2. [Multi-Pattern (CSV)](#2-multi-pattern-csv)
3. [Index Ranges](#3-index-ranges)
4. [Pattern Expansion](#4-pattern-expansion)
5. [Rename Capture & Replacement](#5-rename-capture--replacement)
6. [API Reference](#6-api-reference)
7. [Operator Usage Guide](#7-operator-usage-guide)
8. [Comparison: TD / Houdini / GONODES](#8-comparison-td--houdini--gonodes)
9. [Future Enhancements](#9-future-enhancements)

---

## 1. Name Matching

Name matching filters a list of strings (channel names, node IDs, file names, etc.) against a glob-style pattern.

### 1.1 Wildcards

| Pattern | Meaning | Example |
|---------|---------|---------|
| `*` | Match any string (including empty) | `*` matches everything |
| `?` | Match exactly one character | `t?` matches `tx`, `ty`, `tz` but not `transform` |

### 1.2 Character Sets

| Pattern | Meaning | Example |
|---------|---------|---------|
| `[abc]` | Match one of the listed characters | `[rgb]_out` matches `r_out`, `g_out`, `b_out` |
| `[a-z]` | Match one character in a range | `ch[0-9]` matches `ch0` through `ch9` |
| `[a-zA-Z]` | Multiple ranges | `[a-zA-Z]*` matches names starting with a letter |
| `[!abc]` | Match any character NOT in the set | `[!0-9]*` matches names not starting with a digit |
| `[!a-z]` | Negated range | `[!a-z]*` matches names not starting with lowercase |

### 1.3 Combined Wildcards

You can combine wildcards freely:

| Pattern | What It Matches |
|---------|-----------------|
| `chan*` | Anything starting with "chan" → `chan1`, `channel_x`, `channels` |
| `*_out` | Anything ending with "_out" → `r_out`, `mix_out` |
| `*blend*` | Anything containing "blend" → `blend1`, `color_blend_a` |
| `t?` | Two-character names starting with 't' → `tx`, `ty`, `tz` |
| `node??` | "node" + exactly 2 chars → `node01`, `nodeAB` |
| `[rgb]_[0-9]` | r_0, r_1, ..., g_0, ..., b_9 |
| `*[!_]*` | Names not containing underscore... pattern applied per-char |

### 1.4 Examples: Channel Name Matching

Given channels: `tx, ty, tz, rx, ry, rz, scale_x, scale_y, scale_z, blend1, blend2, temp`

| Pattern | Matches |
|---------|---------|
| `*` | All 12 channels |
| `t?` | `tx`, `ty`, `tz` |
| `?x` | `tx`, `rx` |
| `[tr]?` | `tx`, `ty`, `tz`, `rx`, `ry`, `rz` |
| `scale_*` | `scale_x`, `scale_y`, `scale_z` |
| `blend*` | `blend1`, `blend2` |
| `*_z` | `scale_z` (`_` is literal, so `tz` does not match) |
| `[!t]*` | Everything except `tx`, `ty`, `tz`, `temp` |

---

## 2. Multi-Pattern (CSV)

Multiple patterns are separated by commas. Each is tested independently — a name matches if it matches **any** include pattern and **no** exclude patterns.

### 2.1 Basic Multi-Pattern

| Pattern | Meaning |
|---------|---------|
| `tx, ty, tz` | Exact names `tx` OR `ty` OR `tz` |
| `t*, r*` | Starts with `t` OR starts with `r` |
| `*_x, *_y, *_z` | Ends with `_x`, `_y`, or `_z` |

### 2.2 Exclusion with `!`

Prefix any pattern with `!` to exclude matching names from the result:

| Pattern | Meaning |
|---------|---------|
| `*, !temp` | Everything except `temp` |
| `*, !temp*` | Everything except names starting with `temp` |
| `chan*, !chan3` | Channels starting with "chan" but not "chan3" |
| `[tr]*, !tz` | Translate/rotate channels except `tz` |
| `*, !*_debug, !*_tmp` | Everything except debug and tmp suffixed |

### 2.3 How Exclusion Works

1. **Include pass:** the name must match at least one non-`!` pattern
2. **Exclude pass:** if the name also matches any `!` pattern, it's rejected
3. If **only** `!` patterns are given (no includes), `*` is implied — so `!temp*` means "everything except temp-prefixed"

### 2.4 Examples

Given channels: `tx, ty, tz, rx, ry, rz, blend1, blend2, temp_debug`

| Pattern | Result |
|---------|--------|
| `tx, ry` | `tx`, `ry` |
| `t*, r*` | `tx`, `ty`, `tz`, `rx`, `ry`, `rz`, `temp_debug` |
| `t*, !temp*` | `tx`, `ty`, `tz` |
| `*, !blend*` | `tx`, `ty`, `tz`, `rx`, `ry`, `rz`, `temp_debug` |
| `!tz, !rz` | `tx`, `ty`, `rx`, `ry`, `blend1`, `blend2`, `temp_debug` |
| `blend[12]` | `blend1`, `blend2` |

---

## 3. Index Ranges

Index ranges select elements by their numeric position (0-based index) in a list. Used by DeleteCHOP (By Index Range mode), and available to any operator via `GNPattern.parse_index_range()`.

### 3.1 Syntax

| Syntax | Meaning | Example (count=20) |
|--------|---------|---------------------|
| `5` | Exact index | `[5]` |
| `3-7` | Range, inclusive | `[3, 4, 5, 6, 7]` |
| `0-10:2` | Range with stride (every 2nd) | `[0, 2, 4, 6, 8, 10]` |
| `0-10:3` | Every 3rd | `[0, 3, 6, 9]` |
| `*` | All indices | `[0, 1, 2, ..., 19]` |
| `*:3` | Every 3rd of all | `[0, 3, 6, 9, 12, 15, 18]` |
| `*:2` | Every 2nd of all | `[0, 2, 4, 6, 8, 10, 12, 14, 16, 18]` |
| `!5-10` | All EXCEPT 5-10 | `[0,1,2,3,4, 11,12,...,19]` |

### 3.2 Take-Skip (Houdini-style)

The take-skip syntax `n-m:take,period` selects the first `take` indices, then skips to the next `period`, repeat:

| Syntax | Meaning | Result (count=20) |
|--------|---------|---------------------|
| `0-19:2,5` | Take 2, period 5 (take 2, skip 3) | `[0,1, 5,6, 10,11, 15,16]` |
| `0-19:1,3` | Take 1, period 3 (take 1, skip 2) | `[0, 3, 6, 9, 12, 15, 18]` |
| `0-19:3,4` | Take 3, period 4 (take 3, skip 1) | `[0,1,2, 4,5,6, 8,9,10, 12,13,14, 16,17,18]` |

**Use case:** You have 100 channels interleaved as `x,y,z,x,y,z,...` and want just the X values → `0-99:1,3` (take 1 every 3 = positions 0, 3, 6, 9, ...).

### 3.3 Multiple Ranges (comma-separated)

Combine multiple ranges with commas:

| Syntax | Result |
|--------|--------|
| `0-5, 10-15` | `[0,1,2,3,4,5, 10,11,12,13,14,15]` |
| `0-5, 10-15, 20` | `[0,1,2,3,4,5, 10,11,12,13,14,15, 20]` |
| `*:2, !10-15` | Every 2nd of all, then remove 10-15 |

### 3.4 Exclusion in Index Ranges

Prefix any range with `!` to subtract those indices from the result:

| Syntax | Meaning |
|--------|---------|
| `0-100, !50-60` | 0-100 except 50-60 |
| `*:2, !0` | Every 2nd of all, but not index 0 |
| `*, !0-4` | All except the first 5 |

### 3.5 Practical Examples

**"Every other channel starting from 0"** (your original question):
```
*:2          → 0, 2, 4, 6, 8, ...
```

**"Every other channel starting from 1"**:
```
1-999:2      → 1, 3, 5, 7, 9, ...
```

**"First 3, then every 5th"**:
```
0-2, 5-999:5 → 0, 1, 2, 5, 10, 15, 20, ...
```

**"Interleaved XYZ — extract just Y (index 1 of every 3)"**:
```
1-999:1,3    → 1, 4, 7, 10, 13, ...
```

---

## 4. Pattern Expansion

Expansion generates names from a compact pattern. This is the **inverse** of matching — instead of filtering existing names, it creates new names.

### 4.1 Numeric Ranges

| Pattern | Expands To |
|---------|-----------|
| `ch[1-4]` | `ch1 ch2 ch3 ch4` |
| `ch[0-8:2]` | `ch0 ch2 ch4 ch6 ch8` |
| `blend[1,3,5]` | `blend1 blend3 blend5` |
| `ch[10-12]` | `ch10 ch11 ch12` |

### 4.2 Alpha Sets

Each character inside `[]` becomes a separate result:

| Pattern | Expands To |
|---------|-----------|
| `[xyz]` | `x y z` |
| `[rgb]_out` | `r_out g_out b_out` |
| `t[xyz]` | `tx ty tz` |

### 4.3 Cartesian Product

Multiple bracket groups produce all combinations (left-to-right):

| Pattern | Expands To |
|---------|-----------|
| `[tr][xyz]` | `tx ty tz rx ry rz` |
| `[ab][12]` | `a1 a2 b1 b2` |
| `ch[1-2]_[abc]` | `ch1_a ch1_b ch1_c ch2_a ch2_b ch2_c` |

### 4.4 Space-Separated Tokens

Multiple space-separated patterns are expanded independently and concatenated:

| Pattern | Expands To |
|---------|-----------|
| `ch[1-3] pos[xyz]` | `ch1 ch2 ch3 posx posy posz` |
| `[rgb] alpha` | `r g b alpha` |

### 4.5 Where Expansion Is Used

- **RenameCHOP** `to_pattern` — generates the target names
- **Future:** ConstantCHOP `names`, WaveCHOP `channel_names`, etc.

---

## 5. Rename Capture & Replacement

Renaming combines matching (on the "from" side) with replacement (on the "to" side). Wildcards in the "from" pattern **capture** the text they matched, and the "to" pattern can reference those captures.

### 5.1 Capture Syntax

Each `*` and `?` in the "from" pattern is numbered 0, 1, 2, ... in order of appearance:

| From Pattern | Capture Groups |
|---|---|
| `*_old` | `*(0)` = everything before `_old` |
| `*_*` | `*(0)` = first segment, `*(1)` = second segment |
| `pre_*_mid_*_suf` | `*(0)` = between pre_ and _mid_, `*(1)` = between _mid_ and _suf |
| `?x` | `?(0)` = the single character before `x` |
| `??_*` | `?(0)` = first char, `?(1)` = second char, `*(0)` = rest |

### 5.2 Replacement Syntax

The "to" pattern substitutes captures using `*(N)` and `?(N)`:

| From | To | Input → Output |
|---|---|---|
| `*_old` | `*(0)_new` | `foo_old` → `foo_new` |
| `*_old` | `*(0)_new` | `bar_baz_old` → `bar_baz_new` |
| `*_*` | `*(1)_*(0)` | `left_monitor` → `monitor_left` |
| `*_*` | `*(1).*(0)` | `foo_bar` → `bar.foo` |
| `?x` | `?(0)y` | `tx` → `ty`, `rx` → `ry` |
| `??_*` | `*(0)_?(1)?(0)` | `ab_hello` → `hello_ba` |

### 5.3 Bare Wildcard Shorthand

If the from pattern has only one `*`, a bare `*` in the to pattern is equivalent to `*(0)`:

| From | To | Same As |
|---|---|---|
| `*_old` | `*_new` | `*(0)_new` |
| `pre_*` | `post_*` | `post_*(0)` |

Similarly, a bare `?` is equivalent to `?(0)`.

### 5.4 Expansion in To Patterns

The to pattern can use `[...]` expansion to generate sequential names:

| From | To | Input Channels → Output |
|---|---|---|
| `chan*` | `tx[1-4]` | `chan0, chan1, chan2, chan3` → `tx1, tx2, tx3, tx4` |
| `*` | `output[1-8]` | 8 channels → `output1, output2, ..., output8` |
| `*` | `[rgb]_out` | 3 channels → `r_out, g_out, b_out` |

When expansion produces fewer names than matching channels, the last expanded name is reused. When it produces more, extras are ignored.

### 5.5 Comprehensive Rename Examples

**Prefix replacement:**
```
From: old_*          To: new_*(0)
  old_position → new_position
  old_rotation → new_rotation
  old_scale    → new_scale
```

**Suffix swap:**
```
From: *_left         To: *(0)_right
  hand_left → hand_right
  foot_left → foot_right
```

**Two-part swap (TD-style):**
```
From: *_side_*       To: *(1)_floor_*(0)
  left_side_monitor   → monitor_floor_left
  right_side_projector → projector_floor_right
  top_side_led        → led_floor_top
```

**Single-character transform:**
```
From: ?x             To: ?(0)y
  tx → ty
  rx → ry
```

**Sequential numbering:**
```
From: chan*           To: output[1-8]
  chan0 → output1    (first match)
  chan1 → output2    (second match)
  chan2 → output3    ...
```

**Character class rename:**
```
From: [rgb]_in       To: [rgb]_out
  r_in → r_out      (via expansion: 3 targets assigned sequentially)
  g_in → g_out
  b_in → b_out
```

---

## 6. API Reference

All functions are `static` on `class_name GNPattern`.

### 6.1 Name Matching

```gdscript
# Single pattern match
GNPattern.matches("tx", "t?")              # → true
GNPattern.matches("blend2", "blend*")      # → true
GNPattern.matches("hello", "[a-z]*")       # → true

# Multi-pattern with exclusion
GNPattern.matches_any("tx", "t*, !tz")     # → true
GNPattern.matches_any("tz", "t*, !tz")     # → false
GNPattern.matches_any("blend", "*, !temp*") # → true

# Filter an array
var names = PackedStringArray(["tx", "ty", "tz", "rx", "ry", "rz"])
GNPattern.filter(names, "t*")
# → ["tx", "ty", "tz"]

GNPattern.filter(names, "?z")
# → ["tz", "rz"]

GNPattern.filter(names, "*, !tz, !rz")
# → ["tx", "ty", "rx", "ry"]
```

### 6.2 Index Ranges

```gdscript
# Simple range
GNPattern.parse_index_range("3-7", 20)
# → [3, 4, 5, 6, 7]

# Stride
GNPattern.parse_index_range("0-10:2", 20)
# → [0, 2, 4, 6, 8, 10]

# Every 3rd of all
GNPattern.parse_index_range("*:3", 12)
# → [0, 3, 6, 9]

# Take-skip: take 2, repeat every 5
GNPattern.parse_index_range("0-19:2,5", 20)
# → [0, 1, 5, 6, 10, 11, 15, 16]

# Combined with exclusion
GNPattern.parse_index_range("0-20, !10-12", 21)
# → [0,1,2,3,4,5,6,7,8,9, 13,14,15,16,17,18,19,20]

# Multiple ranges
GNPattern.parse_index_range("0-3, 10-13, 20", 25)
# → [0, 1, 2, 3, 10, 11, 12, 13, 20]
```

### 6.3 Pattern Expansion

```gdscript
GNPattern.expand("ch[1-4]")
# → ["ch1", "ch2", "ch3", "ch4"]

GNPattern.expand("[rgb]_out")
# → ["r_out", "g_out", "b_out"]

GNPattern.expand("[tr][xyz]")
# → ["tx", "ty", "tz", "rx", "ry", "rz"]

GNPattern.expand("ch[0-8:2]")
# → ["ch0", "ch2", "ch4", "ch6", "ch8"]

GNPattern.expand("ch[1-2] pos[xyz]")
# → ["ch1", "ch2", "posx", "posy", "posz"]
```

### 6.4 Rename

```gdscript
# Single rename
GNPattern.rename("foo_old", "*_old", "*(0)_new")
# → "foo_new"

# Non-matching input passes through
GNPattern.rename("bar", "*_old", "*(0)_new")
# → "bar"

# Batch rename
var names = PackedStringArray(["tx", "ty", "tz", "scale"])
var result = GNPattern.rename_batch(names, "t?", "?(0)_translate")
# → {"tx": "x_translate", "ty": "y_translate", "tz": "z_translate"}
# "scale" not in result (didn't match)

# Batch with expansion
var chans = PackedStringArray(["a", "b", "c", "d"])
var result2 = GNPattern.rename_batch(chans, "*", "out[1-4]")
# → {"a": "out1", "b": "out2", "c": "out3", "d": "out4"}
```

### 6.5 Utility

```gdscript
GNPattern.split_patterns("tx, ty, !tz, rz")
# → {"include": ["tx", "ty", "rz"], "exclude": ["tz"]}

GNPattern.split_patterns("!temp*")
# → {"include": ["*"], "exclude": ["temp*"]}
# (auto-adds * when only excludes are present)
```

---

## 7. Operator Usage Guide

### 7.1 SelectCHOP

| Parameter | Uses GNPattern | How |
|-----------|---------------|-----|
| `pattern` | `matches_any()` | Filters channels by name |
| `rename` | `rename_batch()` | If set, renames matching channels using capture/expansion syntax |

**Examples:**

Select translate channels:
```
pattern: t*
```

Select everything except temp:
```
pattern: *, !temp*
```

Select and rename:
```
pattern: *_left
rename:  *(0)_right
```
→ `hand_left` becomes `hand_right`

### 7.2 DeleteCHOP

| Parameter | Uses GNPattern | How |
|-----------|---------------|-----|
| `pattern` | `matches_any()` | Modes 0 and 2: filter by name |
| `index_range` | `parse_index_range()` | Mode 3: delete by index expression |

**Examples:**

Delete channels named "temp" or "debug":
```
scope: By Pattern
pattern: temp*, debug*
```

Keep only translate:
```
scope: Keep Only Pattern
pattern: t?
```

Delete every other channel:
```
scope: By Index Range
index_range: *:2
```

Delete channels 10-20 except 15:
```
scope: By Index Range
index_range: 10-20, !15
```

### 7.3 RenameCHOP

Two modes:

**Pattern mode** (new):

| Parameter | Uses GNPattern | How |
|-----------|---------------|-----|
| `from_pattern` | Matching + capture | Glob pattern to match channels |
| `to_pattern` | Replacement + expansion | Target names with `*(N)`, `?(N)`, `[1-N]` |

Examples:
```
from: *_old        to: *(0)_new           # suffix swap
from: *_*          to: *(1)_*(0)          # two-part swap
from: chan*         to: output[1-8]        # sequential rename
from: ?x           to: ?(0)y              # single-char transform
from: [tr][xyz]    to: translate_[xyz] rotate_[xyz]  # expansion
```

**Manual Rows mode** (legacy): explicit from/to pairs, no wildcards.

### 7.4 OPFindDAT

| Parameter | Uses GNPattern | How |
|-----------|---------------|-----|
| `name_pattern` | `matches_any()` | Filters nodes by ID/name |

**Examples:**

Find all noise nodes:
```
name_pattern: noise*
```

Find everything except utility nodes:
```
name_pattern: *, !null*, !select*
```

### 7.5 FolderDAT

| Parameter | Uses GNPattern | How |
|-----------|---------------|-----|
| `filter` | `matches_any()` | Filters file names |

**Examples:**

Only PNG files:
```
filter: *.png
```

Images:
```
filter: *.png, *.jpg, *.webp, *.exr
```

Everything except temp files:
```
filter: *, !*.tmp, !*.bak
```

---

## 8. Comparison: TD / Houdini / GONODES

### 8.1 Name Matching

| Feature | Houdini | TD | GONODES |
|---------|---------|-----|---------|
| `*` any string | ✅ | ✅ | ✅ |
| `?` single char | ✅ | ✅ | ✅ |
| `[abc]` char set | ✅ | ✅ | ✅ |
| `[a-z]` char range | ❌ | ❌ | ✅ |
| `[!abc]` negated set | ❌ | ❌ | ✅ |
| Multi-pattern | ✅ (space-sep) | ✅ (space-sep) | ✅ (comma-sep) |
| `!` / `^` exclusion | ✅ | ✅ | ✅ |
| `\|` union | ❌ | ✅ | ❌ (comma = union) |
| `&` intersection | ❌ | ✅ | ❌ (planned) |
| `~` set difference | ❌ | ✅ | ❌ (! covers this) |
| `()` grouping | ❌ | ✅ | ❌ (planned) |

### 8.2 Index Ranges

| Feature | Houdini | TD | GONODES |
|---------|---------|-----|---------|
| `n` exact | ✅ | ✅ | ✅ |
| `n-m` range | ✅ | ✅ | ✅ |
| `n-m:step` stride | ✅ | ✅ | ✅ |
| `n-m:take,period` | ✅ | ✅ (`[n-m:take:period]`) | ✅ |
| `*:N` every Nth of all | ❌ | ✅ | ✅ |
| `!` exclude | ✅ | ✅ (`^`) | ✅ |

### 8.3 Rename / Replacement

| Feature | Houdini | TD | GONODES |
|---------|---------|-----|---------|
| Wildcard capture `*(0)` | ❌ (uses VEX) | ✅ | ✅ |
| `?(0)` single-char capture | ❌ | ✅ | ✅ |
| `[1-5]` expansion | ❌ | ✅ | ✅ |
| `[abc]` alpha expansion | ❌ | ✅ | ✅ |
| `[tr][xyz]` cartesian | ❌ | ✅ | ✅ |
| Bare `*` shorthand | ❌ | ❌ | ✅ |

### 8.4 Summary

GONODES covers ~95% of combined TD + Houdini pattern capabilities. It exceeds both in character ranges (`[a-z]`), negated sets (`[!abc]`), and bare wildcard shorthand. The remaining gaps are TD's set algebra operators (`&`, `|`, `~`, `()`) and Houdini's attribute filter (`@attr>0`) — both are planned for future versions.

---

## 9. Future Enhancements

These features are not yet implemented but the API is designed to accommodate them without breaking changes.

### 9.1 Set Intersection (`&`)

**What:** Match names that satisfy **both** patterns simultaneously.

**Syntax:** `geo* & *light` — names starting with "geo" AND ending with "light".

**Use case:** Complex filtering when exclusion alone isn't sufficient.

**Status:** Planned. Requires extending `split_patterns()` to recognise `&` as a binary operator and `filter()` to compute set intersection.

### 9.2 Grouped Expressions with `()`

**What:** Parentheses to control evaluation order in compound patterns.

**Syntax:** `(* & geo*) | light3` — everything that is a geo, plus `light3`.

**Use case:** Power-user compound filtering.

**Status:** Planned. Requires a tokeniser/parser for the pattern string instead of simple comma-split.

### 9.3 Attribute Filter (`@attr`)

**What:** Filter geometry elements (points, primitives) by attribute value.

**Syntax:** `@Cd.r > 0.5` — points whose red colour channel exceeds 0.5.

**Use case:** GroupSOP, SelectSOP, DeleteSOP — geometry-specific filtering tied to SOP data.

**Status:** Planned as a **separate layer** on SOP operators (not in GNPattern core, since it requires access to geometry data). Will parse `@name op value` syntax and evaluate against `GNGeometryData` attributes.

### 9.4 Quoted Literal Patterns

**What:** Match a string with spaces literally.

**Syntax:** `"my pattern"` — treats spaces as literal, not separators.

**Use case:** Edge case for names containing spaces.

**Status:** Low priority. GONODES uses comma separation (not space), so this is less needed than in TD/Houdini.

### 9.5 Case-Insensitive Matching Option

**What:** Optional case-insensitive matching mode.

**Syntax:** API flag `GNPattern.matches(text, pattern, true)` or prefix `~pattern` in the pattern string.

**Use case:** FolderDAT file name matching on case-insensitive filesystems (Windows).

**Status:** Planned. OPFindDAT's old inline matcher was case-insensitive; consider adding an optional parameter.

---

## Appendix A: Quick Reference Card

```
─── NAME MATCHING ───────────────────────────────────────
  *              any string
  ?              any single character
  [abc]          one of a, b, c
  [a-z]          character range
  [!abc]         NOT one of a, b, c
  prefix*        starts with prefix
  *suffix        ends with suffix
  *mid*          contains mid

─── MULTI-PATTERN ───────────────────────────────────────
  a, b, c        match a OR b OR c
  *, !x          all except x
  a*, !ab        starts with a, except ab

─── INDEX RANGES ────────────────────────────────────────
  5              exact index 5
  0-10           indices 0 through 10
  0-10:2         every 2nd: 0, 2, 4, 6, 8, 10
  0-20:3,7       take 3, period 7: 0,1,2, 7,8,9, 14,15,16
  *:3            every 3rd of all
  !5-10          all except 5-10

─── EXPANSION ───────────────────────────────────────────
  ch[1-4]        ch1 ch2 ch3 ch4
  [rgb]_out      r_out g_out b_out
  ch[0-8:2]      ch0 ch2 ch4 ch6 ch8
  [tr][xyz]      tx ty tz rx ry rz

─── RENAME CAPTURE ──────────────────────────────────────
  from: *_old     to: *(0)_new       (capture + replace)
  from: *_*       to: *(1)_*(0)      (swap two parts)
  from: ?x        to: ?(0)y          (single char swap)
  from: chan*      to: out[1-8]       (sequential numbering)
  from: *_old     to: *_new          (bare * = *(0) shorthand)
```
