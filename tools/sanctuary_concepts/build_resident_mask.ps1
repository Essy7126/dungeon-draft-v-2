param([string]$ProjectPath = (Resolve-Path "$PSScriptRoot/../..").Path)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$maskReferences = @(Get-ChildItem -LiteralPath (Join-Path $PSHOME 'ref') -Filter '*.dll' | Where-Object { $_.Name -notlike 'System.Drawing*' } | Select-Object -ExpandProperty FullName) + @([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -match '^(System.Drawing|System.Private.Windows)' } | Select-Object -ExpandProperty Location)
Add-Type -ReferencedAssemblies $maskReferences -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class SanctuaryResidentMask {
  public static string Build(string source, string output) {
    using(var original = new Bitmap(source))
    using(var bitmap = new Bitmap(original.Width, original.Height, PixelFormat.Format32bppArgb)) {
      using(var g = Graphics.FromImage(bitmap)) g.DrawImageUnscaled(original,0,0);
      int w=bitmap.Width,h=bitmap.Height,n=w*h;
      var rect=new Rectangle(0,0,w,h);
      var locked=bitmap.LockBits(rect,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
      var rgba=new byte[n*4]; Marshal.Copy(locked.Scan0,rgba,0,rgba.Length); bitmap.UnlockBits(locked);
      var outside=new bool[n]; var queue=new int[n]; int begin=0,end=0;
      Action<int> enqueue = i => {
        if(outside[i]) return;
        int b=rgba[i*4],g=rgba[i*4+1],r=rgba[i*4+2];
        int lo=Math.Min(r,Math.Min(g,b)),hi=Math.Max(r,Math.Max(g,b));
        if(lo<210 || hi-lo>20) return;
        outside[i]=true; queue[end++]=i;
      };
      for(int x=0;x<w;x++){enqueue(x);enqueue((h-1)*w+x);}
      for(int y=0;y<h;y++){enqueue(y*w);enqueue(y*w+w-1);}
      while(begin<end){int i=queue[begin++],x=i%w,y=i/w;
        if(x>0)enqueue(i-1);if(x<w-1)enqueue(i+1);if(y>0)enqueue(i-w);if(y<h-1)enqueue(i+w);
      }
      var result=new byte[n*4];
      int[] minX={w,w},minY={h,h},maxX={0,0},maxY={0,0};
      for(int i=0;i<n;i++){
        byte value=outside[i]?(byte)0:(byte)255;
        result[i*4]=value;result[i*4+1]=value;result[i*4+2]=value;result[i*4+3]=255;
        if(!outside[i]){int x=i%w,y=i/w,k=x<w/2?0:1;minX[k]=Math.Min(minX[k],x);maxX[k]=Math.Max(maxX[k],x);minY[k]=Math.Min(minY[k],y);maxY[k]=Math.Max(maxY[k],y);}
      }
      using(var mask=new Bitmap(w,h,PixelFormat.Format32bppArgb)){
        var data=mask.LockBits(rect,ImageLockMode.WriteOnly,PixelFormat.Format32bppArgb);
        Marshal.Copy(result,0,data.Scan0,result.Length);mask.UnlockBits(data);mask.Save(output,ImageFormat.Png);
      }
      return String.Format("{{\"native_size\":[{0},{1}],\"background_pixels\":{2},\"bounds\":[[{3},{4},{5},{6}],[{7},{8},{9},{10}]]}}",w,h,end,minX[0],minY[0],maxX[0],maxY[0],minX[1],minY[1],maxX[1],maxY[1]);
    }
  }
}
'@
$sourcePath = Join-Path $ProjectPath 'meshy_output/20260907_195221_sanctuary-residents_01a07cff/residents.png'
$assetPath = Join-Path $ProjectPath 'asset/hub/sanctuary_prototype'
Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $assetPath 'residents.png')
$result = [SanctuaryResidentMask]::Build($sourcePath, (Join-Path $assetPath 'residents_mask.png'))
Set-Content -LiteralPath (Join-Path $assetPath 'residents_mask_metadata.json') -Value $result -Encoding utf8
Write-Output $result
