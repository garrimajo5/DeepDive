# PowerShell 7, System.Drawing. Existing code-native atlas glyph row is retained.
Add-Type -AssemblyName System.Drawing
$root=Split-Path $PSScriptRoot -Parent
$old=[Drawing.Bitmap]::new((Join-Path $root 'ekran-atlas.png'))
$im=[Drawing.Bitmap]::new(1024,512,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g=[Drawing.Graphics]::FromImage($im)
$g.Clear([Drawing.Color]::Transparent)
$g.DrawImageUnscaled($old,0,0)
$bg=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#0B1C24'))
$ink=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#67DDEB'))
$pen=[Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml('#315C68'),2)
$font=[Drawing.Font]::new('DejaVu Sans',18,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel)
$g.FillRectangle($bg,0,0,320,136)
$g.DrawRectangle($pen,1,1,317,133)
$g.DrawString('ХОД',$font,$ink,12,8)
$g.DrawLine($pen,12,105,308,105)
for($x=16;$x -le 304;$x+=12){$g.DrawLine($pen,$x,118,$x,126)}
$g.FillRectangle($bg,352,0,320,136)
$g.Dispose();$im.Save((Join-Path $root 'ekran-atlas-v7.png'),[Drawing.Imaging.ImageFormat]::Png)
$im.Dispose();$old.Dispose();$font.Dispose();$bg.Dispose();$ink.Dispose();$pen.Dispose()
