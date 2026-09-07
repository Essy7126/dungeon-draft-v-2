# Explicit authoring geometry -> canonical arena resource and derived guides.
param(
    [string]$ManifestPath = '',
    [string]$ArenaPath = '',
    [switch]$ValidateOnly
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$arenaRoot = Join-Path $projectRoot 'data/arenas/greek_drawn_courtyard_v1'
if ($ManifestPath -eq '') { $ManifestPath = Join-Path $arenaRoot 'geometry_manifest.json' }
if ($ArenaPath -eq '') { $ArenaPath = Join-Path $arenaRoot 'arena.tres' }
$manifestPath = [System.IO.Path]::GetFullPath($ManifestPath)
$arenaPath = [System.IO.Path]::GetFullPath($ArenaPath)
$arenaRoot = Split-Path -Parent $arenaPath
$geometry = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
function Set-GeometryProperty([string]$name, $value) {
    $geometry | Add-Member -MemberType NoteProperty -Name $name -Value $value -Force
}
function Test-ContourPoint([double]$x, [double]$y, $polygon) {
    $inside = $false
    for ($i=0; $i -lt $polygon.Count; $i++) {
        $j = ($i + $polygon.Count - 1) % $polygon.Count
        $a=$polygon[$i]; $b=$polygon[$j]
        $cross=($x-$a[0])*($b[1]-$a[1])-($y-$a[1])*($b[0]-$a[0])
        if ([Math]::Abs($cross) -lt 0.000001 -and $x -ge [Math]::Min($a[0],$b[0]) -and $x -le [Math]::Max($a[0],$b[0]) -and $y -ge [Math]::Min($a[1],$b[1]) -and $y -le [Math]::Max($a[1],$b[1])) { return $true }
        if (($a[1] -gt $y) -ne ($b[1] -gt $y)) {
            if ($x -lt ($b[0]-$a[0])*($y-$a[1])/($b[1]-$a[1])+$a[0]) { $inside = -not $inside }
        }
    }
    return $inside
}
function Format-Number($value) { return ([double]$value).ToString('0.########',[System.Globalization.CultureInfo]::InvariantCulture) }
function Format-Vector($value, [string]$type='Vector2') { return "$type($(Format-Number $value[0]), $(Format-Number $value[1]))" }
if ($null -eq $geometry.grid_size -or $geometry.grid_size.Count -ne 2 -or $geometry.grid_size[0] -lt 2 -or $geometry.grid_size[1] -lt 2) { throw 'grid_size must explicitly provide at least two columns and rows.' }
foreach ($field in @('grid_origin','axis_x','axis_y','image_size')) {
    if ($null -eq $geometry.$field -or $geometry.$field.Count -ne 2) { throw "Missing two-component $field." }
}
$determinant=$geometry.axis_x[0]*$geometry.axis_y[1]-$geometry.axis_x[1]*$geometry.axis_y[0]
if ([Math]::Abs($determinant) -lt 0.000001) { throw 'Grid axes must be independent.' }
Set-GeometryProperty 'tile_footprint' @(([Math]::Abs($geometry.axis_x[0])+[Math]::Abs($geometry.axis_y[0])),([Math]::Abs($geometry.axis_x[1])+[Math]::Abs($geometry.axis_y[1])))
foreach ($field in @('corner_cuts','pits','obstacles','hero_spawns','enemy_spawns')) {
    if ($null -eq $geometry.PSObject.Properties[$field]) { Set-GeometryProperty $field @() }
}
foreach ($field in @('image_offset','camera_offset')) { if ($null -eq $geometry.PSObject.Properties[$field]) { Set-GeometryProperty $field @(0,0) } }
if ($null -eq $geometry.PSObject.Properties['image_scale']) { Set-GeometryProperty 'image_scale' @(1,1) }
if ($null -eq $geometry.PSObject.Properties['camera_zoom']) { Set-GeometryProperty 'camera_zoom' 1.0 }
$voidKeys = @{}
foreach ($coordinate in $geometry.corner_cuts) { $voidKeys["$($coordinate[0]),$($coordinate[1])"] = $true }
foreach ($pit in $geometry.pits) { foreach ($coordinate in $pit.cells) { $voidKeys["$($coordinate[0]),$($coordinate[1])"] = $true } }
$explicitFloor = $null -ne $geometry.PSObject.Properties['floor_cells']
$hasContour = $null -ne $geometry.PSObject.Properties['floor_contour_grid']
if ($explicitFloor -and $hasContour) { throw 'Use floor_cells or floor_contour_grid, not both.' }
if ($hasContour -and $geometry.floor_contour_grid.Count -lt 3) { throw 'floor_contour_grid needs at least three coefficient-space vertices.' }
$floorKeys = @{}
if ($explicitFloor) {
    foreach ($coordinate in $geometry.floor_cells) {
        if ($coordinate.Count -ne 2 -or $coordinate[0] -ne [int]$coordinate[0] -or $coordinate[1] -ne [int]$coordinate[1]) { throw 'floor_cells requires integer coordinate pairs.' }
        $x=[int]$coordinate[0];$y=[int]$coordinate[1];$key="$x,$y"
        if ($x -lt 0 -or $y -lt 0 -or $x -ge $geometry.grid_size[0] -or $y -ge $geometry.grid_size[1]) { throw "Floor cell outside grid_size: $key" }
        if ($floorKeys.ContainsKey($key) -or $voidKeys.ContainsKey($key)) { throw "Duplicate floor cell or floor/void conflict: $key" }
        $floorKeys[$key]=$true
    }
}
$rows = @()
$cells = @()
for ($yy=0; $yy -lt $geometry.grid_size[1]; $yy++) {
    $row = ''
    for ($xx=0; $xx -lt $geometry.grid_size[0]; $xx++) {
        $cx = $geometry.grid_origin[0] + $geometry.axis_x[0]*$xx + $geometry.axis_y[0]*$yy
        $cy = $geometry.grid_origin[1] + $geometry.axis_x[1]*$xx + $geometry.axis_y[1]*$yy
        $halfX = $geometry.tile_footprint[0]/2
        $halfY = $geometry.tile_footprint[1]/2
        $key="$xx,$yy"
        $rendered = if ($explicitFloor) { $floorKeys.ContainsKey($key) } elseif ($hasContour) { (Test-ContourPoint $xx $yy $geometry.floor_contour_grid) -and -not $voidKeys.ContainsKey($key) } else { -not $voidKeys.ContainsKey($key) }
        $polygon=@()
        foreach ($corner in @(@(-0.5,-0.5),@(0.5,-0.5),@(0.5,0.5),@(-0.5,0.5))) {
            $polygon+=,@(($cx+$corner[0]*$geometry.axis_x[0]+$corner[1]*$geometry.axis_y[0]),($cy+$corner[0]*$geometry.axis_x[1]+$corner[1]*$geometry.axis_y[1]))
        }
        $row += $(if ($rendered) {'.'} else {'X'})
        $cells += [ordered]@{
            cell=@($xx,$yy); center_px=@($cx,$cy)
            polygon_px=$polygon
            floor_rendered=$rendered
        }
    }
    $rows += $row
}
Set-GeometryProperty 'cells' $cells
Set-GeometryProperty 'ascii_rows' $rows
Set-GeometryProperty 'expected_floor_count' @($cells | Where-Object {$_.floor_rendered}).Count
$walkable = @{}
foreach ($entry in $cells) { if ($entry.floor_rendered) { $walkable["$($entry.cell[0]),$($entry.cell[1])"]=$true } }
foreach ($obstacle in $geometry.obstacles) {
    foreach ($coordinate in $obstacle.cells) {
        $key = "$($coordinate[0]),$($coordinate[1])"
        if (-not $walkable.ContainsKey($key)) { throw "Obstacle is outside the floor or duplicates another: $key" }
        $walkable.Remove($key)
    }
}
foreach ($camp in @('hero_spawns','enemy_spawns')) {
    foreach ($coordinate in $geometry.$camp) {
        if (-not $walkable.ContainsKey("$($coordinate[0]),$($coordinate[1])")) { throw "Illegal spawn: $coordinate" }
    }
}
if ($geometry.hero_spawns.Count -lt 1) { throw 'At least one legal hero spawn is required.' }
$queue = [System.Collections.Generic.Queue[string]]::new()
$visited = @{}
$firstSpawn = $geometry.hero_spawns[0]
$start = "$($firstSpawn[0]),$($firstSpawn[1])"
$queue.Enqueue($start)
$visited[$start]=$true
while ($queue.Count -gt 0) {
    $point = $queue.Dequeue().Split(',')
    foreach ($step in @(@(-1,0),@(1,0),@(0,-1),@(0,1))) {
        $next = "$([int]$point[0]+$step[0]),$([int]$point[1]+$step[1])"
        if ($walkable.ContainsKey($next) -and -not $visited.ContainsKey($next)) { $visited[$next]=$true; $queue.Enqueue($next) }
    }
}
if ($visited.Count -ne $walkable.Count) { throw 'The playable floor is disconnected.' }
$anchors = if ($null -ne $geometry.PSObject.Properties['calibration_cells']) { @($geometry.calibration_cells) } else { @(@(0,0),@(($geometry.grid_size[0]-1),0),@(0,($geometry.grid_size[1]-1)),@(($geometry.grid_size[0]-1),($geometry.grid_size[1]-1))) }
$anchorKeys=@{};$anchorPixels=@()
foreach ($cell in $anchors) {
    $key="$($cell[0]),$($cell[1])"
    if ($cell[0] -lt 0 -or $cell[1] -lt 0 -or $cell[0] -ge $geometry.grid_size[0] -or $cell[1] -ge $geometry.grid_size[1] -or $anchorKeys.ContainsKey($key)) { throw "Invalid or duplicate calibration anchor: $key" }
    $anchorKeys[$key]=$true
    $anchorPixels+=,@(($geometry.grid_origin[0]+$cell[0]*$geometry.axis_x[0]+$cell[1]*$geometry.axis_y[0]),($geometry.grid_origin[1]+$cell[0]*$geometry.axis_x[1]+$cell[1]*$geometry.axis_y[1]))
}
if ($anchors.Count -lt 3) { throw 'At least three calibration anchors are required.' }
Set-GeometryProperty 'calibration_cells' $anchors
Set-GeometryProperty 'calibration_pixels' $anchorPixels
Set-GeometryProperty 'expected_void_count' ($geometry.grid_size[0]*$geometry.grid_size[1]-$geometry.expected_floor_count)
if ($ValidateOnly) {
    [ordered]@{valid=$true;grid_size=$geometry.grid_size;grid_origin=$geometry.grid_origin;axis_x=$geometry.axis_x;axis_y=$geometry.axis_y;tile_footprint=$geometry.tile_footprint;floor_cells=$geometry.expected_floor_count;void_cells=$geometry.expected_void_count;connected_walkable=$visited.Count;calibration_cells=$anchors;calibration_pixels=$anchorPixels} | ConvertTo-Json -Depth 6
    return
}
$arenaText = Get-Content -LiteralPath $arenaPath -Raw
$preamble = $arenaText.Substring(0,$arenaText.IndexOf('[sub_resource'))
$mainResource = [regex]::Match($arenaText,'(?ms)^\[resource\].*').Value
$mainResource = [regex]::Replace($mainResource,'(?m)^(cells|obstacles|decorations|spawns) = .*\r?\n?','')
# Replace every author-controlled affine field, including native anchor pixels.
function Set-ArenaLine([string]$name,[string]$value) {
    $pattern='(?m)^'+[regex]::Escape($name)+' = .*\r?\n?'
    if ([regex]::IsMatch($script:mainResource,$pattern)) { $script:mainResource=[regex]::Replace($script:mainResource,$pattern,"$name = $value`n") }
    else { $script:mainResource += "$name = $value`n" }
}
Set-ArenaLine 'source_image_size' (Format-Vector $geometry.image_size 'Vector2i')
if ($null -ne $geometry.PSObject.Properties['background_path']) { Set-ArenaLine 'background_path' ('"'+$geometry.background_path+'"') }
Set-ArenaLine 'grid_size' (Format-Vector $geometry.grid_size 'Vector2i')
foreach ($field in @('grid_origin','axis_x','axis_y','image_offset','image_scale','camera_offset')) { Set-ArenaLine $field (Format-Vector $geometry.$field) }
Set-ArenaLine 'camera_zoom' (Format-Number $geometry.camera_zoom)
Set-ArenaLine 'calibration_cells' ('Array[Vector2i](['+(($anchors | ForEach-Object { Format-Vector $_ 'Vector2i' }) -join ', ')+'])')
Set-ArenaLine 'calibration_pixels' ('Array[Vector2](['+(($anchorPixels | ForEach-Object { Format-Vector $_ }) -join ', ')+'])')
$blocks = [System.Collections.Generic.List[string]]::new()
$blocks.Add("[sub_resource type=`"Resource`" id=`"ModularProfile`"]`nscript = ExtResource(`"3_modular`")`ntheme_id = &`"forest`"`nhybrid_floor_policy = 2`nbase_terrain_id = &`"stone`"")
$cellRefs = [System.Collections.Generic.List[string]]::new()
$obstacleRefs = [System.Collections.Generic.List[string]]::new()
$decorationRefs = [System.Collections.Generic.List[string]]::new()
$spawnRefs = [System.Collections.Generic.List[string]]::new()
foreach ($entry in $cells) {
    if (-not $entry.floor_rendered) { continue }
    $xx=$entry.cell[0]; $yy=$entry.cell[1]; $id="Cell_${xx}_${yy}"
    $cellRefs.Add("SubResource(`"$id`")")
    $blocks.Add("[sub_resource type=`"Resource`" id=`"$id`"]`nscript = ExtResource(`"2_cell`")`ncoordinate = Vector2i($xx, $yy)`nterrain_id = &`"stone`"")
}
foreach ($obstacle in $geometry.obstacles) {
    foreach ($coordinate in $obstacle.cells) {
        $xx=$coordinate[0]; $yy=$coordinate[1]; $id="Obstacle_${xx}_${yy}"; $decorId="Decor_${xx}_${yy}"
        $vision=if($obstacle.blocks_sight){'true'}else{'false'}
        $preset=if($obstacle.blocks_sight){0}else{1}
        $sceneName=if($obstacle.id -eq 'west_column'){'BrokenColumn'}elseif($obstacle.id -eq 'eastern_bench'){'TempleBenchSection'}else{'LimestonePlinth'}
        $scenePath=if($null -ne $obstacle.PSObject.Properties['scene_path'] -and $obstacle.scene_path -ne ''){$obstacle.scene_path}elseif($null -ne $obstacle.PSObject.Properties['prop_scene'] -and $obstacle.prop_scene -ne ''){$obstacle.prop_scene}else{"res://tools/labs/greek_drawn_arena/$sceneName.tscn"}
        $obstacleRefs.Add("SubResource(`"$id`")")
        $blocks.Add("[sub_resource type=`"Resource`" id=`"$id`"]`nscript = ExtResource(`"4_obstacle`")`nobstacle_id = &`"$($obstacle.id)_${xx}_${yy}`"`ncell = Vector2i($xx, $yy)`npreset = $preset`nblocks_line_of_sight = $vision`nblocks_projectiles = $vision")
        $decorationRefs.Add("SubResource(`"$decorId`")")
        $blocks.Add("[sub_resource type=`"Resource`" id=`"$decorId`"]`nscript = ExtResource(`"6_decoration`")`ndecoration_id = &`"$($obstacle.id)_${xx}_${yy}`"`nscene_path = `"$scenePath`"`ncell = Vector2i($xx, $yy)`nlayer = &`"y_sorted_props`"")
    }
}
$counter=0
foreach ($camp in @('hero_spawns','enemy_spawns')) {
    foreach ($coordinate in $geometry.$camp) {
        $xx=$coordinate[0]; $yy=$coordinate[1]; $id="Spawn_$counter"; $kind=if($camp -eq 'hero_spawns'){0}else{3}
        $spawnRefs.Add("SubResource(`"$id`")")
        $blocks.Add("[sub_resource type=`"Resource`" id=`"$id`"]`nscript = ExtResource(`"5_spawn`")`nspawn_id = &`"$id`"`nkind = $kind`ncell = Vector2i($xx, $yy)")
        $counter++
    }
}
$mainResource += 'cells = Array[ExtResource("2_cell")](['+($cellRefs -join ', ')+'])'+"`n"
$mainResource += 'obstacles = Array[ExtResource("4_obstacle")](['+($obstacleRefs -join ', ')+'])'+"`n"
$mainResource += 'decorations = Array[ExtResource("6_decoration")](['+($decorationRefs -join ', ')+'])'+"`n"
$mainResource += 'spawns = Array[ExtResource("5_spawn")](['+($spawnRefs -join ', ')+'])'+"`n"
$steps = [regex]::Matches($preamble,'\[ext_resource ').Count+$blocks.Count+1
$preamble = [regex]::Replace($preamble,'load_steps=\d+',"load_steps=$steps")
($preamble+($blocks -join "`n`n")+"`n`n"+$mainResource) | Set-Content -LiteralPath $arenaPath -Encoding utf8
$geometry | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $manifestPath -Encoding utf8
Add-Type -AssemblyName System.Drawing
$bmp=[System.Drawing.Bitmap]::new([int]$geometry.image_size[0],[int]$geometry.image_size[1])
$gfx=[System.Drawing.Graphics]::FromImage($bmp)
$gfx.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$gfx.Clear([System.Drawing.ColorTranslator]::FromHtml('#b7d5cc'))
$svg=[System.Collections.Generic.List[string]]::new()
$svg.Add("<svg xmlns='http://www.w3.org/2000/svg' width='$($geometry.image_size[0])' height='$($geometry.image_size[1])' viewBox='0 0 $($geometry.image_size[0]) $($geometry.image_size[1])'><rect width='$($geometry.image_size[0])' height='$($geometry.image_size[1])' fill='#b7d5cc'/>")
$colors=@{}
foreach($entry in $cells){if($entry.floor_rendered){$colors["$($entry.cell[0]),$($entry.cell[1])"]='#ede6cb'}}
foreach($pit in $geometry.pits){foreach($c in $pit.cells){$colors["$($c[0]),$($c[1])"]='#253538'}}
foreach($block in $geometry.obstacles){foreach($c in $block.cells){$colors["$($c[0]),$($c[1])"]='#cd9566'}}
$pen=[System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml('#68795e'),1.4)
foreach($entry in $cells){
    $key="$($entry.cell[0]),$($entry.cell[1])"; if(-not $colors.ContainsKey($key)){continue}; $color=$colors[$key]
    $pointString=($entry.polygon_px | ForEach-Object{"$($_[0]),$($_[1])"}) -join ' '
    $svg.Add("<polygon points='$pointString' fill='$color' stroke='#68795e' stroke-width='1.4'/>")
    [System.Drawing.PointF[]]$points=@($entry.polygon_px | ForEach-Object{[System.Drawing.PointF]::new([float]$_[0],[float]$_[1])})
    $brush=[System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($color))
    $gfx.FillPolygon($brush,$points)
    $gfx.DrawPolygon($pen,$points)
    $brush.Dispose()
}
$svg.Add('</svg>')
$svg -join "`n" | Set-Content -LiteralPath (Join-Path $arenaRoot 'grid_reference.svg') -Encoding utf8
$bmp.Save((Join-Path $arenaRoot 'grid_reference.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$gfx.Dispose()
$bmp.Dispose()
$pen.Dispose()
Write-Output "Geometry synchronized: $($cellRefs.Count) floor tiles; $($geometry.expected_void_count) void cells; $($obstacleRefs.Count) blockers; $($visited.Count)/$($walkable.Count) connected walkable cells."



