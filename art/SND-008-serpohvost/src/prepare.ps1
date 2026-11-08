param([string]$FF='C:\Users\FEDYA\Documents\ChatGPT\Pogrujenie\output\snd001-test\deps\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$inv=[Globalization.CultureInfo]::InvariantCulture
function F([string[]]$a){
 $old=$ErrorActionPreference;$ErrorActionPreference='Continue';$l=& $FF @a 2>&1;$c=$LASTEXITCODE;$ErrorActionPreference=$old
 if($c -ne 0){throw ($l -join "\n")};return ($l|ForEach-Object{"$_".TrimEnd()}) -join [Environment]::NewLine
}
function M([string]$p){
 $l=F @('-hide_banner','-i',$p,'-af','loudnorm=I=-20:TP=-2:LRA=11:print_format=json','-f','null','-')
 $j=[regex]::Match($l,'(?s)\{\s*"input_i".*?\}').Value|ConvertFrom-Json
 return @{l=$l;i=[double]::Parse($j.input_i,$inv);p=[double]::Parse($j.input_tp,$inv)}
}
$state=Get-Content "$root/generation-state.json" -Raw|ConvertFrom-Json
$report=@()
foreach($it in $state.items){
 $name=$it.name;$raw="$root/check.pcm";$tmp="$root/prepared.wav";$out="$root/$name.wav"
 $null=F @('-v','error','-i',"$root/source/$name.mp3",'-ar','48000','-ac','2','-f','s16le','-y',$raw)
 $sourceLength=(Get-Item $raw).Length/192000.0
 $fadeStart=($sourceLength-0.04).ToString('0.000000',$inv)
 $lp=if($name -like 'pred-click-*'){'lowpass=f=1200:p=2,lowpass=f=1200:p=2,'}else{''}
 $filter="$($lp)afade=t=in:d=0.008,afade=t=out:st=$($fadeStart):d=0.04"
 $null=F @('-v','error','-i',"$root/source/$name.mp3",'-af',$filter,'-ar','48000','-ac','2','-c:a','pcm_f32le','-y',$tmp)
 $m=M $tmp
 $gain=[Math]::Min($it.processing_target_lufs-$m.i,-2-$m.p)
 $g=$gain.ToString('0.000',$inv)
 $null=F @('-v','error','-i',$tmp,'-af',"volume=$($g)dB",'-ar','48000','-ac','2','-c:a','pcm_s16le','-y',$out)
 $fm=M $out
 [IO.File]::WriteAllText("$root/$name-technical.txt",$fm.l.TrimEnd()+[Environment]::NewLine)
 $null=F @('-v','error','-i',$out,'-f','s16le','-ar','48000','-ac','2','-y',$raw)
 $b=[IO.File]::ReadAllBytes($raw);$peak=0.0;$edges=0.0;$energy=0.0
 for($k=0;$k -lt $b.Length;$k+=2){$v=[double][BitConverter]::ToInt16($b,$k)/32768;$energy+=$v*$v;$peak=[Math]::Max($peak,[Math]::Abs($v))}
 foreach($k in 0,2,($b.Length-4),($b.Length-2)){$edges=[Math]::Max($edges,[Math]::Abs([double][BitConverter]::ToInt16($b,$k)/32768))}
 $entry=[ordered]@{file="$name.wav";seconds=$b.Length/192000.0;sample_rate=48000;channels=2;codec='pcm_s16le';bytes=(Get-Item $out).Length;lufs=$fm.i;true_peak_dbtp=$fm.p;sample_peak_dbfs=20*[Math]::Log10($peak);edge_max_dbfs=$(if($edges -gt 0){20*[Math]::Log10($edges)}else{-120});gain_db=$gain;fade_in_seconds=0.008;fade_out_seconds=0.04;lowpass_hz=$(if($name -like 'pred-click-*'){1200}else{$null})}
 if($name -like 'pred-click-*'){
  $null=F @('-v','error','-i',$out,'-af','highpass=f=1500:p=2,highpass=f=1500:p=2','-f','s16le','-ar','48000','-ac','2','-y',$raw)
  $hb=[IO.File]::ReadAllBytes($raw);$he=0.0
  for($k=0;$k -lt $hb.Length;$k+=2){$v=[double][BitConverter]::ToInt16($hb,$k)/32768;$he+=$v*$v}
  $entry['highpass1500_energy_ratio']=$he/$energy
 }
 if($fm.p -gt -1 -or $entry.bytes -gt 6000000){throw 'Audio limits failed'}
 $report+=[pscustomobject]$entry
 Remove-Item -LiteralPath $raw,$tmp
}
$report|ConvertTo-Json -Depth 8|Set-Content "$root/technical.json" -Encoding UTF8
$report|Format-Table file,seconds,lufs,true_peak_dbtp,edge_max_dbfs,highpass1500_energy_ratio -AutoSize
