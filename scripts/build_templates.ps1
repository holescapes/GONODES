#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Builds GONODES Player (and optionally Editor) binaries for all platforms.

.DESCRIPTION
    Uses Godot's command-line export system to produce Player and Editor
    binaries for Windows, macOS, Linux, Android, iOS, and Web.

    The resulting binaries are placed in the templates/ folder at the
    project root, organized by platform:

        templates/
          windows_x86_64/   GONODESPlayer.exe + .pck
          windows_arm64/    GONODESPlayer.exe + .pck
          linux_x86_64/     GONODESPlayer     + .pck
          linux_arm64/      GONODESPlayer     + .pck
          macos/            GONODESPlayer.app/
          android/          GONODESPlayer.apk
          ios/              GONODESPlayer.ipa
          web/              GONODESPlayer.html + .wasm + .pck + .js

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
      windows_x86_64, windows_arm64, linux_x86_64, linux_arm64, macos,
      android, ios, web
    Default: auto-detected from host OS/architecture (desktop only)
    Use "all" to build everything including mobile + web.

.PARAMETER BuildAll
    Convenience shortcut: build both Player and Editor for ALL platforms.
    Equivalent to -Platforms "all" -IncludeEditor.
    Default: false

.PARAMETER IncludeEditor
    Also build the Editor binary for each platform (uses the editor main scene).
    Default: false (Player only)

.PARAMETER GDExtensions
    Controls how third-party GDExtension native libraries are handled.
    Accepted values:
      auto  (default)  Smart filter: keeps library entries whose files exist
            on disk, removes entries for missing files.  Each platform
            export also leaves out any extension folder that has no
            library for that OS and architecture, so the player does not
            log "library not found" for binaries it cannot load.
            The base GONODES project always builds cleanly in this mode.
      all   Include everything as-is.  Exports will fail if a referenced
            library is missing for the target platform.
      none  Disable ALL GDExtension files.  The project builds with zero
            native extension dependencies.
      name,name,...  Comma-separated addon folder names (under addons/).
            Named addons use smart filtering; everything else is disabled.
    Examples:
      -GDExtensions "auto"           # default smart filter
      -GDExtensions "all"            # include everything
      -GDExtensions "none"           # disable all extensions
      -GDExtensions "ffmpeg"         # include only ffmpeg
      -GDExtensions "ffmpeg,openxr"  # include ffmpeg and openxr

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
    .\build_templates.ps1 -BuildAll

.EXAMPLE
    .\build_templates.ps1 -BuildAll -Clean

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
    [switch]$BuildAll,
    [switch]$IncludeEditor,
    [string]$GDExtensions = "auto",
    [switch]$Clean,
    [switch]$RestoreOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- PowerShell 5.1 compatibility shims --------------------------------------
# $IsWindows, $IsMacOS, $IsLinux are automatic in PS 7+ but absent in 5.1.
if (-not (Get-Variable -Name IsWindows -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:IsWindows = ($env:OS -eq "Windows_NT")
}
if (-not (Get-Variable -Name IsMacOS -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:IsMacOS = $false
}
if (-not (Get-Variable -Name IsLinux -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:IsLinux = $false
}

# --- Constants ----------------------------------------------------------------

$SCRIPT_DIR             = Split-Path -Parent $MyInvocation.MyCommand.Path
# Read expected major.minor from versions.env (fallback 4.7)
$GODOT_VERSION_EXPECTED = "4.7"
$versionsEnv = Join-Path (Split-Path -Parent $SCRIPT_DIR) "versions.env"
if (Test-Path $versionsEnv) {
    foreach ($line in Get-Content $versionsEnv) {
        if ($line -match '^\s*GODOT_VERSION\s*=\s*([0-9]+)\.([0-9]+)') {
            $GODOT_VERSION_EXPECTED = "$($Matches[1]).$($Matches[2])"
            break
        }
    }
}
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
    "android"        = @{ player = "Player Android ARM64";   editor = "";                       ext = ".apk" }
    "ios"            = @{ player = "Player iOS ARM64";       editor = "";                       ext = ".ipa" }
    "web"            = @{ player = "Player Web";             editor = "";                       ext = ".html" }
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

    # Check GONODES_GODOT environment variable
    if ($env:GONODES_GODOT -and (Test-Path $env:GONODES_GODOT)) {
        return (Resolve-Path $env:GONODES_GODOT).Path
    }

    # Search PATH
    foreach ($name in @("godot", "godot.exe", "godot4", "Godot")) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }

    # Platform-specific common locations
    if ($IsWindows -or ($env:OS -eq "Windows_NT")) {
        $winPaths = @(
            "$env:LOCALAPPDATA\Godot\godot.exe",
            "$env:USERPROFILE\OneDrive\Documents\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe",
            "$env:USERPROFILE\OneDrive\Documents\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe",
            "C:\Godot\Godot_v4.7.2-stable_win64_console.exe",
            "C:\Godot\Godot_v4.7.2-stable_win64.exe",
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
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($projectGodot, $newContent, $utf8NoBom)
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

# --- Pre-Build Hygiene ---------------------------------------------------------

function Remove-TempFiles([string]$project) {
    # Windows antivirus, file indexers, and Godot itself can leave ~*.TMP files
    # next to DLLs.  These confuse Godot's export file-copy step because it
    # sees them in directory listings but can't open them.  Clean them up.
    $addonsDir = Join-Path $project "addons"
    if (-not (Test-Path $addonsDir)) { return }

    $tempFiles = Get-ChildItem $addonsDir -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^~' -or $_.Name -match '\.TMP$' }

    foreach ($f in $tempFiles) {
        try {
            Remove-Item $f.FullName -Force -ErrorAction Stop
            Write-Ok "Cleaned temp file: $($f.Name)"
        } catch {
            Write-Warn "Could not remove temp file (may be locked): $($f.Name)"
            Write-Warn "Close Godot and any antivirus file locks, then retry."
        }
    }
}

function Test-GDExtensions([string]$project, [string[]]$platforms) {
    # Scan all .gdextension files and check whether the libraries they
    # reference for each target platform actually exist on disk.  Godot's
    # export will fail if a referenced library is missing.  We warn early
    # so the user knows which platforms may have issues.
    $gdextFiles = Get-ChildItem (Join-Path $project "addons") -Recurse -Filter "*.gdextension" -ErrorAction SilentlyContinue
    if (-not $gdextFiles) { return }

    # Map our platform names to .gdextension [libraries] key prefixes
    $platPrefixes = @{
        "windows_x86_64" = @("windows.release.x86_64", "windows.debug.x86_64")
        "windows_arm64"  = @("windows.release.arm64",  "windows.debug.arm64")
        "linux_x86_64"   = @("linux.release.x86_64",   "linux.debug.x86_64")
        "linux_arm64"    = @("linux.release.arm64",    "linux.debug.arm64")
        "macos"          = @("macos.release",          "macos.debug")
    }

    foreach ($extFile in $gdextFiles) {
        $extName = $extFile.Directory.Name + "/" + $extFile.Name
        $content = Get-Content $extFile.FullName -Raw -Encoding UTF8

        foreach ($plat in $platforms) {
            $prefixes = $platPrefixes[$plat]
            if (-not $prefixes) { continue }

            foreach ($prefix in $prefixes) {
                # Match: prefix = "res://path/to/lib.dll"
                if ($content -match "(?m)^\s*$([regex]::Escape($prefix))\s*=\s*`"(res://[^`"]+)`"") {
                    $resPath = $Matches[1]
                    $diskPath = $resPath -replace '^res://', ''
                    $fullPath = Join-Path $project $diskPath
                    if (-not (Test-Path $fullPath)) {
                        Write-Warn "GDExtension '$extName' references missing library for $plat"
                        Write-Warn "  Expected: $diskPath"
                        Write-Warn "  Export for $plat may fail -- the extension will not be included."
                    }
                }
            }
        }
    }
}

# --- GDExtension Disable / Restore --------------------------------------------
#
# Modes (controlled by -GDExtensions):
#
#   auto  (default)
#       For each .gdextension, comment out [libraries] entries whose referenced
#       files are missing on disk.
#       - If SOME entries remain -> Godot loads the extension for those
#         platforms and silently skips the removed ones.
#       - If ALL entries are missing -> the file is deleted entirely so Godot
#         does not attempt to load it (avoids "No library found" exit 1).
#
#   none
#       Delete every .gdextension (and its .uid) so Godot never sees them.
#
#   <name,name,...>
#       Named addons (matched by their folder under addons/) get 'auto'
#       treatment; everything else is deleted ('none').
#
# In all cases:
#   - Originals are backed up as .gdextension.bak / .uid.bak.
#   - .godot/uid_cache.bin is deleted so Godot does not choke on stale UIDs.
#   - Restore-GDExtensions reverses everything when the build finishes.

$script:ModifiedGDExtFiles = @()

function Disable-GDExtensions([string]$project, [string]$mode) {
    $addonsDir = Join-Path $project "addons"
    if (-not (Test-Path $addonsDir)) { return }

    $gdextFiles = Get-ChildItem $addonsDir -Recurse -Filter "*.gdextension" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike '*.bak' }
    if (-not $gdextFiles) {
        Write-Ok "No GDExtension files found -- nothing to do."
        return
    }

    # Parse mode
    $filterMode = $mode.ToLower().Trim()
    if ($filterMode -eq 'all') { return }  # nothing to change

    $isNone = ($filterMode -eq 'none')
    $isAuto = ($filterMode -eq 'auto')
    $allowedAddons = @()
    if (-not $isNone -and -not $isAuto) {
        $allowedAddons = $filterMode -split ',' |
            ForEach-Object { $_.Trim().ToLower() } |
            Where-Object { $_ }
    }

    # Delete uid_cache.bin so stale UIDs never cause errors
    $uidCache = Join-Path (Join-Path $project ".godot") "uid_cache.bin"
    if (Test-Path $uidCache) {
        Remove-Item $uidCache -Force -ErrorAction SilentlyContinue
        Write-Ok "Cleared UID cache (will regenerate)"
    }

    foreach ($f in $gdextFiles) {
        # Addon name = first path component under addons/
        $addonsLen = (Join-Path $project "addons").Length + 1
        $relPath   = $f.FullName.Substring($addonsLen)
        $addonName = ($relPath -split '[\\/]')[0].ToLower()

        # Decide: fully disable or smart-filter?
        $shouldDisable = $false
        if ($isNone) {
            $shouldDisable = $true
        } elseif ($allowedAddons.Count -gt 0 -and -not ($allowedAddons -contains $addonName)) {
            $shouldDisable = $true
        }

        # Backup original
        $bakPath = $f.FullName + ".bak"
        try {
            Copy-Item -Path $f.FullName -Destination $bakPath -Force -ErrorAction Stop
        } catch {
            Write-Warn "Could not backup $($f.Name): $_"
            continue
        }

        if ($shouldDisable) {
            # --- Fully disable: delete .gdextension + .uid ---
            $uidFile = $f.FullName + ".uid"
            if (Test-Path $uidFile) {
                Copy-Item $uidFile "$uidFile.bak" -Force -ErrorAction SilentlyContinue
                Remove-Item $uidFile -Force -ErrorAction SilentlyContinue
            }
            Remove-Item $f.FullName -Force -ErrorAction Stop
            $script:ModifiedGDExtFiles += $f.FullName
            Write-Ok "Disabled: $addonName/$($f.Name) (removed during build)"
            continue
        }

        # --- Smart filter: comment out missing library entries ---
        $lines = Get-Content $f.FullName -Encoding UTF8
        $inLibraries      = $false
        $changed           = $false
        $remainingEntries  = 0
        $newLines          = @()

        foreach ($line in $lines) {
            if ($line -match '^\s*\[') {
                $inLibraries = ($line -match '^\s*\[libraries\]')
            }

            if ($inLibraries -and $line -match '^\s*\S+\s*=\s*"(res://[^"]+)"') {
                $resPath  = $Matches[1]
                $diskPath = $resPath -replace '^res://', ''
                $fullPath = Join-Path $project $diskPath
                if (-not (Test-Path $fullPath)) {
                    $newLines += "; DISABLED (missing file): $line"
                    $changed = $true
                    continue
                } else {
                    $remainingEntries++
                }
            }

            $newLines += $line
        }

        if ($changed -and $remainingEntries -eq 0) {
            # ALL entries missing -> fully disable
            $uidFile = $f.FullName + ".uid"
            if (Test-Path $uidFile) {
                Copy-Item $uidFile "$uidFile.bak" -Force -ErrorAction SilentlyContinue
                Remove-Item $uidFile -Force -ErrorAction SilentlyContinue
            }
            Remove-Item $f.FullName -Force -ErrorAction Stop
            $script:ModifiedGDExtFiles += $f.FullName
            Write-Ok "Disabled: $addonName/$($f.Name) (no libraries found on disk)"
        } elseif ($changed) {
            # Some entries remain -> write filtered version
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllLines($f.FullName, $newLines, $utf8NoBom)
            $script:ModifiedGDExtFiles += $f.FullName
            Write-Ok "Filtered: $addonName/$($f.Name) (kept $remainingEntries, removed missing)"
        } else {
            Remove-Item $bakPath -Force -ErrorAction SilentlyContinue
            Write-Ok "OK: $addonName/$($f.Name) (all libraries present)"
        }
    }
}

function Restore-GDExtensions([string]$project) {
    foreach ($origPath in $script:ModifiedGDExtFiles) {
        $bakPath = $origPath + ".bak"
        $uidBak  = $origPath + ".uid.bak"
        $uidPath = $origPath + ".uid"

        if (Test-Path $bakPath) {
            try {
                Move-Item -Path $bakPath -Destination $origPath -Force -ErrorAction Stop
            } catch {
                Write-Warn "Could not restore $(Split-Path -Leaf $origPath): $_"
            }
        }
        if (Test-Path $uidBak) {
            try {
                Move-Item -Path $uidBak -Destination $uidPath -Force -ErrorAction Stop
            } catch {
                Write-Warn "Could not restore UID for $(Split-Path -Leaf $origPath): $_"
            }
        }
    }

    # Delete uid_cache.bin so Godot regenerates it cleanly on next launch
    $uidCache = Join-Path (Join-Path $project ".godot") "uid_cache.bin"
    Remove-Item $uidCache -Force -ErrorAction SilentlyContinue

    $script:ModifiedGDExtFiles = @()
}

# --- Godot Export --------------------------------------------------------------

function Update-ExtensionExportFilter([string]$project, [string]$presetName, [string]$platform) {
    # -GDExtensions all keeps every config, including ones this OS cannot load.
    if ($GDExtensions -eq 'all') { return }
    $py = Join-Path $project "scripts\strip_unsupported_extensions.py"
    if (-not (Test-Path $py)) {
        Write-Warn "strip_unsupported_extensions.py is missing. This export keeps every extension."
        return
    }
    $output = & python $py --project $project --platform $platform --preset $presetName --apply 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Could not strip unsupported extensions for $platform. This export keeps every extension."
        if ($output) { Write-Warn ($output | Out-String).Trim() }
        return
    }
    foreach ($line in $output) {
        Write-Ok $line
    }
}

function Restore-ExtensionExportFilter([string]$project) {
    $py = Join-Path $project "scripts\strip_unsupported_extensions.py"
    if (-not (Test-Path $py)) { return }
    & python $py --project $project --restore | Out-Null
}

function Invoke-GodotExport([string]$godot, [string]$project, [string]$presetName, [string]$outputPath) {
    Write-Host "    Exporting '$presetName' -> $outputPath"

    $outDir = Split-Path -Parent $outputPath
    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    $stderrLog = Join-Path $outDir "export_stderr.log"
    $stdoutLog = Join-Path $outDir "export_stdout.log"

    # Strategy: use cmd.exe /c to launch Godot with shell-level redirects.
    # This avoids three PowerShell 5.1 pitfalls:
    #   1. Direct invocation (&) converts native stderr to ErrorRecords,
    #      which $ErrorActionPreference="Stop" makes fatal.
    #   2. .NET Process with RedirectStandardOutput + RedirectStandardError
    #      deadlocks (or requires async event handlers that break in PS 5.1
    #      scriptblock scoping under StrictMode).
    #   3. Start-Process can resolve APPDATA to a different user profile on
    #      domain-joined machines.
    # cmd.exe /c handles the file redirects at OS level — no pipe deadlock,
    # no PS error stream, inherits current environment.
    $cmdArgs = "`"$godot`" --headless --path `"$project`" --export-release `"$presetName`" `"$outputPath`""
    $cmdLine = "cmd.exe /c `"$cmdArgs > `"$stdoutLog`" 2> `"$stderrLog`"`""

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "cmd.exe"
    $psi.Arguments = "/c `"$cmdArgs > `"$stdoutLog`" 2> `"$stderrLog`"`""
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.WaitForExit()
    $exitCode = $proc.ExitCode

    # macOS exports produce a .app folder, others a file
    $exists = (Test-Path $outputPath)

    if ($exists) {
        if (Test-Path $outputPath -PathType Container) {
            Write-Ok "$($outputPath | Split-Path -Leaf)  (app bundle)"
        } else {
            $sizeMB = [math]::Round((Get-Item $outputPath).Length / 1MB, 1)
            Write-Ok "$($outputPath | Split-Path -Leaf)  ($sizeMB MB)"
        }
        # Clean up log files on success
        Remove-Item $stderrLog -ErrorAction SilentlyContinue
        Remove-Item $stdoutLog -ErrorAction SilentlyContinue
        return $true
    }

    Write-Fail "Export failed (exit code $exitCode)"
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
    Write-Fail 'Set $env:GONODES_GODOT = "C:\path\to\godot.exe"'
    Write-Fail 'Or use -GodotPath:  .\build_templates.ps1 -GodotPath "C:\path\to\godot.exe"'
    exit 1
}
Write-Ok "Godot:   $godot"
if (-not (Test-GodotVersion $godot)) { exit 1 }

# -- Resolve settings ----------------------------------------------------------

if (-not $OutputDir) { $OutputDir = Join-Path $ProjectPath "templates" }

# Auto-detect host platform if none specified
# -- BuildAll shortcut ----------------------------------------------------------

if ($BuildAll) {
    $Platforms = @("all")
    $IncludeEditor = $true
    Write-Ok "BuildAll: building Player + Editor for all platforms"
}

if ($Platforms.Count -eq 0) {
    $Platforms = @(Get-HostPlatform)
    Write-Ok "Auto-detected host platform: $($Platforms[0])"
}

if ($Platforms -contains "all") {
    $Platforms = @("windows_x86_64", "windows_arm64", "linux_x86_64", "linux_arm64", "macos", "android", "ios", "web")
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
Write-Ok "GDExtensions:  $GDExtensions"

# -- Clean ---------------------------------------------------------------------

if ($Clean -and (Test-Path $OutputDir)) {
    Write-Step "Cleaning existing templates..."
    Remove-Item -Recurse -Force $OutputDir
    Write-Ok "Removed $OutputDir"
}

# ==============================================================================
# Pre-Build Checks
# ==============================================================================

Write-Step "Pre-build cleanup..."
Remove-TempFiles $ProjectPath

# -- GDExtension handling ------------------------------------------------------

if ($GDExtensions -eq 'all') {
    Write-Step "Checking GDExtension libraries (all included)..."
    Test-GDExtensions $ProjectPath $Platforms
} else {
    Write-Step "Preparing GDExtensions (mode: $GDExtensions)..."
    Disable-GDExtensions $ProjectPath $GDExtensions
}

# --- Python runtime ------------------------------------------------------------

$script:PythonBundled = $false

function Update-PythonBundle {
    $py = Join-Path $ProjectPath "addons\gn_ext_user_python\setup_python.py"
    if (-not (Test-Path $py)) { return }
    Write-Step "Bundling CPython + NumPy for this OS..."
    & python $py --bundle --no-enable
    if ($LASTEXITCODE -eq 0) {
        $script:PythonBundled = $true
        Write-Ok "Python runtime ready"
    } else {
        Write-Warn "Python runtime was not bundled. This export will not include Python nodes."
    }
}

function Add-PythonRuntime([string]$exportPath, [string]$plat) {
    if (-not $script:PythonBundled) { return }
    if ($plat -ne (Get-HostPlatform)) {
        Write-Warn "The Python runtime matches $(Get-HostPlatform) only. The $plat export does not include it."
        return
    }
    $py = Join-Path $ProjectPath "addons\gn_ext_user_python\setup_python.py"
    & python $py --stage $exportPath
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Python runtime placed next to the export"
    } else {
        Write-Warn "Could not place the Python runtime next to the export"
    }
}

Update-PythonBundle

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
        Update-ExtensionExportFilter $ProjectPath $info.player $plat
        if (Invoke-GodotExport $godot $ProjectPath $info.player $playerOut) {
            Add-PythonRuntime $playerOut $plat
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
            # Skip platforms that don't have editor builds (mobile/web)
            if ($info.editor -eq "") {
                Write-Ok "Skipping Editor for $plat (no editor preset)"
                continue
            }
            $platDir   = Join-Path $OutputDir $plat
            $editorFn  = "GONODES$($info.ext)"
            $editorOut = Join-Path $platDir $editorFn

            Write-Step "Editor - $plat"
            Update-ExtensionExportFilter $ProjectPath $info.editor $plat
            if (Invoke-GodotExport $godot $ProjectPath $info.editor $editorOut) {
                Add-PythonRuntime $editorOut $plat
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
    Restore-ExtensionExportFilter $ProjectPath
    # Always restore GDExtension files first (before main scene, in case
    # the user opens Godot immediately after).
    if ($script:ModifiedGDExtFiles.Count -gt 0) {
        Write-Step "Restoring GDExtension files..."
        Restore-GDExtensions $ProjectPath
        Write-Ok "GDExtension files restored."
    }

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
