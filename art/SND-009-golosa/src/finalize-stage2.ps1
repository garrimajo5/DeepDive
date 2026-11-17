$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$ff='C:/Users/FEDYA/Documents/ChatGPT/Pogrujenie/output/snd001-test/deps/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
$ci=[Globalization.CultureInfo]::InvariantCulture
$rows=@(Get-Content "$root/stage2-20261116-technical.json" -Raw|ConvertFrom-Json)
$checks=Get-Content "$root/stage2-20261116-verification.json" -Raw|ConvertFrom-Json
foreach($v in $checks){
 $r=$rows|Where-Object file -eq $v.file
 if(!$v.pass){
  $p="$root/audio/voice/$($v.file)"
  $archive="$root/sources/processed-v2/$($v.file)"
  New-Item -ItemType Directory -Force (Split-Path $archive)|Out-Null
  if(Test-Path $archive){throw "Archive exists: $archive"}
  Copy-Item -LiteralPath $p -Destination $archive
  $start=[Math]::Max([double]0,$v.leading_silence_at_minus50dB-.06)
  $end=$v.duration-$v.trailing_silence_at_minus50dB+.025
  $tempo=[Math]::Min([double]1,($end-$start)/1.40)
  $filter='atrim=start='+$start.ToString('0.000000',$ci)+':end='+$end.ToString('0.000000',$ci)+',asetpts=PTS-STARTPTS,atempo='+$tempo.ToString('0.000000',$ci)+',apad=pad_dur=0.225'
  $null=& $ff -hide_banner -loglevel error -nostdin -y -i $archive -af $filter -ar 48000 -ac 1 -c:a pcm_s16le $p 2>&1
  if($LASTEXITCODE){throw "ffmpeg: $p"}
  $r|Add-Member -Force NoteProperty final_edge_filter $filter
 }
 $log=(& $ff -hide_banner -nostdin -i "$root/audio/voice/$($v.file)" -af 'loudnorm=I=-20:TP=-1:LRA=11:print_format=json' -f null - 2>&1|Out-String)
 $m=[regex]::Match($log,'(?s)\{\s*"input_i".*?\}').Value|ConvertFrom-Json
 $r.LUFS=[double]::Parse($m.input_i,$ci);$r.dBTP=[double]::Parse($m.input_tp,$ci)
 $r.bytes=(Get-Item "$root/audio/voice/$($v.file)").Length
 $r.sha256=(Get-FileHash "$root/audio/voice/$($v.file)").Hash.ToLower()
 $log|Set-Content "$root/technical/stage2-20261116/$($v.file.Replace('.wav','-final.txt'))" -Encoding UTF8
}
$rows|ConvertTo-Json -Depth 8|Set-Content "$root/stage2-20261116-technical.json" -Encoding UTF8
& "$PSScriptRoot/verify-stage2.ps1"
