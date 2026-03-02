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
INCLUDE_EDITOR=false
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
        *) return 1 ;;
    esac
}

platform_ext() {
    case "$1" in
        windows_x86_64|windows_arm64) echo ".exe" ;;
        macos)                        echo ".app" ;;
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
  --include-editor     Also build Editor binaries
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
        --include-editor) INCLUDE_EDITOR=true; shift ;;
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

# Expand "all"
if [[ "$PLATFORMS" == "all" ]]; then
    PLATFORMS="windows_x86_64,windows_arm64,linux_x86_64,linux_arm64,macos"
fi

# Split on commas
IFS=',' read -ra PLATFORM_LIST <<< "$PLATFORMS"

# Validate
ALL_VALID="windows_x86_64 windows_arm64 linux_x86_64 linux_arm64 macos"
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

# ── Clean ─────────────────────────────────────────────────────────────────────

if $CLEAN && [[ -d "$OUTPUT_DIR" ]]; then
    step "Cleaning existing templates..."
    rm -rf "$OUTPUT_DIR"
    ok "Removed $OUTPUT_DIR"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Build Loop
# ═══════════════════════════════════════════════════════════════════════════════

SUCCESS_COUNT=0
FAIL_COUNT=0

# Trap: always restore main scene on exit (normal, error, or signal)
cleanup() {
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
        ext="$(platform_ext "$plat")"
        preset="$(editor_preset_name "$plat")"
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
