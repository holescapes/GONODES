<#
.SYNOPSIS
    Fix all help patches that have invalid non-TOP→WindowTOP connections.
    Replaces them with proper family-appropriate visualization chains.
#>

param(
    [string]$HelpRoot = (Join-Path $PSScriptRoot "..\addons\gonodes\help")
)

$HelpRoot = Resolve-Path $HelpRoot

$stats = @{ Fixed = 0; Skipped = 0; Errors = 0 }

function Get-FromKey($conn) {
    if ($conn.from) { return $conn.from } else { return $conn.from_node }
}
function Get-ToKey($conn) {
    if ($conn.to) { return $conn.to } else { return $conn.to_node }
}

function Fix-ChopPatch($filePath) {
    <#  CHOP → CHOPtoTOP → WindowTOP  #>
    try {
        $raw = Get-Content $filePath -Raw -Encoding UTF8
        $json = $raw | ConvertFrom-Json

        # Find connection to window1
        $winConn = $json.connections | Where-Object { (Get-ToKey $_) -eq 'window1' }
        if (-not $winConn) { return $false }

        $srcName = Get-FromKey $winConn
        $srcNode = $json.nodes.PSObject.Properties | Where-Object { $_.Name -eq $srcName }
        if (-not $srcNode) { return $false }
        $srcType = $srcNode.Value.type
        if ($srcType -match 'TOP$') { return $false }  # Already valid

        # Get window1 position
        $winPos = $json.nodes.window1.position
        $winX = [int]$winPos[0]
        $winY = [int]$winPos[1]

        # Insert CHOPtoTOP between source and window1
        $choptopX = $winX
        $newWinX = $winX + 350

        # Add CHOPtoTOP node
        $choptopNode = [ordered]@{
            type = "CHOPtoTOP"
            position = @($choptopX, $winY)
            parameters = [ordered]@{
                resolution = @{ value = [ordered]@{ _type = "Vector2i"; x = 512; y = 512 } }
            }
        }
        $json.nodes | Add-Member -NotePropertyName "choptop1" -NotePropertyValue ([PSCustomObject]$choptopNode) -Force

        # Move window1 to the right
        $json.nodes.window1.position = @($newWinX, $winY)

        # Fix connections: remove old X→window1, add X→choptop1 and choptop1→window1
        $newConns = @()
        foreach ($c in $json.connections) {
            $to = Get-ToKey $c
            if ($to -eq 'window1') {
                # Replace with source→choptop1
                $newConns += [PSCustomObject]@{ from = (Get-FromKey $c); from_port = [int]$c.from_port; to = "choptop1"; to_port = 0 }
            } else {
                $newConns += $c
            }
        }
        # Add choptop1→window1
        $newConns += [PSCustomObject]@{ from = "choptop1"; from_port = 0; to = "window1"; to_port = 0 }
        $json.connections = $newConns

        $json | ConvertTo-Json -Depth 20 | Set-Content $filePath -Encoding UTF8
        return $true
    } catch {
        Write-Host "  ERROR ($filePath): $_" -ForegroundColor Red
        return $null
    }
}

function Fix-SopPatch($filePath) {
    <#  SOP → GeometryCOMP + CameraCOMP → RenderTOP → WindowTOP  #>
    try {
        $raw = Get-Content $filePath -Raw -Encoding UTF8
        $json = $raw | ConvertFrom-Json

        # Find connection to window1
        $winConn = $json.connections | Where-Object { (Get-ToKey $_) -eq 'window1' }
        if (-not $winConn) { return $false }

        $srcName = Get-FromKey $winConn
        $srcNode = $json.nodes.PSObject.Properties | Where-Object { $_.Name -eq $srcName }
        if (-not $srcNode) { return $false }
        $srcType = $srcNode.Value.type
        if ($srcType -match 'TOP$') { return $false }  # Already valid

        # Get positions
        $srcPos = $srcNode.Value.position
        $srcX = [int]$srcPos[0]
        $srcY = [int]$srcPos[1]

        $geoX = $srcX + 300
        $camX = $geoX
        $camY = $srcY + 200
        $renderX = $geoX + 300
        $winX = $renderX + 350

        # Add GeometryCOMP
        $geoNode = [ordered]@{
            type = "GeometryCOMP"
            position = @($geoX, $srcY)
            parameters = @{}
        }
        $json.nodes | Add-Member -NotePropertyName "geo_view" -NotePropertyValue ([PSCustomObject]$geoNode) -Force

        # Add CameraCOMP
        $camNode = [ordered]@{
            type = "CameraCOMP"
            position = @($camX, $camY)
            parameters = [ordered]@{
                tx = @{ value = 0.0 }
                ty = @{ value = 0.5 }
                tz = @{ value = 3.0 }
            }
        }
        $json.nodes | Add-Member -NotePropertyName "cam_view" -NotePropertyValue ([PSCustomObject]$camNode) -Force

        # Add RenderTOP
        $renderNode = [ordered]@{
            type = "RenderTOP"
            position = @($renderX, $srcY)
            parameters = [ordered]@{
                resolution = @{ value = [ordered]@{ _type = "Vector2i"; x = 512; y = 512 } }
            }
        }
        $json.nodes | Add-Member -NotePropertyName "render_view" -NotePropertyValue ([PSCustomObject]$renderNode) -Force

        # Move window1
        $json.nodes.window1.position = @($winX, $srcY)

        # Fix connections
        $newConns = @()
        foreach ($c in $json.connections) {
            if ((Get-ToKey $c) -eq 'window1') {
                # Replace: source→geo_view
                $newConns += [PSCustomObject]@{ from = (Get-FromKey $c); from_port = [int]$c.from_port; to = "geo_view"; to_port = 0 }
            } else {
                $newConns += $c
            }
        }
        # Add scene chain
        $newConns += [PSCustomObject]@{ from = "geo_view"; from_port = 0; to = "render_view"; to_port = 0 }
        $newConns += [PSCustomObject]@{ from = "cam_view"; from_port = 0; to = "render_view"; to_port = 1 }
        $newConns += [PSCustomObject]@{ from = "render_view"; from_port = 0; to = "window1"; to_port = 0 }
        $json.connections = $newConns

        $json | ConvertTo-Json -Depth 20 | Set-Content $filePath -Encoding UTF8
        return $true
    } catch {
        Write-Host "  ERROR ($filePath): $_" -ForegroundColor Red
        return $null
    }
}

function Fix-CompPatch($filePath) {
    <#
        COMP patches need a scene → RenderTOP → WindowTOP.
        If the terminal COMP is a scene node (Geo, Light, Camera, etc.),
        add RenderTOP + CameraCOMP (if no camera).
        For non-scene COMPs (AnimationCOMP, etc.), need Geo+Camera+Render.
    #>
    try {
        $raw = Get-Content $filePath -Raw -Encoding UTF8
        $json = $raw | ConvertFrom-Json

        $winConn = $json.connections | Where-Object { (Get-ToKey $_) -eq 'window1' }
        if (-not $winConn) { return $false }

        $srcName = Get-FromKey $winConn
        $srcNode = $json.nodes.PSObject.Properties | Where-Object { $_.Name -eq $srcName }
        if (-not $srcNode) { return $false }
        $srcType = $srcNode.Value.type
        if ($srcType -match 'TOP$') { return $false }

        # Check existing nodes for camera and geo
        $hasCamera = $false
        $hasMergeCOMP = $false
        $hasGeo = $false
        $cameraName = $null
        $geoName = $null
        $mergeCompName = $null
        foreach ($prop in $json.nodes.PSObject.Properties) {
            if ($prop.Value.type -eq 'CameraCOMP') { $hasCamera = $true; $cameraName = $prop.Name }
            if ($prop.Value.type -eq 'GeometryCOMP') { $hasGeo = $true; $geoName = $prop.Name }
            if ($prop.Value.type -eq 'MergeCOMP') { $hasMergeCOMP = $true; $mergeCompName = $prop.Name }
        }

        $srcPos = $srcNode.Value.position
        $srcX = [int]($srcPos[0])
        $srcY = [int]($srcPos[1])
        # Scene COMPs (Geo, Rigid, Static, Soft, Instance, MergeCOMP) can feed render directly
        $sceneTypes = @('GeometryCOMP','RigidBodyCOMP','StaticBodyCOMP','SoftBodyCOMP','InstanceCOMP','MergeCOMP','AreaCOMP')
        $isSceneComp = $sceneTypes -contains $srcType

        $renderX = $srcX + 300
        $winX = $renderX + 350

        # For non-scene COMPs (AnimationCOMP, NullCOMP, SwitchCOMP, SubNetworkNode, etc.)
        # We need to find a scene comp to connect to render, or build one
        if (-not $isSceneComp) {
            # Find what the terminal comp feeds (it might feed a scene comp upstream)
            # Strategy: look for a geoComp or mergeCOMP in the patch, use that as render input
            if ($hasMergeCOMP) {
                $feedName = $mergeCompName
            } elseif ($hasGeo) {
                $feedName = $geoName
            } else {
                # No scene comp at all — add a box + geo to visualize
                $boxX = $srcX + 300
                $geoViewX = $boxX + 300
                $renderX = $geoViewX + 300
                $winX = $renderX + 350

                $json.nodes | Add-Member -NotePropertyName "box_view" -NotePropertyValue ([PSCustomObject][ordered]@{
                    type = "BoxSOP"
                    position = @($boxX, $srcY)
                    parameters = @{}
                }) -Force

                $json.nodes | Add-Member -NotePropertyName "geo_view" -NotePropertyValue ([PSCustomObject][ordered]@{
                    type = "GeometryCOMP"
                    position = @($geoViewX, $srcY)
                    parameters = @{}
                }) -Force

                $feedName = "geo_view"

                # Connect box→geo
                $json.connections = @($json.connections) + @(
                    [PSCustomObject]@{ from = "box_view"; from_port = 0; to = "geo_view"; to_port = 0 }
                )
            }

            # Use this scene comp as render input
            $feedPos = ($json.nodes.PSObject.Properties | Where-Object { $_.Name -eq $feedName }).Value.position
            $feedX = [int]($feedPos[0])
            $renderX = [Math]::Max([int]$renderX, [int]($feedX + 300))
            $winX = [int]($renderX + 350)

            $renderNode = [ordered]@{
                type = "RenderTOP"
                position = @($renderX, $srcY)
                parameters = [ordered]@{
                    resolution = @{ value = [ordered]@{ _type = "Vector2i"; x = 512; y = 512 } }
                }
            }
            $json.nodes | Add-Member -NotePropertyName "render_view" -NotePropertyValue ([PSCustomObject]$renderNode) -Force

            if (-not $hasCamera) {
                $camY = [int]($srcY + 200)
                $camPosX = [int]($renderX - 300)
                $json.nodes | Add-Member -NotePropertyName "cam_view" -NotePropertyValue ([PSCustomObject][ordered]@{
                    type = "CameraCOMP"
                    position = @($camPosX, $camY)
                    parameters = [ordered]@{ tx = @{value=0.0}; ty = @{value=0.5}; tz = @{value=3.0} }
                }) -Force
                $cameraName = "cam_view"
            }

            $json.nodes.window1.position = @([int]$winX, [int]$srcY)

            # Fix connections: remove X→window1
            $newConns = @()
            foreach ($c in $json.connections) {
                if ((Get-ToKey $c) -ne 'window1') { $newConns += $c }
            }
            $newConns += [PSCustomObject]@{ from = $feedName; from_port = 0; to = "render_view"; to_port = 0 }
            $newConns += [PSCustomObject]@{ from = $cameraName; from_port = 0; to = "render_view"; to_port = 1 }
            $newConns += [PSCustomObject]@{ from = "render_view"; from_port = 0; to = "window1"; to_port = 0 }
            $json.connections = $newConns
        } else {
            # srcType is a scene comp — connect it directly to render
            $renderNode = [ordered]@{
                type = "RenderTOP"
                position = @($renderX, $srcY)
                parameters = [ordered]@{
                    resolution = @{ value = [ordered]@{ _type = "Vector2i"; x = 512; y = 512 } }
                }
            }
            $json.nodes | Add-Member -NotePropertyName "render_view" -NotePropertyValue ([PSCustomObject]$renderNode) -Force

            if (-not $hasCamera) {
                $camY = [int]($srcY + 200)
                $camPosX = [int]($renderX - 300)
                $json.nodes | Add-Member -NotePropertyName "cam_view" -NotePropertyValue ([PSCustomObject][ordered]@{
                    type = "CameraCOMP"
                    position = @($camPosX, $camY)
                    parameters = [ordered]@{ tx = @{value=0.0}; ty = @{value=0.5}; tz = @{value=3.0} }
                }) -Force
                $cameraName = "cam_view"
            }

            $json.nodes.window1.position = @([int]$winX, [int]$srcY)

            # Fix connections: replace X→window1 with X→render_view
            $newConns = @()
            foreach ($c in $json.connections) {
                if ((Get-ToKey $c) -eq 'window1') {
                    $newConns += [PSCustomObject]@{ from = (Get-FromKey $c); from_port = [int]$c.from_port; to = "render_view"; to_port = 0 }
                } else {
                    $newConns += $c
                }
            }
            if ($cameraName) {
                $newConns += [PSCustomObject]@{ from = $cameraName; from_port = 0; to = "render_view"; to_port = 1 }
            }
            $newConns += [PSCustomObject]@{ from = "render_view"; from_port = 0; to = "window1"; to_port = 0 }
            $json.connections = $newConns
        }

        $json | ConvertTo-Json -Depth 20 | Set-Content $filePath -Encoding UTF8
        return $true
    } catch {
        Write-Host "  ERROR ($filePath): $_" -ForegroundColor Red
        return $null
    }
}

function Fix-DatPatch($filePath) {
    <#  DAT: Add TextTOP between — displays a description of what the DAT does  #>
    try {
        $raw = Get-Content $filePath -Raw -Encoding UTF8
        $json = $raw | ConvertFrom-Json

        $winConn = $json.connections | Where-Object { (Get-ToKey $_) -eq 'window1' }
        if (-not $winConn) { return $false }

        $srcName = Get-FromKey $winConn
        $srcNode = $json.nodes.PSObject.Properties | Where-Object { $_.Name -eq $srcName }
        if (-not $srcNode) { return $false }
        $srcType = $srcNode.Value.type
        if ($srcType -match 'TOP$') { return $false }

        $winPos = $json.nodes.window1.position
        $winX = [int]$winPos[0]
        $winY = [int]$winPos[1]

        # Get the DAT node's type for descriptive text
        $description = "$srcType output"

        $textX = $winX
        $newWinX = $winX + 350

        $textNode = [ordered]@{
            type = "TextTOP"
            position = @($textX, $winY)
            parameters = [ordered]@{
                resolution = @{ value = [ordered]@{ _type = "Vector2i"; x = 512; y = 512 } }
                text = @{ value = $description }
                font_size = @{ value = 24 }
            }
        }
        $json.nodes | Add-Member -NotePropertyName "text_view" -NotePropertyValue ([PSCustomObject]$textNode) -Force

        $json.nodes.window1.position = @($newWinX, $winY)

        # Fix connections: remove DAT→window1, add DAT→text_view(dat_input) and text_view→window1
        # DAT→TextTOP: TextTOP has a DAT input on port 0 that overrides the text param
        $newConns = @()
        foreach ($c in $json.connections) {
            if ((Get-ToKey $c) -eq 'window1') {
                # Route DAT into TextTOP's DAT input (port 1)
                $newConns += [PSCustomObject]@{ from = (Get-FromKey $c); from_port = [int]$c.from_port; to = "text_view"; to_port = 0 }
            } else {
                $newConns += $c
            }
        }
        $newConns += [PSCustomObject]@{ from = "text_view"; from_port = 0; to = "window1"; to_port = 0 }
        $json.connections = $newConns

        $json | ConvertTo-Json -Depth 20 | Set-Content $filePath -Encoding UTF8
        return $true
    } catch {
        Write-Host "  ERROR ($filePath): $_" -ForegroundColor Red
        return $null
    }
}

function Fix-MatPatch($filePath) {
    <#  MAT: BoxSOP → GeometryCOMP (with MAT input) → CameraCOMP → RenderTOP → WindowTOP  #>
    try {
        $raw = Get-Content $filePath -Raw -Encoding UTF8
        $json = $raw | ConvertFrom-Json

        $winConn = $json.connections | Where-Object { (Get-ToKey $_) -eq 'window1' }
        if (-not $winConn) { return $false }

        $srcName = Get-FromKey $winConn
        $srcNode = $json.nodes.PSObject.Properties | Where-Object { $_.Name -eq $srcName }
        if (-not $srcNode) { return $false }
        $srcType = $srcNode.Value.type
        if ($srcType -match 'TOP$') { return $false }

        $srcPos = $srcNode.Value.position
        $srcX = [int]$srcPos[0]
        $srcY = [int]$srcPos[1]

        # Check if there's already a GeometryCOMP
        $hasGeo = $false
        $geoName = $null
        foreach ($prop in $json.nodes.PSObject.Properties) {
            if ($prop.Value.type -eq 'GeometryCOMP') { $hasGeo = $true; $geoName = $prop.Name }
        }

        # Check if there's already a SOP feeding the scene
        $hasSop = $false
        foreach ($prop in $json.nodes.PSObject.Properties) {
            if ($prop.Value.type -match 'SOP$') { $hasSop = $true; break }
        }

        $boxX = $srcX + 300
        $geoX = $boxX + 300
        $renderX = $geoX + 300
        $camX = $geoX
        $camY = $srcY + 200
        $winX = $renderX + 350

        # Add BoxSOP for shape (unless there's already a SOP)
        if (-not $hasSop) {
            $json.nodes | Add-Member -NotePropertyName "box_view" -NotePropertyValue ([PSCustomObject][ordered]@{
                type = "BoxSOP"
                position = @($boxX, $srcY)
                parameters = @{}
            }) -Force
        }

        if (-not $hasGeo) {
            $json.nodes | Add-Member -NotePropertyName "geo_view" -NotePropertyValue ([PSCustomObject][ordered]@{
                type = "GeometryCOMP"
                position = @($geoX, $srcY)
                parameters = @{}
            }) -Force
            $geoName = "geo_view"
        }

        $json.nodes | Add-Member -NotePropertyName "cam_view" -NotePropertyValue ([PSCustomObject][ordered]@{
            type = "CameraCOMP"
            position = @($camX, $camY)
            parameters = [ordered]@{ tx = @{value=0.0}; ty = @{value=0.5}; tz = @{value=3.0} }
        }) -Force

        $json.nodes | Add-Member -NotePropertyName "render_view" -NotePropertyValue ([PSCustomObject][ordered]@{
            type = "RenderTOP"
            position = @($renderX, $srcY)
            parameters = [ordered]@{
                resolution = @{ value = [ordered]@{ _type = "Vector2i"; x = 512; y = 512 } }
            }
        }) -Force

        $json.nodes.window1.position = @($winX, $srcY)

        # Fix connections: remove MAT→window1, build proper chain
        $newConns = @()
        foreach ($c in $json.connections) {
            if ((Get-ToKey $c) -eq 'window1') {
                # Route MAT into GeometryCOMP's material port (port 1)
                $newConns += [PSCustomObject]@{ from = (Get-FromKey $c); from_port = [int]$c.from_port; to = $geoName; to_port = 1 }
            } else {
                $newConns += $c
            }
        }
        # Add box→geo (SOP port 0)
        if (-not $hasSop) {
            $newConns += [PSCustomObject]@{ from = "box_view"; from_port = 0; to = $geoName; to_port = 0 }
        }
        $newConns += [PSCustomObject]@{ from = $geoName; from_port = 0; to = "render_view"; to_port = 0 }
        $newConns += [PSCustomObject]@{ from = "cam_view"; from_port = 0; to = "render_view"; to_port = 1 }
        $newConns += [PSCustomObject]@{ from = "render_view"; from_port = 0; to = "window1"; to_port = 0 }
        $json.connections = $newConns

        $json | ConvertTo-Json -Depth 20 | Set-Content $filePath -Encoding UTF8
        return $true
    } catch {
        Write-Host "  ERROR ($filePath): $_" -ForegroundColor Red
        return $null
    }
}

# ── Main ──────────────────────────────────────────────────────

$familyFixers = @{
    chop = { param($f) Fix-ChopPatch $f }
    sop  = { param($f) Fix-SopPatch $f }
    comp = { param($f) Fix-CompPatch $f }
    dat  = { param($f) Fix-DatPatch $f }
    mat  = { param($f) Fix-MatPatch $f }
}

foreach ($fam in @('chop','sop','comp','dat','mat')) {
    $dir = Join-Path $HelpRoot $fam
    $fixer = $familyFixers[$fam]
    Write-Host "`n=== $($fam.ToUpper()) ===" -ForegroundColor Cyan
    foreach ($f in Get-ChildItem $dir -Filter *.gnpatch | Sort-Object Name) {
        $result = & $fixer $f.FullName
        if ($result -eq $true) {
            Write-Host "  FIXED: $($f.Name)" -ForegroundColor Green
            $stats.Fixed++
        } elseif ($result -eq $false) {
            Write-Host "  SKIP:  $($f.Name) (already valid)" -ForegroundColor Yellow
            $stats.Skipped++
        } else {
            $stats.Errors++
        }
    }
}

Write-Host "`n── Summary ──" -ForegroundColor White
Write-Host "Fixed:   $($stats.Fixed)"
Write-Host "Skipped: $($stats.Skipped)"
Write-Host "Errors:  $($stats.Errors)"
