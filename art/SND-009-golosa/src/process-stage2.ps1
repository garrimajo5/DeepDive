param([string]$Ffmpeg='C:/Users/FEDYA/Documents/ChatGPT/Pogrujenie/output/snd001-test/deps/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$ci=[Globalization.CultureInfo]::InvariantCulture
$rows=@()
function MeasureAudio($path) {
 $log=(& $Ffmpeg -hide_banner -nostdin -i $path -af 'loudnorm=I=-20:TP=-1:LRA=11:print_format=json' -f null - 2>&1 | Out-String)
 if($LASTEXITCODE -ne 0){throw "measure $path"}
 $m=[regex]::Match($log,'(?s)\{\s*"input_i".*?\}')
 return @{log=$log;stats=($m.Value|ConvertFrom-Json)}
}
foreach($manifest in Get-ChildItem "$root/stage2-20261116/*.json" | Sort-Object Name){
 $items=Get-Content -Raw $manifest.FullName | ConvertFrom-Json
 foreach($item in $items){
  for($n=0;$n -lt $item.generations.Count;$n++){
   $gen=$item.generations[$n]
   $name=$item.id
   if($item.count -eq 2){$name+='-'+($n+1)}
   $srcDir="$root/sources/stage2-20261116/$($item.key)"
   $outDir="$root/audio/voice/$($item.key)"
   $qcDir="$root/technical/stage2-20261116/$($item.key)"
   New-Item -ItemType Directory -Force $srcDir,$outDir,$qcDir | Out-Null
   $src="$srcDir/$name.mp3";$pcm="$qcDir/$name.pcm";$trim="$qcDir/$name-trim.wav";$out="$outDir/$name.wav"
   if(!(Test-Path $src)){
    & curl.exe -sS -L --fail --max-time 45 -o $src $gen.content_url
    if($LASTEXITCODE -ne 0){throw "download failed $($gen.id)"}
   }
   $null= & $Ffmpeg -hide_banner -loglevel error -nostdin -y -i $src -ar 48000 -ac 1 -f s16le $pcm 2>&1
   if($LASTEXITCODE -ne 0){throw "decode $src"}
   $bytes=[IO.File]::ReadAllBytes($pcm);$samples=$bytes.Length/2
   $first=-1;$last=-1
   for($j=0;$j -lt $samples;$j++){
    if([Math]::Abs([int][BitConverter]::ToInt16($bytes,$j*2)) -gt 103){if($first -lt 0){$first=$j};$last=$j}
   }
   if($first -lt 0){throw "silent $src"}
   $start=[Math]::Max(0,($first/48000)-0.05)
   $end=[Math]::Min($samples/48000,($last/48000)+0.05)
   $length=$end-$start
   $pad=0.20
   if($length+$pad -lt 1.5){$pad=[Math]::Min(0.25,1.5-$length)}
   $filter='atrim=start='+$start.ToString('0.000000',$ci)+':end='+$end.ToString('0.000000',$ci)+',asetpts=PTS-STARTPTS,apad=pad_dur='+$pad.ToString('0.000000',$ci)
   $null= & $Ffmpeg -hide_banner -loglevel error -nostdin -y -f s16le -ar 48000 -ac 1 -i $pcm -af $filter -c:a pcm_s16le $trim 2>&1
   if($LASTEXITCODE -ne 0){throw "trim $src"}
   $m=MeasureAudio $trim
   $gain=[Math]::Min(-20-[double]::Parse($m.stats.input_i,$ci),-1.2-[double]::Parse($m.stats.input_tp,$ci))
   $null= & $Ffmpeg -hide_banner -loglevel error -nostdin -n -i $trim -af ('volume='+$gain.ToString('0.000',$ci)+'dB') -ar 48000 -ac 1 -c:a pcm_s16le $out 2>&1
   if($LASTEXITCODE -ne 0){throw "output exists or conversion failed $out"}
   $final=MeasureAudio $out
   $final.log | Set-Content "$qcDir/$name-final.txt" -Encoding UTF8
   $m.log | Set-Content "$qcDir/$name-source.txt" -Encoding UTF8
   $duration=$length+$pad
   $lufs=[double]::Parse($final.stats.input_i,$ci);$peak=[double]::Parse($final.stats.input_tp,$ci)
   $rows += [pscustomobject]@{voice=$item.key;file="$($item.key)/$name.wav";id=$gen.id;text=$item.text;duration=$duration;source_duration=$gen.duration_secs;trim_start=$start;trim_end=$end;tail_pad=$pad;LUFS=$lufs;dBTP=$peak;gain_db=$gain;sample_rate=48000;channels=1;bits=16;bytes=(Get-Item $out).Length;sha256=(Get-FileHash $out -Algorithm SHA256).Hash.ToLower();pass=($duration -ge 1.499 -and $duration -le 5 -and $lufs -ge -21 -and $lufs -le -19 -and $peak -le -1)}
   # Remove only derived scratch files in this order's QC directory.
   Remove-Item -LiteralPath $pcm,$trim
   Write-Output "$($item.key)/$name $duration s $lufs LUFS $peak dBTP"
   $rows | ConvertTo-Json -Depth 5 | Set-Content "$root/stage2-20261116-technical.json" -Encoding UTF8
  }
 }
}
