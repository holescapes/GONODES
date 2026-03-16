#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# GONODES Template Builder  (Linux / macOS)
# ═══════════════════════════════════════════════════════════════════════════════
#
# Builds Player (and optionally Editor) binaries for all desktop platforms.
# Equivalent to scripts/build_templates.ps1 on Windows.
#
# Usage:
#   ./scripts/build_templates.sh --godot /path/to/godot
#   ./scripts/build_templates.sh --platforms all
#   ./scripts/build_templates.sh --platforms linux_x86_64,macos --clean
#   ./scripts/build_templates.sh --restore-only
#
# Prerequisites:
#   - Godot 4.6.x editor binary (with export templates installed)
#   - Export templates matching your Godot version
#   - export_presets.cfg with presets for each target platform
#
# Godot Version: 4.6.1 stable (update export templates when upgrading Godot)
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ─── Constants ─────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT_VERSION_EXPECTED="4.6"
EDITOR_MAIN_SCENE='res://scenes/gn_editor.tscn'
PLAYER_MAIN_SCENE='res://scenes/player_main.tscn'

# ─── Defaults ──────────────────────────────────────────────────────────────────

GODOT_PATH=""
PROJECT_PATH=""
OUTPUT_DIR=""
BUILD_ALL=false
INCLUDE_EDITOR=false
GDEXT_MODE="auto"
CLEAN=false
RESTORE_ONLY=false

# Auto-detect host platform for default
detect_host_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"
    case "$os" in
        Darwin)  echo "macos" ;;
        Linux)
            case "$arch" in
                x86_64|amd64)  echo "linux_x86_64" ;;
                aarch64|arm64) echo "linux_arm64"   ;;
                *)             echo "linux_x86_64"  ;;
            esac
            ;;
        MINGW*|MSYS*|CYGWIN*)
            case "$arch" in
                x86_64|amd64)  echo "windows_x86_64" ;;
                aarch64|arm64) echo "windows_arm64"   ;;
                *)             echo "windows_x86_64"  ;;
            esac
            ;;
        *)  echo "linux_x86_64" ;;
    esac
}

PLATFORMS="$(detect_host_platform)"

# Platform → preset name mappings
# Associative arrays require bash 4+; for broader compat we use case statements.

player_preset_name() {
    case "$1" in
        windows_x86_64) echo "Player Windows x86_64" ;;
        windows_arm64)  echo "Player Windows ARM64"  ;;
        linux_x86_64)   echo "Player Linux x86_64"   ;;
        linux_arm64)    echo "Player Linux ARM64"    ;;
        macos)          echo "Player macOS"          ;;
        android)        echo "Player Android ARM64"  ;;
        ios)            echo "Player iOS ARM64"      ;;
        web)            echo "Player Web"            ;;
        *) return 1 ;;
    esac
}

editor_preset_name() {
    case "$1" in
        windows_x86_64) echo "Editor Windows x86_64" ;;
        windows_arm64)  echo "Editor Windows ARM64"  ;;
        linux_x86_64)   echo "Editor Linux x86_64"   ;;
        linux_arm64)    echo "Editor Linux ARM64"    ;;
        macos)          echo "Editor macOS"          ;;
        android|ios|web) echo "" ;;  # No editor builds for mobile/web
        *) return 1 ;;
    esac
}

platform_ext() {
    case "$1" in
        windows_x86_64|windows_arm64) echo ".exe" ;;
        macos)                        echo ".app" ;;
        android)                      echo ".apk" ;;
        ios)                          echo ".ipa" ;;
        web)                          echo ".html" ;;
        *)                            echo ""     ;;
    esac
}

# ─── Output Helpers ────────────────────────────────────────────────────────────

C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_RED='\033[0;31m'
C_GRAY='\033[0;90m'
C_RESET='\033[0m'

step()  { printf "\n${C_CYAN}━━━ %s${C_RESET}\n" "$*"; }
ok()    { printf "  ${C_GREEN}✓${C_RESET} %s\n" "$*"; }
warn()  { printf "  ${C_YELLOW}⚠${C_RESET} %s\n" "$*"; }
fail()  { printf "  ${C_RED}✗${C_RESET} %s\n" "$*"; }

# ─── Argument Parsing ─────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --godot PATH         Path to the Godot editor binary
  --project PATH       GONODES project root (default: parent of scripts/)
  --output PATH        Output directory (default: <project>/templates)
  --platforms LIST     Comma-separated: windows_x86_64,windows_arm64,
                       linux_x86_64,linux_arm64,macos   or "all"
                       (default: auto-detect host platform)
  --build-all          Build Player + Editor for ALL platforms
                       (shortcut for --platforms all --include-editor)
  --include-editor     Also build Editor binaries
  --gdext MODE         GDExtension handling mode (default: auto)
                         auto   Smart filter: keep entries for existing files,
                                remove missing.  Extensions with zero libraries
                                are disabled entirely.
                         all    Include everything as-is.
                         none   Disable ALL GDExtension files.
                         name,name,...  Include only named addons (by folder
                                name under addons/); disable the rest.
  --clean              Remove templates/ before building
  --restore-only       Recovery: restore project.godot main scene
  -h, --help           Show this help
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --godot)          GODOT_PATH="$2"; shift 2 ;;
        --project)        PROJECT_PATH="$2"; shift 2 ;;
        --output)         OUTPUT_DIR="$2"; shift 2 ;;
        --platforms)      PLATFORMS="$2"; shift 2 ;;
        --build-all)      BUILD_ALL=true; shift ;;
        --include-editor) INCLUDE_EDITOR=true; shift ;;
        --include-gdext)  GDEXT_MODE="all"; shift ;;   # compat alias
        --gdext)          GDEXT_MODE="$2"; shift 2 ;;
        --clean)          CLEAN=true; shift ;;
        --restore-only)   RESTORE_ONLY=true; shift ;;
        -h|--help)        usage ;;
        *) fail "Unknown option: $1"; usage ;;
    esac
done

# ─── Godot Discovery ──────────────────────────────────────────────────────────

find_godot() {
    # Explicit path
    if [[ -n "$GODOT_PATH" && -x "$GODOT_PATH" ]]; then
        echo "$GODOT_PATH"
        return
    fi

    # Search PATH
    for name in godot godot4 Godot; do
        local found
        found="$(command -v "$name" 2>/dev/null || true)"
        if [[ -n "$found" ]]; then
            echo "$found"
            return
        fi
    done

    # macOS common locations
    if [[ "$(uname -s)" == "Darwin" ]]; then
        local app_path="/Applications/Godot.app/Contents/MacOS/Godot"
        if [[ -x "$app_path" ]]; then
            echo "$app_path"
            return
        fi
    fi

    # Linux common locations
    for p in /usr/bin/godot /usr/local/bin/godot "$HOME/.local/bin/godot"; do
        if [[ -x "$p" ]]; then
            echo "$p"
            return
        fi
    done

    echo ""
}

check_godot_version() {
    local godot="$1"
    local ver
    ver="$("$godot" --version 2>&1 | head -1)" || true
    if [[ "$ver" == ${GODOT_VERSION_EXPECTED}* ]]; then
        ok "Godot version: $ver"
        return 0
    fi
    warn "Expected Godot ${GODOT_VERSION_EXPECTED}.x, got: $ver"
    warn "Export templates may not match — proceed with caution."
    return 0  # warn-only, don't block
}

# ─── Main-Scene Swap ──────────────────────────────────────────────────────────

get_main_scene() {
    local project_godot="$1"
    grep -oP 'run/main_scene="\K[^"]+' "$project_godot" 2>/dev/null || echo ""
}

set_main_scene() {
    local project_godot="$1"
    local scene="$2"

    if grep -q 'run/main_scene=' "$project_godot"; then
        # Portable sed: macOS needs -i '' syntax, GNU needs just -i
        if [[ "$(uname -s)" == "Darwin" ]]; then
            sed -i '' "s|run/main_scene=\"[^\"]*\"|run/main_scene=\"${scene}\"|" "$project_godot"
        else
            sed -i "s|run/main_scene=\"[^\"]*\"|run/main_scene=\"${scene}\"|" "$project_godot"
        fi
        return 0
    fi
    fail "Could not find run/main_scene in project.godot"
    return 1
}

# ─── Pre-Build Hygiene ─────────────────────────────────────────────────────────

remove_temp_files() {
    local project="$1"
    local addons_dir="$project/addons"
    [[ -d "$addons_dir" ]] || return 0

    # Windows antivirus, file indexers, and Godot itself can leave ~*.TMP files
    # next to DLLs.  These confuse Godot's export file-copy step.
    local found=0
    while IFS= read -r -d '' tmpfile; do
        if rm -f "$tmpfile" 2>/dev/null; then
            ok "Cleaned temp file: $(basename "$tmpfile")"
        else
            warn "Could not remove temp file (may be locked): $(basename "$tmpfile")"
        fi
        found=1
    done < <(find "$addons_dir" -name '~*' -o -name '*.TMP' -print0 2>/dev/null || true)
}

check_gdextensions() {
    local project="$1"
    shift
    local platforms=("$@")
    local addons_dir="$project/addons"
    [[ -d "$addons_dir" ]] || return 0

    # Scan .gdextension files and check if referenced libraries exist
    while IFS= read -r -d '' ext_file; do
        local ext_name
        ext_name="$(basename "$(dirname "$ext_file")")/$(basename "$ext_file")"

        for plat in "${platforms[@]}"; do
            local prefixes
            case "$plat" in
                windows_x86_64) prefixes="windows.release.x86_64 windows.debug.x86_64" ;;
                windows_arm64)  prefixes="windows.release.arm64 windows.debug.arm64" ;;
                linux_x86_64)   prefixes="linux.release.x86_64 linux.debug.x86_64" ;;
                linux_arm64)    prefixes="linux.release.arm64 linux.debug.arm64" ;;
                macos)          prefixes="macos.release macos.debug" ;;
                *)              continue ;;
            esac

            for prefix in $prefixes; do
                # Match: prefix = "res://path/to/lib"
                local res_path
                res_path="$(grep -oP "^\s*${prefix//./\\.}\s*=\s*\"\Kres://[^\"]+" "$ext_file" 2>/dev/null || true)"
                if [[ -n "$res_path" ]]; then
                    local disk_path="${res_path#res://}"
                    local full_path="$project/$disk_path"
                    if [[ ! -e "$full_path" ]]; then
                        warn "GDExtension '$ext_name' references missing library for $plat"
                        warn "  Expected: $disk_path"
                        warn "  Export for $plat may fail -- the extension will not be included."
                    fi
                fi
            done
        done
    done < <(find "$addons_dir" -name '*.gdextension' -print0 2>/dev/null || true)
}

# --- GDExtension Disable / Restore --------------------------------------------
#
# Modes (controlled by --gdext):
#
#   auto  (default)
#       Comment out [libraries] entries whose files are missing.
#       If ALL entries for an extension are missing, DELETE the .gdextension
#       (and its .uid) so Godot never tries to load it.
#
#   none
#       Delete every .gdextension (and .uid) so Godot loads none of them.
#
#   <name,name,...>
#       Named addons get 'auto' treatment; everything else is deleted.
#
# Originals backup: .gdextension.bak / .uid.bak
# .godot/uid_cache.bin is deleted to prevent stale UID errors.

MODIFIED_GDEXT_FILES=()

disable_gdextensions() {
    local project="$1" mode="$2"
    local addons_dir="$project/addons"
    [[ -d "$addons_dir" ]] || return 0

    local filter_mode
    filter_mode="$(echo "$mode" | tr '[:upper:]' '[:lower:]' | xargs)"
    [[ "$filter_mode" == "all" ]] && return 0  # nothing to change

    local is_none=false is_auto=false
    declare -a allowed_addons=()
    if [[ "$filter_mode" == "none" ]]; then
        is_none=true
    elif [[ "$filter_mode" == "auto" ]]; then
        is_auto=true
    else
        IFS=',' read -ra allowed_addons <<< "$filter_mode"
        # lowercase all entries
        for i in "${!allowed_addons[@]}"; do
            allowed_addons[$i]="$(echo "${allowed_addons[$i]}" | xargs | tr '[:upper:]' '[:lower:]')"
        done
    fi

    # Delete uid_cache.bin to prevent stale UID references
    local uid_cache="$project/.godot/uid_cache.bin"
    if [[ -f "$uid_cache" ]]; then
        rm -f "$uid_cache"
        ok "Cleared UID cache (will regenerate)"
    fi

    while IFS= read -r -d '' ext_file; do
        local dir_name base_name bak_path addon_name
        dir_name="$(dirname "$ext_file")"
        base_name="$(basename "$ext_file")"
        bak_path="${ext_file}.bak"

        # Addon name = first directory component under addons/
        local rel_path="${ext_file#$addons_dir/}"
        addon_name="$(echo "${rel_path%%/*}" | tr '[:upper:]' '[:lower:]')"

        # Should this addon be fully disabled or smart-filtered?
        local should_disable=false
        if $is_none; then
            should_disable=true
        elif ! $is_auto && [[ ${#allowed_addons[@]} -gt 0 ]]; then
            # Named list mode: disable if NOT in allowed list
            should_disable=true
            for a in "${allowed_addons[@]}"; do
                if [[ "$a" == "$addon_name" ]]; then
                    should_disable=false
                    break
                fi
            done
        fi

        # Backup original
        if ! cp "$ext_file" "$bak_path" 2>/dev/null; then
            warn "Could not backup $base_name"
            continue
        fi

        if $should_disable; then
            # --- Fully disable: delete .gdextension + .uid ---
            local uid_file="${ext_file}.uid"
            if [[ -f "$uid_file" ]]; then
                cp "$uid_file" "${uid_file}.bak" 2>/dev/null || true
                rm -f "$uid_file"
            fi
            rm -f "$ext_file"
            MODIFIED_GDEXT_FILES+=("$ext_file")
            ok "Disabled: $addon_name/$base_name (removed during build)"
            continue
        fi

        # --- Smart filter: comment out missing library entries ---
        local in_libraries=false changed=false remaining_entries=0
        local tmp_file="${ext_file}.tmp"
        > "$tmp_file"

        while IFS= read -r line; do
            if [[ "$line" =~ ^\[.*\] ]]; then
                if [[ "$line" =~ ^\[libraries\] ]]; then
                    in_libraries=true
                else
                    in_libraries=false
                fi
            fi

            if $in_libraries && [[ "$line" =~ =.*\"(res://[^\"]+)\" ]]; then
                local res_path="${BASH_REMATCH[1]}"
                local disk_path="${res_path#res://}"
                local full_path="$project/$disk_path"
                if [[ ! -e "$full_path" ]]; then
                    printf '; DISABLED (missing file): %s\n' "$line" >> "$tmp_file"
                    changed=true
                    continue
                else
                    remaining_entries=$((remaining_entries + 1))
                fi
            fi

            printf '%s\n' "$line" >> "$tmp_file"
        done < "$ext_file"

        if $changed && [[ $remaining_entries -eq 0 ]]; then
            # ALL entries missing -> fully disable
            rm -f "$tmp_file"
            local uid_file="${ext_file}.uid"
            if [[ -f "$uid_file" ]]; then
                cp "$uid_file" "${uid_file}.bak" 2>/dev/null || true
                rm -f "$uid_file"
            fi
            rm -f "$ext_file"
            MODIFIED_GDEXT_FILES+=("$ext_file")
            ok "Disabled: $addon_name/$base_name (no libraries found on disk)"
        elif $changed; then
            mv "$tmp_file" "$ext_file"
            MODIFIED_GDEXT_FILES+=("$ext_file")
            ok "Filtered: $addon_name/$base_name (kept $remaining_entries, removed missing)"
        else
            rm -f "$tmp_file"
            rm -f "$bak_path"
            ok "OK: $addon_name/$base_name (all libraries present)"
        fi
    done < <(find "$addons_dir" -name '*.gdextension' -not -name '*.bak' -print0 2>/dev/null || true)
}

restore_gdextensions() {
    local project="$1"
    for orig_path in "${MODIFIED_GDEXT_FILES[@]}"; do
        local bak_path="${orig_path}.bak"
        local uid_bak="${orig_path}.uid.bak"
        local uid_path="${orig_path}.uid"

        if [[ -f "$bak_path" ]]; then
            mv "$bak_path" "$orig_path" 2>/dev/null || \
                warn "Could not restore $(basename "$orig_path")"
        fi
        if [[ -f "$uid_bak" ]]; then
            mv "$uid_bak" "$uid_path" 2>/dev/null || \
                warn "Could not restore UID for $(basename "$orig_path")"
        fi
    done

    # Delete uid_cache.bin so Godot regenerates cleanly on next launch
    local uid_cache="$project/.godot/uid_cache.bin"
    rm -f "$uid_cache" 2>/dev/null || true

    MODIFIED_GDEXT_FILES=()
}

# ─── Godot Export ──────────────────────────────────────────────────────────────

invoke_godot_export() {
    local godot="$1" project="$2" preset="$3" output="$4"
    printf "    Exporting '%s' → %s\n" "$preset" "$output"

    local out_dir
    out_dir="$(dirname "$output")"
    mkdir -p "$out_dir"

    local stdout_log="$out_dir/export_stdout.log"
    local stderr_log="$out_dir/export_stderr.log"

    set +e
    "$godot" --headless --path "$project" --export-release "$preset" "$output" \
        >"$stdout_log" 2>"$stderr_log"
    local exit_code=$?
    set -e

    if [[ $exit_code -eq 0 ]] && [[ -e "$output" ]]; then
        if [[ -d "$output" ]]; then
            ok "$(basename "$output")  (app bundle)"
        else
            local size_mb
            size_mb="$(du -m "$output" | cut -f1)"
            ok "$(basename "$output")  (${size_mb} MB)"
        fi
        rm -f "$stdout_log" "$stderr_log"
        return 0
    fi

    fail "Export failed (exit code $exit_code)"
    if [[ -f "$stderr_log" ]]; then
        head -8 "$stderr_log" | while IFS= read -r line; do
            fail "    $line"
        done
    fi
    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
printf "${C_CYAN}╔══════════════════════════════════════════════════════════╗${C_RESET}\n"
printf "${C_CYAN}║         GONODES Template Builder                        ║${C_RESET}\n"
printf "${C_CYAN}║         Builds Player/Editor binaries for Quick Build   ║${C_RESET}\n"
printf "${C_CYAN}╚══════════════════════════════════════════════════════════╝${C_RESET}\n"

# ── Resolve project path ──────────────────────────────────────────────────────

if [[ -z "$PROJECT_PATH" ]]; then
    PROJECT_PATH="$(dirname "$SCRIPT_DIR")"  # scripts/ → project root
fi
PROJECT_GODOT="$PROJECT_PATH/project.godot"

if [[ ! -f "$PROJECT_GODOT" ]]; then
    fail "project.godot not found in: $PROJECT_PATH"
    fail "Use --project to specify the GONODES project root."
    exit 1
fi
ok "Project: $PROJECT_PATH"

# ── RestoreOnly shortcut ──────────────────────────────────────────────────────

if $RESTORE_ONLY; then
    step "Restoring project.godot main scene..."
    current="$(get_main_scene "$PROJECT_GODOT")"
    if [[ "$current" == "$EDITOR_MAIN_SCENE" ]]; then
        ok "Already set to Editor scene — nothing to restore."
    elif set_main_scene "$PROJECT_GODOT" "$EDITOR_MAIN_SCENE"; then
        ok "Restored: $EDITOR_MAIN_SCENE"
    else
        fail "Restore failed."
        exit 1
    fi
    exit 0
fi

# ── Find Godot ────────────────────────────────────────────────────────────────

GODOT="$(find_godot)"
if [[ -z "$GODOT" ]]; then
    fail "Godot editor binary not found."
    fail "Use --godot /path/to/godot"
    exit 1
fi
ok "Godot:   $GODOT"
check_godot_version "$GODOT"

# ── Resolve settings ─────────────────────────────────────────────────────────

if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$PROJECT_PATH/templates"
fi

# -- BuildAll shortcut ----------------------------------------------------------

if $BUILD_ALL; then
    PLATFORMS="all"
    INCLUDE_EDITOR=true
    ok "BuildAll: building Player + Editor for all platforms"
fi

# Expand "all"
if [[ "$PLATFORMS" == "all" ]]; then
    PLATFORMS="windows_x86_64,windows_arm64,linux_x86_64,linux_arm64,macos,android,ios,web"
fi

# Split on commas
IFS=',' read -ra PLATFORM_LIST <<< "$PLATFORMS"

# Validate
ALL_VALID="windows_x86_64 windows_arm64 linux_x86_64 linux_arm64 macos android ios web"
for plat in "${PLATFORM_LIST[@]}"; do
    if ! echo "$ALL_VALID" | grep -qw "$plat"; then
        fail "Unknown platform: $plat"
        fail "Valid: $ALL_VALID"
        exit 1
    fi
done

ok "Output:  $OUTPUT_DIR"
ok "Targets: ${PLATFORM_LIST[*]}"
if $INCLUDE_EDITOR; then ok "Include Editor: yes"; fi
ok "GDExtensions:  $GDEXT_MODE"

# ── Clean ─────────────────────────────────────────────────────────────────────

if $CLEAN && [[ -d "$OUTPUT_DIR" ]]; then
    step "Cleaning existing templates..."
    rm -rf "$OUTPUT_DIR"
    ok "Removed $OUTPUT_DIR"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Pre-Build Checks
# ═══════════════════════════════════════════════════════════════════════════════

step "Pre-build cleanup..."
remove_temp_files "$PROJECT_PATH"

# -- GDExtension handling ------------------------------------------------------

if [[ "$GDEXT_MODE" == "all" ]]; then
    step "Checking GDExtension libraries (all included)..."
    check_gdextensions "$PROJECT_PATH" "${PLATFORM_LIST[@]}"
else
    step "Preparing GDExtensions (mode: $GDEXT_MODE)..."
    disable_gdextensions "$PROJECT_PATH" "$GDEXT_MODE"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Build Loop
# ═══════════════════════════════════════════════════════════════════════════════

SUCCESS_COUNT=0
FAIL_COUNT=0

# Trap: always restore main scene on exit (normal, error, or signal)
cleanup() {
    # Restore GDExtension files first
    if [[ ${#MODIFIED_GDEXT_FILES[@]} -gt 0 ]]; then
        step "Restoring GDExtension files..."
        restore_gdextensions "$PROJECT_PATH"
        ok "GDExtension files restored."
    fi

    local current
    current="$(get_main_scene "$PROJECT_GODOT")"
    if [[ "$current" != "$EDITOR_MAIN_SCENE" ]]; then
        warn "Restoring main scene after interruption..."
        set_main_scene "$PROJECT_GODOT" "$EDITOR_MAIN_SCENE" || true
    fi
}
trap cleanup EXIT

# ── Phase 1: Player exports ──────────────────────────────────────────────────

step "Switching main scene → Player ($PLAYER_MAIN_SCENE) ..."
if ! set_main_scene "$PROJECT_GODOT" "$PLAYER_MAIN_SCENE"; then
    fail "Could not swap main scene — aborting."
    exit 1
fi
ok "project.godot updated."

for plat in "${PLATFORM_LIST[@]}"; do
    ext="$(platform_ext "$plat")"
    preset="$(player_preset_name "$plat")"
    plat_dir="$OUTPUT_DIR/$plat"
    player_out="$plat_dir/GONODESPlayer${ext}"

    step "Player · $plat"
    if invoke_godot_export "$GODOT" "$PROJECT_PATH" "$preset" "$player_out"; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        warn "Preset '$preset' may not exist in export_presets.cfg."
        warn "Open Godot → Project → Export → Add... and create it."
    fi
done

# ── Phase 2: Editor exports ──────────────────────────────────────────────────

step "Restoring main scene → Editor ($EDITOR_MAIN_SCENE) ..."
if ! set_main_scene "$PROJECT_GODOT" "$EDITOR_MAIN_SCENE"; then
    fail "Could not restore main scene — run with --restore-only to fix."
    exit 1
fi
ok "project.godot restored."

if $INCLUDE_EDITOR; then
    for plat in "${PLATFORM_LIST[@]}"; do
        preset="$(editor_preset_name "$plat")"
        # Skip platforms that don't have editor builds (mobile/web)
        if [[ -z "$preset" ]]; then
            ok "Skipping Editor for $plat (no editor preset)"
            continue
        fi
        ext="$(platform_ext "$plat")"
        plat_dir="$OUTPUT_DIR/$plat"
        editor_out="$plat_dir/GONODES${ext}"

        step "Editor · $plat"
        if invoke_godot_export "$GODOT" "$PROJECT_PATH" "$preset" "$editor_out"; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    done
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
printf "${C_CYAN}╔══════════════════════════════════════════════════════════╗${C_RESET}\n"
printf "${C_CYAN}║  Build Complete                                          ║${C_RESET}\n"
printf "${C_CYAN}╚══════════════════════════════════════════════════════════╝${C_RESET}\n"
echo ""
printf "  ${C_GREEN}Successful: %d${C_RESET}\n" "$SUCCESS_COUNT"
if [[ $FAIL_COUNT -gt 0 ]]; then
    printf "  ${C_RED}Failed:     %d${C_RESET}\n" "$FAIL_COUNT"
else
    printf "  ${C_GREEN}Failed:     0${C_RESET}\n"
fi
printf "  Output:     %s\n" "$OUTPUT_DIR"
echo ""

if [[ $SUCCESS_COUNT -gt 0 ]]; then
    printf "  ${C_GRAY}Quick Build in the editor will find these templates${C_RESET}\n"
    printf "  ${C_GRAY}automatically for the built platforms.${C_RESET}\n"
    echo ""
fi

exit "$FAIL_COUNT"
