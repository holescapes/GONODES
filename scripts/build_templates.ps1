#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Builds GONODES Player (and optionally Editor) binaries for desktop platforms.

.DESCRIPTION
    Uses Godot's command-line export system to produce Player and Editor
    binaries for Windows, macOS, and Linux across x86_64 and ARM64.

    The resulting binaries are placed in the templates/ folder at the
    project root, organized by platform:

        templates/
          windows_x86_64/   GONODESPlayer.exe + .pck
          windows_arm64/    GONODESPlayer.exe + .pck
          linux_x86_64/     GONODESPlayer     + .pck
          linux_arm64/      GONODESPlayer     + .pck
          macos/            GONODESPlayer.app/

    IMPORTANT -- Main-Scene Swap
    ----------------------------
    Godot export always uses project.godot's run/main_scene.  The Editor main
    scene is gn_editor.tscn; the Player needs player_main.tscn.  This script
    temporarily rewrites project.godot before Player exports and restores it
    immediately after.  If the script is interrupted, run it again with
    -RestoreOnly to fix project.godot.

    PREREQUISITES:
    - Godot 4.6.x editor binary (with export templates installed)
    - Export templates matching your Godot version:
          Editor > Manage Export Templates > Download for Current Version
    - Export presets defined in export_presets.cfg for each target platform
      (the project ships with presets for all 5 desktop targets)

.PARAMETER GodotPath
    Path to the Godot editor executable.
    Default: searches PATH, then common install locations.

.PARAMETER ProjectPath
    Path to the GONODES project root (containing project.godot).
    Default: parent directory of this script's location.

.PARAMETER OutputDir
    Where to write the built templates.
    Default: ProjectPath/templates

.PARAMETER Platforms
    Which platforms to build.  Comma-separated list of:
      windows_x86_64, windows_arm64, linux_x86_64, linux_arm64, macos
    Default: auto-detected from host OS/architecture
    Use "all" to build everything.

.PARAMETER IncludeEditor
    Also build the Editor binary for each platform (uses the editor main scene).
    Default: false (Player only)

.PARAMETER Clean
    Remove existing templates/ folder before building.

.PARAMETER RestoreOnly
    Only restore project.godot to the Editor main scene (recovery after
    an interrupted build).

.EXAMPLE
    .\build_templates.ps1 -GodotPath "C:\Godot\Godot_v4.6.1-stable_win64_console.exe"

.EXAMPLE
    .\build_templates.ps1 -Platforms "all"

.EXAMPLE
    .\build_templates.ps1 -Platforms "windows_x86_64,linux_x86_64" -Clean

.EXAMPLE
    .\build_templates.ps1 -RestoreOnly

.NOTES
    GONODES Build System
    Godot Version: 4.6.1 stable (update export templates when upgrading Godot)
#>

[CmdletBinding()]
param(
    [string]$GodotPath = "",
    [string]$ProjectPath = "",
    [string]$OutputDir = "",
    [string[]]$Platforms = @(),
    [switch]$IncludeEditor,
    [switch]$Clean,
    [switch]$RestoreOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Constants ----------------------------------------------------------------

$SCRIPT_DIR             = Split-Path -Parent $MyInvocation.MyCommand.Path
$GODOT_VERSION_EXPECTED = "4.6"
$EDITOR_MAIN_SCENE      = 'res://scenes/gn_editor.tscn'
$PLAYER_MAIN_SCENE      = 'res://scenes/player_main.tscn'

# Platform -> export-preset-name mapping.
# Names MUST match the [preset.N] entries in export_presets.cfg.
$PLATFORM_PRESETS = @{
    "windows_x86_64" = @{ player = "Player Windows x86_64";  editor = "Editor Windows x86_64";  ext = ".exe" }
    "windows_arm64"  = @{ player = "Player Windows ARM64";   editor = "Editor Windows ARM64";   ext = ".exe" }
    "linux_x86_64"   = @{ player = "Player Linux x86_64";    editor = "Editor Linux x86_64";    ext = "" }
    "linux_arm64"    = @{ player = "Player Linux ARM64";     editor = "Editor Linux ARM64";     ext = "" }
    "macos"          = @{ player = "Player macOS";           editor = "Editor macOS";           ext = ".app" }
}

# --- Host Platform Detection --------------------------------------------------

function Get-HostPlatform {
    if ($IsWindows -or ($env:OS -eq "Windows_NT")) {
        if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq "Arm64") {
            return "windows_arm64"
        }
        return "windows_x86_64"
    }
    if ($IsMacOS) { return "macos" }
    if ($IsLinux) {
        $arch = uname -m 2>$null
        if ($arch -match "aarch64|arm64") { return "linux_arm64" }
        return "linux_x86_64"
    }
    return "windows_x86_64"  # fallback
}

# --- Helpers -------------------------------------------------------------------

function Write-Step([string]$msg)  { Write-Host "`n--- $msg" -ForegroundColor Cyan   }
function Write-Ok  ([string]$msg)  { Write-Host "  [OK] $msg"   -ForegroundColor Green  }
function Write-Warn([string]$msg)  { Write-Host "  [!!] $msg"   -ForegroundColor Yellow }
function Write-Fail([string]$msg)  { Write-Host "  [XX] $msg"   -ForegroundColor Red    }

# --- Godot Discovery ----------------------------------------------------------

function Find-Godot {
    if ($GodotPath -and (Test-Path $GodotPath)) { return (Resolve-Path $GodotPath).Path }

    # Search PATH
    foreach ($name in @("godot", "godot.exe", "godot4", "Godot")) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }

    # Platform-specific common locations
    if ($IsWindows -or ($env:OS -eq "Windows_NT")) {
        $winPaths = @(
            "$env:LOCALAPPDATA\Godot\godot.exe",
            "C:\Godot\Godot_v4.6.1-stable_win64.exe",
            "C:\Godot\Godot_v4.6.1-stable_win64_console.exe"
        )
        foreach ($p in $winPaths) {
            if (Test-Path $p) { return $p }
        }
    }
    if ($IsMacOS) {
        $macPath = "/Applications/Godot.app/Contents/MacOS/Godot"
        if (Test-Path $macPath) { return $macPath }
    }
    if ($IsLinux) {
        foreach ($p in @("/usr/bin/godot", "/usr/local/bin/godot", "$HOME/.local/bin/godot")) {
            if (Test-Path $p) { return $p }
        }
    }
    return ""
}

function Test-GodotVersion([string]$godot) {
    try {
        $ver = (& $godot --version 2>&1) | Select-Object -First 1
        if ($ver -match "^$GODOT_VERSION_EXPECTED") {
            Write-Ok "Godot version: $ver"
            return $true
        }
        Write-Warn "Expected Godot $GODOT_VERSION_EXPECTED.x, got: $ver"
        Write-Warn "Export templates may not match -- proceed with caution."
        return $true  # warn-only, don't block
    } catch {
        Write-Fail "Could not determine Godot version: $_"
        return $false
    }
}

# --- Main-Scene Swap ----------------------------------------------------------

function Set-MainScene([string]$projectGodot, [string]$scenePath) {
    $content = Get-Content $projectGodot -Raw -Encoding UTF8
    $pattern = 'run/main_scene="[^"]*"'
    $replacement = "run/main_scene=`"$scenePath`""

    if ($content -match $pattern) {
        $newContent = $content -replace $pattern, $replacement
        [System.IO.File]::WriteAllText($projectGodot, $newContent,
            [System.Text.Encoding]::UTF8)
        return $true
    }
    Write-Fail "Could not find run/main_scene in project.godot"
    return $false
}

function Get-CurrentMainScene([string]$projectGodot) {
    $content = Get-Content $projectGodot -Raw -Encoding UTF8
    if ($content -match 'run/main_scene="([^"]*)"') {
        return $Matches[1]
    }
    return ""
}

# --- Godot Export --------------------------------------------------------------

function Invoke-GodotExport([string]$godot, [string]$project, [string]$presetName, [string]$outputPath) {
    Write-Host "    Exporting '$presetName' -> $outputPath"

    $outDir = Split-Path -Parent $outputPath
    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    $exportArgs = @(
        "--headless",
        "--path", "`"$project`"",
        "--export-release", "`"$presetName`"",
        "`"$outputPath`""
    )

    $stdoutLog = Join-Path $outDir "export_stdout.log"
    $stderrLog = Join-Path $outDir "export_stderr.log"

    $proc = Start-Process -FilePath $godot -ArgumentList $exportArgs `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $stdoutLog `
        -RedirectStandardError  $stderrLog

    # macOS exports produce a .app folder, others a file
    $exists = (Test-Path $outputPath)

    if ($proc.ExitCode -eq 0 -and $exists) {
        if (Test-Path $outputPath -PathType Container) {
            Write-Ok "$($outputPath | Split-Path -Leaf)  (app bundle)"
        } else {
            $sizeMB = [math]::Round((Get-Item $outputPath).Length / 1MB, 1)
            Write-Ok "$($outputPath | Split-Path -Leaf)  ($sizeMB MB)"
        }
        Remove-Item $stdoutLog -ErrorAction SilentlyContinue
        Remove-Item $stderrLog -ErrorAction SilentlyContinue
        return $true
    }

    Write-Fail "Export failed (exit code $($proc.ExitCode))"
    if (Test-Path $stderrLog) {
        $err = Get-Content $stderrLog -ErrorAction SilentlyContinue | Select-Object -First 8
        if ($err) { $err | ForEach-Object { Write-Fail "    $_" } }
    }
    return $false
}

# ==============================================================================
# Main
# ==============================================================================

Write-Host ""
Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host "  GONODES Template Builder                                  " -ForegroundColor Cyan
Write-Host "  Builds Player/Editor binaries for Quick Build             " -ForegroundColor Cyan
Write-Host "===========================================================" -ForegroundColor Cyan

# -- Resolve project path ------------------------------------------------------

if (-not $ProjectPath) {
    $ProjectPath = Split-Path -Parent $SCRIPT_DIR  # scripts/ -> project root
}
$projectGodot = Join-Path $ProjectPath "project.godot"

if (-not (Test-Path $projectGodot)) {
    Write-Fail "project.godot not found in: $ProjectPath"
    Write-Fail "Use -ProjectPath to specify the GONODES project root."
    exit 1
}
Write-Ok "Project: $ProjectPath"

# -- RestoreOnly shortcut ------------------------------------------------------

if ($RestoreOnly) {
    Write-Step "Restoring project.godot main scene..."
    $current = Get-CurrentMainScene $projectGodot
    if ($current -eq $EDITOR_MAIN_SCENE) {
        Write-Ok "Already set to Editor scene -- nothing to restore."
    } elseif (Set-MainScene $projectGodot $EDITOR_MAIN_SCENE) {
        Write-Ok "Restored: $EDITOR_MAIN_SCENE"
    } else {
        Write-Fail "Restore failed."
        exit 1
    }
    exit 0
}

# -- Find Godot ----------------------------------------------------------------

$godot = Find-Godot
if (-not $godot) {
    Write-Fail "Godot editor binary not found."
    Write-Fail 'Use -GodotPath, e.g.:  .\build_templates.ps1 -GodotPath "C:\path\to\godot.exe"'
    exit 1
}
Write-Ok "Godot:   $godot"
if (-not (Test-GodotVersion $godot)) { exit 1 }

# -- Resolve settings ----------------------------------------------------------

if (-not $OutputDir) { $OutputDir = Join-Path $ProjectPath "templates" }

# Auto-detect host platform if none specified
if ($Platforms.Count -eq 0) {
    $Platforms = @(Get-HostPlatform)
    Write-Ok "Auto-detected host platform: $($Platforms[0])"
}

if ($Platforms -contains "all") {
    $Platforms = @("windows_x86_64", "windows_arm64", "linux_x86_64", "linux_arm64", "macos")
}
foreach ($plat in $Platforms) {
    if (-not $PLATFORM_PRESETS.ContainsKey($plat)) {
        Write-Fail "Unknown platform: $plat  -- valid: $($PLATFORM_PRESETS.Keys -join ', ')"
        exit 1
    }
}

Write-Ok "Output:  $OutputDir"
Write-Ok "Targets: $($Platforms -join ', ')"
if ($IncludeEditor) { Write-Ok "Include Editor: yes" }

# -- Clean ---------------------------------------------------------------------

if ($Clean -and (Test-Path $OutputDir)) {
    Write-Step "Cleaning existing templates..."
    Remove-Item -Recurse -Force $OutputDir
    Write-Ok "Removed $OutputDir"
}

# ==============================================================================
# Build Loop
# ==============================================================================

$successCount = 0
$failCount    = 0
$originalScene = Get-CurrentMainScene $projectGodot

try {
    # -- Phase 1: Player exports (main scene -> player_main.tscn) --------------

    Write-Step "Switching main scene -> Player ($PLAYER_MAIN_SCENE) ..."
    if (-not (Set-MainScene $projectGodot $PLAYER_MAIN_SCENE)) {
        Write-Fail "Could not swap main scene -- aborting."
        exit 1
    }
    Write-Ok "project.godot updated."

    foreach ($plat in $Platforms) {
        $info     = $PLATFORM_PRESETS[$plat]
        $platDir  = Join-Path $OutputDir $plat
        $playerFn = "GONODESPlayer$($info.ext)"
        $playerOut = Join-Path $platDir $playerFn

        Write-Step "Player - $plat"
        if (Invoke-GodotExport $godot $ProjectPath $info.player $playerOut) {
            $successCount++
        } else {
            $failCount++
            Write-Warn "Preset '$($info.player)' may not exist in export_presets.cfg."
            Write-Warn "Open Godot -> Project -> Export -> Add... and create it."
        }
    }

    # -- Phase 2: Editor exports (restore main scene first) --------------------

    Write-Step "Restoring main scene -> Editor ($EDITOR_MAIN_SCENE) ..."
    if (-not (Set-MainScene $projectGodot $EDITOR_MAIN_SCENE)) {
        Write-Fail "Could not restore main scene -- run with -RestoreOnly to fix."
        exit 1
    }
    Write-Ok "project.godot restored."

    if ($IncludeEditor) {
        foreach ($plat in $Platforms) {
            $info      = $PLATFORM_PRESETS[$plat]
            $platDir   = Join-Path $OutputDir $plat
            $editorFn  = "GONODES$($info.ext)"
            $editorOut = Join-Path $platDir $editorFn

            Write-Step "Editor - $plat"
            if (Invoke-GodotExport $godot $ProjectPath $info.editor $editorOut) {
                $successCount++
            } else {
                $failCount++
            }
        }
    }
}
catch {
    Write-Fail "Unexpected error: $_"
    $failCount++
}
finally {
    # Always restore the Editor main scene, even after errors / Ctrl-C.
    $current = Get-CurrentMainScene $projectGodot
    if ($current -ne $EDITOR_MAIN_SCENE) {
        Write-Warn "Restoring main scene after interruption..."
        Set-MainScene $projectGodot $EDITOR_MAIN_SCENE | Out-Null
    }
}

# ==============================================================================
# Summary
# ==============================================================================

Write-Host ""
Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host "  Build Complete                                            " -ForegroundColor Cyan
Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Successful: $successCount" -ForegroundColor Green
if ($failCount -gt 0) {
    Write-Host "  Failed:     $failCount" -ForegroundColor Red
} else {
    Write-Host "  Failed:     0" -ForegroundColor Green
}
Write-Host "  Output:     $OutputDir"
Write-Host ""

if ($successCount -gt 0) {
    Write-Host "  Quick Build in the editor will find these templates" -ForegroundColor Gray
    Write-Host "  automatically for the built platforms." -ForegroundColor Gray
    Write-Host ""
}

exit $failCount
