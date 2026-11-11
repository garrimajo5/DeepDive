Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationCore
$p=Split-Path $PSScriptRoot -Parent
function Sheet($names,$labels,$out) {
 $bmp=New-Object Drawing.Bitmap (640*$names.Count),530
 $g=[Drawing.Graphics]::FromImage($bmp);$g.Clear([Drawing.Color]::FromArgb(32,36,42))
 $font=New-Object Drawing.Font 'Arial',16
 for($i=0;$i -lt $names.Count;$i++) {
  $im=[Drawing.Image]::FromFile((Join-Path $p ('renders/'+$names[$i]+'.png')))
  $g.DrawImage($im,640*$i,35,640,480);$im.Dispose()
  $g.DrawString($labels[$i],$font,[Drawing.Brushes]::White,640*$i+15,5)
 }
 $g.DrawString('Линейка: 1 м', $font,[Drawing.Brushes]::White,15,500)
 $bmp.Save((Join-Path $p $out),[Drawing.Imaging.ImageFormat]::Jpeg);$g.Dispose();$bmp.Dispose();$font.Dispose()
}
Sheet @('preview-front','preview-side','preview-top') @('Спереди','Сбоку','Сверху') '01-preview.jpg'
foreach($clip in @('Idle','Swim','OpenPetal')) { Sheet @("$clip-0","$clip-1","$clip-2","$clip-3") @("$clip — 0%","$clip — 25%","$clip — 50%","$clip — 75%") "$clip-phases.jpg" }
$enc=New-Object Windows.Media.Imaging.GifBitmapEncoder
for($i=0;$i -lt 31;$i++) {
 $uri=New-Object Uri (Join-Path $p ('renders/gif-{0:d2}.png' -f $i))
 $im=New-Object Windows.Media.Imaging.BitmapImage $uri
 $meta=New-Object Windows.Media.Imaging.BitmapMetadata 'gif'
 $meta.SetQuery('/grctlext/Delay',[uint16]17)
 $meta.SetQuery('/grctlext/Disposal',[byte]2)
 $frame=[Windows.Media.Imaging.BitmapFrame]::Create($im,$null,$meta,$null);$enc.Frames.Add($frame)
}
$stream=[IO.File]::Create((Join-Path $p 'OpenPetal.gif'));$enc.Save($stream);$stream.Close()
$im=[Drawing.Image]::FromFile((Join-Path $p 'renders/stress60.png'))
$im.Save((Join-Path $p 'stress60.jpg'),[Drawing.Imaging.ImageFormat]::Jpeg)
$im.Dispose()
