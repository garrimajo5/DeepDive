param([string]$Ffmpeg = 'C:/Users/FEDYA/Documents/ChatGPT/Pogrujenie/output/snd001-test/deps/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$inv = [Globalization.CultureInfo]::InvariantCulture
function Measure-Audio([string]$file) {
 $log = (& $Ffmpeg -hide_banner -nostdin -i $file -af 'aformat=channel_layouts=mono,loudnorm=I=-20:TP=-2:LRA=11:print_format=json' -f null - 2>&1 | Out-String)
 if($LASTEXITCODE -ne 0) {throw "Decode failed: $file"}
 $match = [regex]::Match($log, '(?s)\{\s*"input_i".*?\}')
 if(!$match.Success) {throw "Missing loudness: $file"}
 return @{stats=($match.Value | ConvertFrom-Json);log=$log}
}
$rows = @()
foreach($file in Get-ChildItem -LiteralPath $root -Filter '*-generation.json' | Sort-Object Name) {
 $doc = Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json
 $key = $file.BaseName -replace '-generation$',''
 $dir = Join-Path $root ('audio/voice/'+$key)
 $tech = Join-Path $root ('technical/'+$key)
 New-Item -ItemType Directory -Force -Path $dir,$tech | Out-Null
 foreach($p in $doc.result.previews) {
  $name = 'kandidat-'+($p.preview_index+1)
  $source = Join-Path $root ('sources/'+$key+'/'+$name+'.mp3')
  $dest = Join-Path $dir ($name+'.wav')
  $measure = Measure-Audio $source
  $i = [double]::Parse($measure.stats.input_i,$inv)
  $tp = [double]::Parse($measure.stats.input_tp,$inv)
  $gain = [Math]::Min(-20-$i,-2-$tp)
  $gainString = $gain.ToString('0.000',$inv)
  $measure.log | Set-Content -LiteralPath (Join-Path $tech ($name+'-source.txt')) -Encoding utf8
  $filter = 'aformat=channel_layouts=mono,volume='+$gainString+'dB'
  $log = (& $Ffmpeg -hide_banner -nostdin -y -i $source -af $filter -ar 48000 -ac 1 -c:a pcm_s16le $dest 2>&1 | Out-String)
  if($LASTEXITCODE -ne 0) {throw "Conversion failed: $dest"}
  $final = Measure-Audio $dest
  $final.log | Set-Content -LiteralPath (Join-Path $tech ($name+'-final.txt')) -Encoding utf8
  $stream=[IO.File]::OpenRead($dest); $br=[IO.BinaryReader]::new($stream)
  try {
   if([Text.Encoding]::ASCII.GetString($br.ReadBytes(4)) -ne 'RIFF') {throw 'Not RIFF'}
   $null=$br.ReadUInt32(); $null=$br.ReadBytes(4)
   $rate=0; $channels=0; $bits=0; $dataBytes=0
   while($stream.Position+8 -le $stream.Length) {
    $tag=[Text.Encoding]::ASCII.GetString($br.ReadBytes(4)); $size=$br.ReadUInt32(); $next=$stream.Position+$size+($size%2)
    if($tag -eq 'fmt ') {$fmt=$br.ReadUInt16();$channels=$br.ReadUInt16();$rate=$br.ReadUInt32();$null=$br.ReadUInt32();$null=$br.ReadUInt16();$bits=$br.ReadUInt16()}
    if($tag -eq 'data') {$dataBytes=$size}
    $stream.Position=$next
   }
  } finally {$br.Dispose();$stream.Dispose()}
  $duration=$dataBytes/($rate*$channels*$bits/8)
  $bytes=(Get-Item -LiteralPath $dest).Length
  $fi=[double]::Parse($final.stats.input_i,$inv);$ftp=[double]::Parse($final.stats.input_tp,$inv)
  if($fmt -ne 1 -or $rate -ne 48000 -or $channels -ne 1 -or $bits -ne 16 -or $bytes -gt 6000000 -or $ftp -gt -1) {throw "Technical limit failed: $dest"}
  $rows += [pscustomobject]@{voice=$key;candidate=($p.preview_index+1);id=$p.generated_voice_id;duration=$duration;sample_rate=$rate;channels=$channels;bits=$bits;bytes=$bytes;LUFS=$fi;dBTP=$ftp;gain_db=$gain;sha256=(Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLower()}
 }
 Write-Output "$key verified"
}
$rows | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $root 'technical-results.json') -Encoding utf8
$rows | Format-Table voice,candidate,duration,LUFS,dBTP,bytes
