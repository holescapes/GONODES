<#
.SYNOPSIS
    Add WindowTOP (512x512, open=true) sink to all help patches missing one.
.DESCRIPTION
    For each .gnpatch file without a WindowTOP node:
    1. Parse JSON
    2. Find terminal nodes (outputs not used as inputs by other nodes)
    3. Pick the rightmost terminal node
    4. Add a WindowTOP node 350px to the right
    5. Connect the terminal node's output to WindowTOP input
    6. Save back to file
#>

$helpDir = "c:\MeOwn\Gonodes\addons\gonodes\help"
$patchFiles = Get-ChildItem -Path $helpDir -Recurse -Filter "*.gnpatch"
$updated = 0
$skipped = 0
$errors = @()

foreach ($file in $patchFiles) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    
    # Skip if already has WindowTOP
    if ($content -match '"WindowTOP"') {
        $skipped++
        continue
    }
    
    try {
        $json = $content | ConvertFrom-Json
        
        # Get all node names
        $nodeNames = @($json.nodes.PSObject.Properties.Name)
        if ($nodeNames.Count -eq 0) {
            $skipped++
            continue
        }
        
        # Find which nodes are used as sources (from) in connections
        $sourceNodes = @{}
        if ($json.connections) {
            foreach ($conn in $json.connections) {
                $sourceNodes[$conn.to] = $true
            }
        }
        
        # Find which nodes are used as "from" in connections (i.e., they feed into other nodes)
        $feedsInto = @{}
        if ($json.connections) {
            foreach ($conn in $json.connections) {
                $feedsInto[$conn.from] = $true
            }
        }
        
        # Terminal nodes = nodes NOT feeding into others
        $terminalNodes = @()
        foreach ($name in $nodeNames) {
            if (-not $feedsInto.ContainsKey($name)) {
                $terminalNodes += $name
            }
        }
        
        # If no terminal nodes found (everything connects to something), use rightmost node
        if ($terminalNodes.Count -eq 0) {
            $terminalNodes = $nodeNames
        }
        
        # Find the rightmost terminal node (highest X position)
        $bestNode = $null
        $bestX = -999999
        foreach ($name in $terminalNodes) {
            $node = $json.nodes.$name
            $x = 0
            if ($node.position -and $node.position.Count -ge 1) {
                $x = [int]$node.position[0]
            }
            if ($x -gt $bestX) {
                $bestX = $x
                $bestNode = $name
            }
        }
        
        if ($bestNode -eq $null) {
            $skipped++
            continue
        }
        
        # Get Y position of best node
        $bestY = 0
        $node = $json.nodes.$bestNode
        if ($node.position -and $node.position.Count -ge 2) {
            $bestY = [int]$node.position[1]
        }
        
        # Determine node type to check if it's a TOP family
        $bestType = $json.nodes.$bestNode.type
        
        # For SOP/COMP chains that end with RenderTOP, no extra step needed
        # For SOP/COMP chains without RenderTOP, we need RenderTOP → WindowTOP
        # For simple cases, just add WindowTOP after the last TOP
        
        # Check if the terminal node is a TOP type (ends with "TOP" or is specific non-TOP types)
        $isTOP = $bestType -match "TOP$"
        $isIMG = $bestType -match "IMG$"
        $isRenderTOP = $bestType -eq "RenderTOP"
        
        # Generate unique window node name
        $windowName = "window1"
        $counter = 1
        while ($nodeNames -contains $windowName) {
            $counter++
            $windowName = "window$counter"
        }
        
        # Position WindowTOP 350px to the right of the last node
        $windowX = $bestX + 350
        $windowY = $bestY
        
        # Build the window node JSON
        $windowNode = @{
            type = "WindowTOP"
            position = @($windowX, $windowY)
            parameters = @{
                resolution = @{
                    value = @{
                        _type = "Vector2i"
                        x = 512
                        y = 512
                    }
                }
                open = @{
                    value = $true
                }
            }
        }
        
        # Add window node to json
        $json.nodes | Add-Member -NotePropertyName $windowName -NotePropertyValue $windowNode
        
        # Add connection from best node to window
        $newConn = @{
            from = $bestNode
            from_port = 0
            to = $windowName
            to_port = 0
        }
        
        if ($json.connections -eq $null) {
            $json.connections = @($newConn)
        } else {
            $connArray = @($json.connections)
            $connArray += $newConn
            $json.connections = $connArray
        }
        
        # Convert back to JSON and save
        $outputJson = $json | ConvertTo-Json -Depth 10 -Compress:$false
        
        # Fix the position arrays to be on one line (cosmetic)
        # PowerShell ConvertTo-Json expands arrays vertically, we want compact positions
        
        Set-Content -Path $file.FullName -Value $outputJson -Encoding UTF8 -NoNewline
        $updated++
        
    } catch {
        $errors += "$($file.Name): $($_.Exception.Message)"
    }
}

Write-Host "`nResults:"
Write-Host "  Updated: $updated"
Write-Host "  Skipped (already has WindowTOP): $skipped"
Write-Host "  Errors: $($errors.Count)"
if ($errors.Count -gt 0) {
    Write-Host "`nErrors:"
    $errors | ForEach-Object { Write-Host "  $_" }
}
