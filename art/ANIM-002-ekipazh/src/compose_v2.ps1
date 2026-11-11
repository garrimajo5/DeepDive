Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationCore
$p=Join-Path (Split-Path $PSScriptRoot -Parent) 'v2'
$font=New-Object Drawing.Font 'Arial',16
function Sheet($names,$labels,$cols,$out) {
 $rows=[int][Math]::Ceiling($names.Count/$cols);$bmp=New-Object Drawing.Bitmap ($cols*440),($rows*550);$g=[Drawing.Graphics]::FromImage($bmp);$g.Clear([Drawing.Color]::FromArgb(16,26,34))
 for($i=0;$i -lt $names.Count;$i++) { $x=($i%$cols)*440;$y=[int][Math]::Floor($i/$cols)*550;$im=[Drawing.Image]::FromFile((Join-Path $p ('renders/'+$names[$i]+'.png')));$g.DrawImage($im,$x,($y+30),440,520);$im.Dispose();if($names[$i] -like "*-rest-*"){$pen=New-Object Drawing.Pen ([Drawing.Color]::LightBlue),2;$g.DrawLine($pen,($x+25),($y+73),($x+25),($y+507));foreach($h in @(0,0.6,1.2,1.8)){$yy=$y+507-$h/1.8*434;$g.DrawLine($pen,($x+20),$yy,($x+30),$yy)};$pen.Dispose()};$g.DrawString($labels[$i],$font,[Drawing.Brushes]::White,$x+8,$y+3) }
 $bmp.Save((Join-Path $p $out),[Drawing.Imaging.ImageFormat]::Jpeg);$g.Dispose();$bmp.Dispose()
}
$names=@();$labels=@();foreach($sex in @('muzhchina','zhenshchina')){foreach($view in @('front','side','back')){$names+="$sex-rest-$view";$labels+="$sex — $view — 1,8 м"}}
Sheet $names $labels 3 '01-preview.jpg'
foreach($clip in @('Idle','Walk','SitIdle','PostIdle')){
 $n=120;if($clip -eq 'Walk'){$n=24};$names=@();$labels=@()
 foreach($sex in @('muzhchina','zhenshchina')){foreach($view in @('three','side')){for($k=0;$k -lt 4;$k++){$frame=$k*$n/4;$names+="$sex-$clip-$frame-$view";$labels+="$clip / $sex / $($k*25)%"}}}
 Sheet $names $labels 4 "02-phases-$clip.jpg"
}
$names=@();$labels=@();foreach($sex in @('muzhchina','zhenshchina')){foreach($role in @('engineer','biologist')){foreach($version in @('before','after')){$names+="$sex-$role-$version";$labels+="$sex / $role / $version"}}}
Sheet $names $labels 4 '03-gear-before-after.jpg'
foreach($clip in @('Walk','Idle')){
 $enc=New-Object Windows.Media.Imaging.GifBitmapEncoder;$n=24;$step=1;$delay=3;if($clip -eq 'Idle'){$n=120;$step=6;$delay=20}
 for($f=0;$f -lt $n;$f+=$step){
  $bmp=New-Object Drawing.Bitmap 440,260;$g=[Drawing.Graphics]::FromImage($bmp);$col=0
  foreach($sex in @('muzhchina','zhenshchina')){$im=[Drawing.Image]::FromFile((Join-Path $p "renders/$sex-$clip-$f-three.png"));$g.DrawImage($im,($col*220),0,220,260);$im.Dispose();$col++}
  $mem=New-Object IO.MemoryStream;$bmp.Save($mem,[Drawing.Imaging.ImageFormat]::Png);$mem.Position=0;$image=New-Object Windows.Media.Imaging.BitmapImage;$image.BeginInit();$image.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad;$image.StreamSource=$mem;$image.EndInit();$mem.Dispose();$g.Dispose();$bmp.Dispose()
  $meta=New-Object Windows.Media.Imaging.BitmapMetadata 'gif';$d=$delay;if($clip -eq 'Walk' -and $f%3 -eq 2){$d=4};$meta.SetQuery('/grctlext/Delay',[uint16]$d);$meta.SetQuery('/grctlext/Disposal',[byte]2);$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($image,$null,$meta,$null))
 }
 $stream=[IO.File]::Create((Join-Path $p "$clip.gif"));$enc.Save($stream);$stream.Close()
}
$font.Dispose()

