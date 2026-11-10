Add-Type -AssemblyName System.Drawing
$p = 'C:/Users/FEDYA/Documents/ChatGPT/Pogrujenie/work/model-schedule-20261107/art/MOD-022-kupolnik'
$b = New-Object Drawing.Bitmap 1024,1024
$g = [Drawing.Graphics]::FromImage($b)
$g.Clear([Drawing.Color]::FromArgb(9,20,29))
$g.SmoothingMode = 'AntiAlias'
$f = New-Object Drawing.Font 'Arial',17
$small = New-Object Drawing.Font 'Arial',13
$brush = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(205,229,235))
$bg = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(220,8,18,27))
$pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(103,221,235)),2
$panels = @(@('front',0,0,'Спереди · −Z',2.4,1),@('side',512,0,'Сбоку',3.5,1),@('top',0,512,'Сверху',3.4,1),@('wire',512,512,'Захват · 6 петель',1.05,0.25))
foreach($a in $panels){
 $im=[Drawing.Image]::FromFile("$p/panel-$($a[0]).png")
 $x=[int]$a[1];$y=[int]$a[2];$g.DrawImage($im,$x,$y,512,512);$im.Dispose()
 $g.FillRectangle($bg,$x+8,$y+8,330,33);$g.DrawString([string]$a[3],$f,$brush,$x+16,$y+12)
 $len=[single](512/[double]$a[4]*[double]$a[5]);$sx=$x+24;$sy=$y+472
 $g.DrawLine($pen,$sx,$sy,($sx+$len),$sy);$g.DrawLine($pen,$sx,($sy-6),$sx,($sy+6));$g.DrawLine($pen,($sx+$len),($sy-6),($sx+$len),($sy+6))
 $label=([string]$a[5]).Replace('.',',')+' м';$g.DrawString($label,$small,$brush,$sx,$sy+10)
}
$g.DrawLine($pen,512,0,512,1024);$g.DrawLine($pen,0,512,1024,512)
$b.Save("$p/preview.png",[Drawing.Imaging.ImageFormat]::Png)
$g.Dispose();$b.Dispose()
foreach($name in @('reference-front','reference-top-v2')){
 $im=[Drawing.Image]::FromFile("$p/$name.png");$im.Save("$p/$name.jpg",[Drawing.Imaging.ImageFormat]::Jpeg);$im.Dispose()
}
