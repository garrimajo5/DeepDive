param([string]$Source)
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
public class Maps083 {
public static void Run(string src,string dir){
using(var original=new Bitmap(src)){
// Preserve full vertical UV, remove empty horizontal canvas only.
int left=original.Width,right=0;
for(int y=0;y<original.Height;y++) for(int x=0;x<original.Width;x++)
if(original.GetPixel(x,y).A>32){left=Math.Min(left,x);right=Math.Max(right,x);}
int margin=8; left=Math.Max(0,left-margin);right=Math.Min(original.Width-1,right+margin);
using(var color=new Bitmap(256,1024,PixelFormat.Format32bppArgb)){
using(var g=Graphics.FromImage(color)){
g.CompositingMode=CompositingMode.SourceCopy;
g.InterpolationMode=InterpolationMode.HighQualityBicubic;
g.DrawImage(original,new Rectangle(0,0,256,1024),new Rectangle(left,0,right-left+1,original.Height),GraphicsUnit.Pixel);
}
double[,] a=new double[256,1024], h=new double[256,1024];
double[] centers=new double[1024], widths=new double[1024];
for(int y=0;y<1024;y++){
int lo=256,hi=-1;
for(int x=0;x<256;x++){a[x,y]=color.GetPixel(x,y).A/255.0;if(a[x,y]>.25){lo=Math.Min(lo,x);hi=Math.Max(hi,x);}}
centers[y]=hi>=lo?(lo+hi)*.5:128; widths[y]=Math.Max(1,(hi-lo)*.5);
}
using(var mask=new Bitmap(256,1024,PixelFormat.Format24bppRgb))
using(var normal=new Bitmap(256,1024,PixelFormat.Format24bppRgb)){
for(int y=0;y<1024;y++)for(int x=0;x<256;x++){
double d=(x-centers[y])/widths[y], ridge=Math.Sqrt(Math.Max(0,1-d*d));
double slit=Math.Exp(-Math.Pow((x-centers[y])/3.0,2));
h[x,y]=a[x,y]*(widths[y]*.13*ridge-1.8*slit);
double node=Math.Min(1,Math.Max(0,(widths[y]-20)/65));
int m=(int)(255*Math.Min(1,(.10+.55*node)*ridge+.45*slit)*a[x,y]);
mask.SetPixel(x,y,Color.FromArgb(m,m,m));
Color c=color.GetPixel(x,y);
// Straight-alpha RGB bleed; no dark matte in fully transparent texels.
if(c.A<4)c=Color.FromArgb(c.A,134,188,203);
color.SetPixel(x,y,Color.FromArgb((int)(c.A*.80),c.R,c.G,c.B));
}
// Smooth scalar relief before differentiation; no color texture noise enters normals.
double[,] smooth=new double[256,1024];
for(int y=0;y<1024;y++)for(int x=0;x<256;x++){
double sum=0;int n=0;
for(int dy=-2;dy<=2;dy++)for(int dx=-2;dx<=2;dx++){sum+=h[Math.Max(0,Math.Min(255,x+dx)),Math.Max(0,Math.Min(1023,y+dy))];n++;}
smooth[x,y]=sum/n;
}
for(int y=0;y<1024;y++)for(int x=0;x<256;x++){
double nx=-(smooth[Math.Min(255,x+1),y]-smooth[Math.Max(0,x-1),y])*.5;
double ny=(smooth[x,Math.Min(1023,y+1)]-smooth[x,Math.Max(0,y-1)])*.5;
if(a[x,y]<.02){nx=0;ny=0;}
double norm=Math.Sqrt(nx*nx+ny*ny+1);
normal.SetPixel(x,y,Color.FromArgb((int)(127.5+127.5*nx/norm),(int)(127.5+127.5*ny/norm),(int)(127.5+127.5/norm)));
}
color.Save(dir+"/pryad-cvet.png",ImageFormat.Png);
mask.Save(dir+"/pryad-maska.png",ImageFormat.Png);
normal.Save(dir+"/pryad-normal.png",ImageFormat.Png);
using(var lit=new Bitmap(256,1024)){
for(int y=0;y<1024;y++)for(int x=0;x<256;x++){
var c=color.GetPixel(x,y);double m=mask.GetPixel(x,y).R/255.0;
lit.SetPixel(x,y,Color.FromArgb(c.A,Math.Min(255,c.R+(int)(103*m)),Math.Min(255,c.G+(int)(221*m)),Math.Min(255,c.B+(int)(235*m))));
}
using(var preview=new Bitmap(1600,1100))
using(var g=Graphics.FromImage(preview))
using(var font=new Font("Arial",22))
using(var small=new Font("Arial",15)){
g.Clear(Color.FromArgb(11,28,36));g.InterpolationMode=InterpolationMode.HighQualityBicubic;
g.DrawString("Инеевая бахрома · ART-083",font,Brushes.White,40,20);
g.DrawString("Без свечения",font,Brushes.LightBlue,70,75);
g.DrawString("Маска × #67DDEB · полная сила",font,Brushes.LightBlue,830,75);
float[] lengths={1f,.6f,.35f,.6f,1f};
for(int panel=0;panel<2;panel++)for(int i=0;i<5;i++){
int px=50+panel*780+i*140;int hh=(int)(850*lengths[i]);
g.DrawImage(panel==0?color:lit,new Rectangle(px,150,110,hh));
g.DrawString(lengths[i].ToString("0.##"),small,Brushes.LightBlue,px+35,1015);
}
g.DrawString("Доли длины: 1 / 0,6 / 0,35 · ширина увеличена для проверки карт · без bloom",small,Brushes.LightBlue,40,1060);
preview.Save(dir+"/preview.png",ImageFormat.Png);
}
}
}
}
}
}
}
"@
[Maps083]::Run($Source,(Resolve-Path "$PSScriptRoot/..").Path)
