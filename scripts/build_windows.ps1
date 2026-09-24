# GONODES — Windows dev build from a fresh clone
#
# Runs the full native-extension pipeline inside the MSVC environment:
#   setup_deps -> extension setups (build.cfg) -> check_env -> godot-cpp -> scons
#
# Default: tier=all — build every extension this platform can (optional tier included;
# proprietary SDK misses / empty SDK folders are skipped, not fatal). Setups run first
# so user_python, OpenCV, etc. download before compile.
#
# Usage (from repo root):
#   .\scripts\build_windows.ps1
#   .\scripts\build_windows.ps1 -Shipped          # faster: core + extension only
#   .\scripts\build_windows.ps1 -SkipDeps
#   .\scripts\build_windows.ps1 -Jobs 8
#   .\scripts\build_windows.ps1 -Tier core
#   .\scripts\build_windows.ps1 -Exts "gn_ext_hap,gn_ext_midi"
#
# Prerequisites (first time only):
#   winget install Python.Python.3.12
#   pip install scons
#   winget install Microsoft.VisualStudio.2022.BuildTools --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
#   Install Godot matching versions.env (currently 4.7.2) + export templates
#   Optional: $env:GONODES_GODOT = "C:\path\to\Godot_*_console.exe"

param(
    [int]$Jobs = 8,
    [string]$Arch = "x86_64",
    [string]$Ext = "",
    [string]$Exts = "",
    [string]$Tier = "",
    [switch]$Shipped,
    [switch]$SkipDeps,
    [switch]$SkipGodotCpp
)

$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $Root

Write-Host ""
Write-Host "============================================================"
Write-Host "  GONODES Windows Build"
Write-Host "  Root: $Root"
Write-Host "============================================================"

# ── Locate MSVC environment ──────────────────────────────────────────────────
if (-not ${env:ProgramFiles(x86)}) {
    ${env:ProgramFiles(x86)} = 'C:\Program Files (x86)'
}
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
    Write-Error "vswhere.exe not found. Install Visual Studio 2022 Build Tools with C++ workload."
}
$vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsPath) {
    Write-Error "MSVC not found. Install VS 2022 Build Tools with 'Desktop development with C++'."
}
$vcvars = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
if (-not (Test-Path $vcvars)) {
    Write-Error "vcvars64.bat not found at: $vcvars"
}

function Invoke-InVcEnv([string]$Command) {
    $full = "`"$vcvars`" >nul && cd /d `"$Root`" && $Command"
    cmd /c $full
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed (exit $LASTEXITCODE): $Command"
    }
}

# ── Resolve build tier ───────────────────────────────────────────────────────
$buildTier = "all"
if ($Tier) { $buildTier = $Tier }
elseif ($Shipped) { $buildTier = "shipped" }

if ($buildTier -eq "all") {
    Write-Host ""
    Write-Host "  Build mode: tier=all (core + extension + optional when SDK present)"
} elseif ($buildTier -eq "shipped") {
    Write-Host ""
    Write-Host "  Build mode: tier=shipped (core + extension only)"
} else {
    Write-Host ""
    Write-Host "  Build mode: tier=$buildTier"
}

# ── Dependencies ─────────────────────────────────────────────────────────────
if (-not $SkipDeps) {
    Write-Host ""
    Write-Host "-- Dependencies: setup_deps.py --"
    python setup_deps.py
    if ($LASTEXITCODE -ne 0) {
        Write-Error "setup_deps.py failed."
    }
}

# ── Extension SDKs (build.cfg setup / vendor_clone) ─────────────────────────
Write-Host ""
Write-Host "-- Extension SDKs: run_extension_setups.py (for-build) --"
$setupArgs = @(
    "scripts/run_extension_setups.py", "--for-build",
    "--tier", $buildTier, "--platform", "windows"
)
if ($Ext) { $setupArgs += @("--ext", $Ext) }
elseif ($Exts) { $setupArgs += @("--exts", $Exts) }
python @setupArgs
if ($LASTEXITCODE -ne 0) {
    Write-Warning "run_extension_setups.py reported errors (non-fatal; continuing build)."
}

# ── Pre-flight (after SDK fetch so probes reflect downloaded toolchains) ─────
Write-Host ""
Write-Host "-- Pre-flight: check_env.py --"
python scripts/check_env.py
if ($LASTEXITCODE -ne 0) {
    Write-Error "check_env.py reported failures. Fix prerequisites before building."
}

# ── godot-cpp ────────────────────────────────────────────────────────────────
if (-not $SkipGodotCpp) {
    Write-Host ""
    Write-Host "-- Building godot-cpp --"
    Invoke-InVcEnv "cd addons\gn_ext_native\native\godot-cpp && scons platform=windows arch=$Arch target=template_release -j$Jobs"
}

# ── Unified extension build ──────────────────────────────────────────────────
Write-Host ""
Write-Host "-- Building native extensions --"
$extArg = ""
if ($Ext) { $extArg = "ext=$Ext " }
elseif ($Exts) { $extArg = "exts=$Exts " }
elseif ($Tier -or $Shipped) { $extArg = "tier=$buildTier " }
else { $extArg = "tier=all " }
Invoke-InVcEnv "cd build && scons ${extArg}platform=windows arch=$Arch target=template_release -j$Jobs"

Write-Host ""
Write-Host "============================================================"
Write-Host "  Build finished."
Write-Host "  Run: python scripts/check_builds.py"
Write-Host "  Restart Godot to load activated extensions."
Write-Host "============================================================"
Write-Host ""
