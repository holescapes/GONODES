# windows_register_gnpatch.ps1 — Register .gnpatch file association on Windows.
#
# Usage (run as current user — no admin required for HKCU):
#   .\windows_register_gnpatch.ps1 -EditorExe "C:\Program Files\GONODES\GONODES.exe" `
#                                   -PlayerExe "C:\Program Files\GONODES\GONODESPlayer.exe" `
#                                   -IconPath  "C:\Program Files\GONODES\gnpatch.ico"
#
# To unregister:
#   .\windows_register_gnpatch.ps1 -Unregister

param(
    [string]$EditorExe,
    [string]$PlayerExe,
    [string]$IconPath,
    [switch]$Unregister
)

$ErrorActionPreference = "Stop"

$ext      = ".gnpatch"
$progId   = "GONODES.Patch"
$basePath = "HKCU:\Software\Classes"

if ($Unregister) {
    Write-Host "Removing .gnpatch file association..."
    Remove-Item -Path "$basePath\$ext" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$basePath\$progId" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Done. You may need to restart Explorer for changes to take effect."
    exit 0
}

if (-not $EditorExe) {
    Write-Error "Please provide -EditorExe path."
    exit 1
}

# ── Extension → ProgID mapping ──
New-Item -Path "$basePath\$ext" -Value $progId -Force | Out-Null
# Perceived type so Explorer shows it in the "document" category
New-Item -Path "$basePath\$ext" -Name "Content Type" -Force | Out-Null
Set-ItemProperty -Path "$basePath\$ext" -Name "(Default)" -Value $progId

# ── ProgID definition ──
New-Item -Path "$basePath\$progId" -Value "GONODES Patch File" -Force | Out-Null

# Icon (optional)
if ($IconPath -and (Test-Path $IconPath)) {
    New-Item -Path "$basePath\$progId\DefaultIcon" -Value "`"$IconPath`",0" -Force | Out-Null
}

# Default verb: open with Editor
New-Item -Path "$basePath\$progId\shell" -Force | Out-Null
Set-ItemProperty -Path "$basePath\$progId\shell" -Name "(Default)" -Value "open"

New-Item -Path "$basePath\$progId\shell\open" -Force | Out-Null
Set-ItemProperty -Path "$basePath\$progId\shell\open" -Name "(Default)" -Value "Open in GONODES Editor"
New-Item -Path "$basePath\$progId\shell\open\command" -Value "`"$EditorExe`" `"%1`"" -Force | Out-Null

# Secondary verb: play with Player
if ($PlayerExe -and (Test-Path $PlayerExe)) {
    New-Item -Path "$basePath\$progId\shell\play" -Force | Out-Null
    Set-ItemProperty -Path "$basePath\$progId\shell\play" -Name "(Default)" -Value "Play in GONODES Player"
    New-Item -Path "$basePath\$progId\shell\play\command" -Value "`"$PlayerExe`" `"%1`"" -Force | Out-Null
}

# Notify Explorer of the change
$code = @"
[System.Runtime.InteropServices.DllImport("shell32.dll")]
public static extern void SHChangeNotify(int wEventId, int uFlags, System.IntPtr dwItem1, System.IntPtr dwItem2);
"@
$shell = Add-Type -MemberDefinition $code -Name "ShellNotify" -Namespace "Win32" -PassThru
$shell::SHChangeNotify(0x08000000, 0, [System.IntPtr]::Zero, [System.IntPtr]::Zero)

Write-Host "Registered .gnpatch → GONODES Editor (double-click) + Player (right-click → Play)"
Write-Host "Editor: $EditorExe"
if ($PlayerExe) { Write-Host "Player: $PlayerExe" }
if ($IconPath)  { Write-Host "Icon:   $IconPath" }
