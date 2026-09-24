#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pack one GONODES extension addon folder into a .pck under templates/extensions/.

.PARAMETER ExtensionName
    Folder name under addons/ (e.g. gn_ext_mapper or mapper).

.PARAMETER GodotPath
    Path to the Godot editor executable.

.PARAMETER ProjectPath
    GONODES project root (contains project.godot).

.EXAMPLE
    .\pack_extension.ps1 -ExtensionName gn_ext_mapper
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ExtensionName,
    [string]$GodotPath = "",
    [string]$ProjectPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ProjectPath) {
    $ProjectPath = Split-Path -Parent $SCRIPT_DIR
}

$projectGodot = Join-Path $ProjectPath "project.godot"
if (-not (Test-Path $projectGodot)) {
    Write-Error "project.godot not found in $ProjectPath"
}

$folder = $ExtensionName.Trim()
if (-not $folder.StartsWith("gn_ext_")) {
    $folder = "gn_ext_$folder"
}

if ($folder -eq "gn_ext_native") {
    Write-Error "Refusing to pack gn_ext_native"
}

$addonDir = Join-Path $ProjectPath ("addons\" + $folder)
if (-not (Test-Path $addonDir)) {
    Write-Error "Extension folder not found: $addonDir"
}

function Find-Godot {
    if ($GodotPath -and (Test-Path $GodotPath)) { return (Resolve-Path $GodotPath).Path }
    if ($env:GONODES_GODOT -and (Test-Path $env:GONODES_GODOT)) { return (Resolve-Path $env:GONODES_GODOT).Path }
    foreach ($name in @("godot", "godot.exe", "godot4", "Godot")) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    $winPaths = @(
        "$env:USERPROFILE\OneDrive\Documents\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe",
        "C:\Godot\Godot_v4.7.2-stable_win64.exe"
    )
    foreach ($p in $winPaths) {
        if (Test-Path $p) { return $p }
    }
    return ""
}

$godot = Find-Godot
if (-not $godot) {
    Write-Error "Godot executable not found. Set -GodotPath or `$env:GONODES_GODOT."
}

$packScript = Join-Path $SCRIPT_DIR "pack_extension.gd"
Write-Host "Packing $folder -> templates/extensions/$folder.pck"
$proc = Start-Process -FilePath $godot -ArgumentList @(
    "--headless", "--path", $ProjectPath, "-s", $packScript, "--", $folder
) -Wait -PassThru -NoNewWindow
if ($proc.ExitCode -ne 0) {
    exit $proc.ExitCode
}

Write-Host "Done."
