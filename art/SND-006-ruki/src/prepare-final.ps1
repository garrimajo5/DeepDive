param([string]$Ffmpeg='C:\Users\FEDYA\Documents\ChatGPT\Pogrujenie\output\snd001-test\deps\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$inv=[Globalization.CultureInfo]::InvariantCulture
function RunFF([string[]]$ArgsFF) {
  $old=$ErrorActionPreference
  $ErrorActionPreference='Continue'
  $lines=& $Ffmpeg @ArgsFF 2>&1
  $code=$LASTEXITCODE
  $ErrorActionPreference=$old
  if($code -ne 0) { throw ($lines -join "\n") }
  return ($lines | ForEach-Object { "$_" }) -join [Environment]::NewLine
}
function MeasureAudio([string]$Path) {
  $log=RunFF @('-hide_banner','-i',$Path,'-af','loudnorm=I=-18:TP=-2:LRA=11:print_format=json','-f','null','-')
  $json=[regex]::Match($log,'(?s)\{\s*"input_i".*?\}').Value | ConvertFrom-Json
  return @{log=$log; lufs=[double]::Parse($json.input_i,$inv); peak=[double]::Parse($json.input_tp,$inv)}
}
$state=Get-Content "$root/generation-state.json" -Raw | ConvertFrom-Json
$report=@()
foreach($item in $state.items) {
  $name=$item.name
  $source="$root/source/$name.mp3"
  $raw="$root/$name-check.pcm"
  $null=RunFF @('-v','error','-i',$source,'-ar','44100','-ac','2','-f','s16le','-y',$raw)
  $duration=(Get-Item $raw).Length/176400.0
  Remove-Item -LiteralPath $raw
  $temp="$root/$name-prepared.wav"
  if($item.loop) {
    $tail=($duration-0.1).ToString('0.000000',$inv)
    $filter="[0:a]asplit=3[h][m][t];[h]atrim=end=0.1,asetpts=PTS-STARTPTS[head];[t]atrim=start=$tail,asetpts=PTS-STARTPTS[tail];[tail]afade=t=out:d=0.1[tailfade];[head]afade=t=in:d=0.1[headfade];[tailfade][headfade]amix=inputs=2:duration=longest:normalize=0[seam];[m]atrim=start=0.1:end=$tail,asetpts=PTS-STARTPTS[mid];[mid][seam]concat=n=2:v=0:a=1[out]"
    $null=RunFF @('-v','error','-i',$source,'-filter_complex',$filter,'-map','[out]','-ar','44100','-ac','2','-c:a','pcm_f32le','-y',$temp)
    $outName=if($name -like 'weld-*'){"$name-rev2.mp3"}elseif($name -eq 'scanner-hold-1'){"$name-rev1.mp3"}else{"$name.mp3"}
  } else {
    $fadeStart=($duration-0.03).ToString('0.000000',$inv)
    $null=RunFF @('-v','error','-i',$source,'-af',"afade=t=in:d=0.003,afade=t=out:st=$($fadeStart):d=0.03",'-ar','48000','-ac','2','-c:a','pcm_f32le','-y',$temp)
    $outName="$name.wav"
  }
  $m=MeasureAudio $temp
  $gain=[Math]::Min(-18-$m.lufs,-2-$m.peak)
  $gainText=$gain.ToString('0.000',$inv)
  $out="$root/$outName"
  if(Test-Path -LiteralPath $out) { throw "Refuse to overwrite $out" }
  $codec=if($item.loop){@('-ar','44100','-c:a','libmp3lame','-b:a','192k')}else{@('-ar','48000','-c:a','pcm_s16le')}
  $null=RunFF (@('-v','error','-i',$temp,'-af',"volume=$($gainText)dB",'-ac','2')+$codec+@($out))
  Remove-Item -LiteralPath $temp
  $final=MeasureAudio $out
  $final.log | Set-Content "$root/$outName-technical.txt" -Encoding UTF8
  $rate=if($item.loop){44100}else{48000}
  $null=RunFF @('-v','error','-i',$out,'-ar',"$rate",'-ac','2','-f','s16le','-y',$raw)
  $bytes=[IO.File]::ReadAllBytes($raw)
  $frames=$bytes.Length/4
  $jump=0.0
  for($ch=0;$ch -lt 2;$ch++){
    $a=[BitConverter]::ToInt16($bytes,2*$ch)/32768.0
    $b=[BitConverter]::ToInt16($bytes,$bytes.Length-4+2*$ch)/32768.0
    $jump=[Math]::Max($jump,[Math]::Abs($a-$b))
  }
  $n=[int]($rate*0.02); $edgeSum=0.0; $sum=0.0
  for($k=0;$k -lt $bytes.Length;$k+=2) {
    $v=[BitConverter]::ToInt16($bytes,$k)/32768.0
    $sum+=$v*$v
    if($k -lt $n*4 -or $k -ge $bytes.Length-$n*4){$edgeSum+=$v*$v}
  }
  $rms=[Math]::Sqrt($sum/($frames*2))
  $edgeRms=[Math]::Sqrt($edgeSum/($n*4))
  Remove-Item -LiteralPath $raw
  $entry=[ordered]@{file=$outName;source="$name.mp3";source_seconds=$duration;seconds=$frames/$rate;sample_rate=$rate;channels=2;bytes=(Get-Item $out).Length;lufs=$final.lufs;true_peak_dbtp=$final.peak;gain_db=$gain;loop=[bool]$item.loop;crossfade_seconds=$(if($item.loop){0.1}else{0});boundary_jump_dbfs=$(if($jump -gt 0){20*[Math]::Log10($jump)}else{-120});edge_20ms_rms_dbfs=$(if($edgeRms -gt 0){20*[Math]::Log10($edgeRms)}else{-120});whole_rms_dbfs=$(20*[Math]::Log10($rms));plan=$(if($item.plan){$item.plan}else{'Free'})}
  if($entry.true_peak_dbtp -gt -1 -or $entry.bytes -gt 6000000){throw "Output limits failed"}
  $report+=[pscustomobject]$entry
}
$report | ConvertTo-Json -Depth 6 | Set-Content "$root/technical-final.json" -Encoding UTF8
$report | Format-Table file,seconds,lufs,true_peak_dbtp,boundary_jump_dbfs,edge_20ms_rms_dbfs,whole_rms_dbfs -AutoSize
