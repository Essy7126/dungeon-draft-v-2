param(
    [string]$ImagePath,
    [string]$ManifestPath,
    [string]$OutputPath
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if (-not ('TerrainSupportDistance' -as [type])) {
Add-Type -TypeDefinition @'
using System;



public class TerrainSupportDistance {
    public static float[] Measure(byte[] pixels, int w, int h, int stride, double[] points) { float[] d=new float[w*h]; int count=0;
            for(int y=0;y<h;y++) for(int x=0;x<w;x++) {
                int p=y*stride+x*4;
                int b=pixels[p],g=pixels[p+1],r=pixels[p+2];
                bool water=(g-r>18 && b-r>15 && b<g*1.10 && g>60);
                d[y*w+x]=water ? 0 : 100000;
                if(water) count++;
            }
            float diag=1.41421356f;
            for(int y=0;y<h;y++) for(int x=0;x<w;x++) {
                int i=y*w+x; float v=d[i];
                if(x>0)v=Math.Min(v,d[i-1]+1);
                if(y>0)v=Math.Min(v,d[i-w]+1);
                if(x>0&&y>0)v=Math.Min(v,d[i-w-1]+diag);
                if(x+1<w&&y>0)v=Math.Min(v,d[i-w+1]+diag);
                d[i]=v;
            }
            for(int y=h-1;y>=0;y--) for(int x=w-1;x>=0;x--) {
                int i=y*w+x; float v=d[i];
                if(x+1<w)v=Math.Min(v,d[i+1]+1);
                if(y+1<h)v=Math.Min(v,d[i+w]+1);
                if(x+1<w&&y+1<h)v=Math.Min(v,d[i+w+1]+diag);
                if(x>0&&y+1<h)v=Math.Min(v,d[i+w-1]+diag);
                d[i]=v;
            }
            float[] result=new float[points.Length/2+1];
            result[0]=count;
            for(int k=0;k<points.Length;k+=2){
                int x=(int)Math.Round(points[k]),y=(int)Math.Round(points[k+1]);
                result[k/2+1]=(x<0||x>=w||y<0||y>=h)?-1:d[y*w+x];
            }
            return result; } }
'@
}
$sourceBitmap = [Drawing.Bitmap]::new($ImagePath)
$imageWidth=$sourceBitmap.Width; $imageHeight=$sourceBitmap.Height
$imageBounds=[Drawing.Rectangle]::new(0,0,$imageWidth,$imageHeight)
$locked=$sourceBitmap.LockBits($imageBounds,[Drawing.Imaging.ImageLockMode]::ReadOnly,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
$pixelStride=[Math]::Abs($locked.Stride)
$pixelBytes=[byte[]]::new($pixelStride*$imageHeight)
[Runtime.InteropServices.Marshal]::Copy($locked.Scan0,$pixelBytes,0,$pixelBytes.Length)
$sourceBitmap.UnlockBits($locked)
$sourceBitmap.Dispose()
$geometry=Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$floor=@{}
foreach($cell in $geometry.cells){if($cell.floor_rendered){$floor["$($cell.cell[0]),$($cell.cell[1])"]=$true}}
$pits=@{}
foreach($pit in $geometry.pits){foreach($cell in $pit.cells){$pits["$($cell[0]),$($cell[1])"]=$true}}
$directions=@(@(0,-1),@(1,0),@(0,1),@(-1,0))
$corners=@(@(-0.5,-0.5),@(0.5,-0.5),@(0.5,0.5),@(-0.5,0.5))
$cases=@(
    @{name='current_108'; origin=@(960,130); ax=@(54,27); ay=@(-54,27)},
    @{name='candidate_96'; origin=@(960,170); ax=@(48,24); ay=@(-48,24)},
    @{name='candidate_100'; origin=@(960,165); ax=@(50,25); ay=@(-50,25)}
)
$results=@()
foreach($case in $cases){
    $coordinates=[Collections.Generic.List[double]]::new()
    $samples=@()
    foreach($entry in $geometry.cells){
        if(-not $entry.floor_rendered){continue}
        $x=[int]$entry.cell[0];$y=[int]$entry.cell[1]
        for($edge=0;$edge-lt4;$edge++){
            $n="$($x+$directions[$edge][0]),$($y+$directions[$edge][1])"
            if($floor.ContainsKey($n) -or $pits.ContainsKey($n)){continue}
            $a=$corners[$edge];$b=$corners[($edge+1)%4]
            for($sample=0;$sample-le16;$sample++){
                $t=$sample/16.0
                $u=$x+$a[0]*(1-$t)+$b[0]*$t
                $v=$y+$a[1]*(1-$t)+$b[1]*$t
                $px=$case.origin[0]+$u*$case.ax[0]+$v*$case.ay[0]
                $py=$case.origin[1]+$u*$case.ax[1]+$v*$case.ay[1]
                $coordinates.Add($px);$coordinates.Add($py)
                $samples+=@{cell=@($x,$y);edge=$edge;point=@($px,$py)}
            }
        }
    }
    $distances=[TerrainSupportDistance]::Measure($pixelBytes,$imageWidth,$imageHeight,$pixelStride,$coordinates.ToArray())
    $minimum=[double]::PositiveInfinity;$nearest=$null;$belowHalfTile=0
    for($i=0;$i-lt$samples.Count;$i++){
        $distance=$distances[$i+1]
        if($distance-lt$minimum){$minimum=$distance;$nearest=$samples[$i]}
        if($distance-lt[double]$case.ax[0]){$belowHalfTile++}
    }
    $results+=@{name=$case.name;origin=$case.origin;axis_x=$case.ax;axis_y=$case.ay;water_pixel_count=$distances[0];sampled_outer_edge_points=$samples.Count;minimum_approx_water_distance_px=$minimum;nearest=$nearest;samples_closer_than_half_tile_width=$belowHalfTile}
}
$report=@{method='Color-classified turquoise water; 8-neighbour chamfer distance, diagnostic only, not runtime collisions';image=$ImagePath;manifest=$ManifestPath;cases=$results}
$report|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $OutputPath -Encoding utf8
$report|ConvertTo-Json -Depth 8
