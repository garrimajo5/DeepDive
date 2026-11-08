$ff='C:\Users\FEDYA\Documents\ChatGPT\Pogrujenie\output\snd001-test\deps\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe'
$root=Split-Path $PSScriptRoot -Parent
$filter='[0:a]asplit=3[h][m][t];[h]atrim=end_sample=4410,asetpts=PTS-STARTPTS,afade=t=in:ss=0:ns=4410[head];[t]atrim=start_sample=127890,asetpts=PTS-STARTPTS,afade=t=out:ss=0:ns=4410[tail];[tail][head]amix=inputs=2:duration=longest:normalize=0[seam];[m]atrim=start_sample=4410:end_sample=127890,asetpts=PTS-STARTPTS[mid];[mid][seam]concat=n=2:v=0:a=1[out]'
& $ff -v error -i "$root/source/scanner-hold-1.mp3" -filter_complex $filter -map '[out]' -ar 44100 -ac 2 -f s16le -y "$root/scan-rotate.pcm"
$b=[IO.File]::ReadAllBytes("$root/scan-rotate.pcm")
$best=1e20; $offset=0
for($i=4410;$i -lt $b.Length/4-4410;$i++){
 $cost=0.0
 foreach($j in -1,0,1){foreach($ch in 0,1){$v=[BitConverter]::ToInt16($b,($i+$j)*4+$ch*2);$cost+=[double]$v*$v}}
 if($cost -lt $best){$best=$cost;$offset=$i}
}
$filter2="[0:a]asplit=2[a][b];[a]atrim=start_sample=$offset,asetpts=PTS-STARTPTS[last];[b]atrim=end_sample=$offset,asetpts=PTS-STARTPTS[first];[last][first]concat=n=2:v=0:a=1,volume=-8.26dB[out]"
& $ff -v error -f s16le -ar 44100 -ac 2 -i "$root/scan-rotate.pcm" -filter_complex $filter2 -map '[out]' -ar 44100 -c:a libmp3lame -b:a 192k -y "$root/scanner-hold-1-rev3.mp3"
& $ff -v error -i "$root/scanner-hold-1-rev3.mp3" -f s16le -ar 44100 -ac 2 -y "$root/scan-final-check.pcm"
$c=[IO.File]::ReadAllBytes("$root/scan-final-check.pcm");$d=0.0
foreach($ch in 0,1){$d=[Math]::Max($d,[Math]::Abs(([double][BitConverter]::ToInt16($c,$ch*2)-[BitConverter]::ToInt16($c,$c.Length-4+$ch*2))/32768))}
@{rotation_sample=$offset;rotation_seconds=$offset/44100;boundary_dbfs=20*[Math]::Log10($d);seconds=$c.Length/176400} | ConvertTo-Json | Set-Content "$root/scanner-rotation.json" -Encoding UTF8
Remove-Item -LiteralPath "$root/scan-rotate.pcm","$root/scan-final-check.pcm"
Get-Content "$root/scanner-rotation.json"
