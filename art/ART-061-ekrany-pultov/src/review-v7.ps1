# PowerShell 7. Review-only contact sheet and JPG export, no retouching.
param([string]$CaptureRoot)
Add-Type -AssemblyName System.Drawing
$root=Split-Path $PSScriptRoot -Parent
if(!$CaptureRoot){$CaptureRoot=$root}
$sheet=[Drawing.Bitmap]::new(960,1260)
$g=[Drawing.Graphics]::FromImage($sheet);$g.Clear([Drawing.Color]::FromArgb(20,30,35))
$f=[Drawing.Font]::new('Arial',16);$row=0
foreach($wheel in @('0','0.2','-0.2','0.4','-0.4','0.8','-0.8')){
 $col=0
 foreach($width in @(1600,2400)){
  $im=[Drawing.Bitmap]::new((Join-Path $CaptureRoot "v7-$width-$wheel-new.png"))
  $scale=$width/1600.0
  $src=[Drawing.RectangleF]::new([single](650*$scale),[single](490*$scale),[single](320*$scale),[single](120*$scale))
  $dst=[Drawing.RectangleF]::new($col*480,$row*180+25,480,150)
  $g.DrawImage($im,$dst,$src,[Drawing.GraphicsUnit]::Pixel)
  $g.DrawString("$width | $wheel",$f,[Drawing.Brushes]::White,$col*480,$row*180)
  $im.Dispose();$col++
 }
 $row++
}
$g.Dispose();$sheet.Save((Join-Path $root 'v7-review.png'));$sheet.Dispose();$f.Dispose()
$im=[Drawing.Bitmap]::new((Join-Path $CaptureRoot 'v7-1600-0-new.png'))
$im.Save((Join-Path $root 'ekran-kadr-v7.jpg'),[Drawing.Imaging.ImageFormat]::Jpeg);$im.Dispose()
