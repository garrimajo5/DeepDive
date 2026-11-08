param([string]$FF='C:\Users\FEDYA\Documents\ChatGPT\Pogrujenie\output\snd001-test\deps\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$inv=[Globalization.CultureInfo]::InvariantCulture
function F([string[]]$a){
 $old=$ErrorActionPreference;$ErrorActionPreference='Continue';$l=& $FF @a 2>&1;$c=$LASTEXITCODE;$ErrorActionPreference=$old
 if($c -ne 0){throw ($l -join "\n")};return ($l|ForEach-Object{"$_".TrimEnd()}) -join [Environment]::NewLine
}
function M([string]$p){
 $l=F @('-hide_banner','-i',$p,'-af','apad=whole_dur=0.4,loudnorm=I=-24:TP=-2:LRA=11:print_format=json','-f','null','-')
 $j=[regex]::Match($l,'(?s)\{\s*"input_i".*?\}').Value|ConvertFrom-Json
 return @{l=$l;i=[double]::Parse($j.input_i,$inv);p=[double]::Parse($j.input_tp,$inv)}
}
$state=Get-Content "$root/generation-state.json" -Raw|ConvertFrom-Json
$report=@()
foreach($it in $state.items){
 $name=$it.name;$raw="$root/work.pcm";$tmp="$root/work.wav";$out="$root/$name.wav"
 $null=F @('-v','error','-i',"$root/source/$name.mp3",'-ar','48000','-ac','2','-f','s16le','-y',$raw)
 $b=[IO.File]::ReadAllBytes($raw);$frames=[int]($b.Length/4);$n=[int]($it.target*48000);$start=0
 # Preserve the most energetic complete window; avoid selecting an empty lead-in.
 if($frames -gt $n){
  $sum=0.0
  for($i=0;$i -lt $n;$i++){foreach($ch in 0,1){$v=[double][BitConverter]::ToInt16($b,$i*4+$ch*2);$sum+=$v*$v}}
  $best=$sum
  for($i=$n;$i -lt $frames;$i++){
   foreach($ch in 0,1){$v=[double][BitConverter]::ToInt16($b,$i*4+$ch*2);$w=[double][BitConverter]::ToInt16($b,($i-$n)*4+$ch*2);$sum+=$v*$v-$w*$w}
   if($sum -gt $best){$best=$sum;$start=$i-$n+1}
  }
 }
 $end=[Math]::Min($start+$n,$frames)
 $len=($end-$start)/48000.0
 $fade=[Math]::Min(0.02,$len*0.15)
 $fadeStart=($len-$fade).ToString('0.000000',$inv);$fadeText=$fade.ToString('0.000000',$inv)
 $lp=if($name -like 'ui-*'){'lowpass=f=4500:p=2,'}else{''}
 $filter="atrim=start_sample=$($start):end_sample=$end,asetpts=PTS-STARTPTS,$($lp)afade=t=in:d=0.002,afade=t=out:st=$($fadeStart):d=$fadeText"
 $null=F @('-v','error','-f','s16le','-ar','48000','-ac','2','-i',$raw,'-af',$filter,'-c:a','pcm_f32le','-y',$tmp)
 $m=M $tmp
 $gain=[Math]::Min($it.lufs-$m.i,-2-$m.p)
 if([double]::IsInfinity($gain) -or [double]::IsNaN($gain)){throw "Cannot measure $name"}
 $g=$gain.ToString('0.000',$inv)
 $null=F @('-v','error','-i',$tmp,'-af',"volume=$($g)dB",'-ar','48000','-ac','2','-c:a','pcm_s16le','-y',$out)
 $fm=M $out
 [IO.File]::WriteAllText("$root/$name-technical.txt",$fm.l.TrimEnd()+[Environment]::NewLine)
 $null=F @('-v','error','-i',$out,'-f','s16le','-ar','48000','-ac','2','-y',$raw)
 $final=[IO.File]::ReadAllBytes($raw);$peak=0.0;$edges=0.0
 for($k=0;$k -lt $final.Length;$k+=2){$peak=[Math]::Max($peak,[Math]::Abs([double][BitConverter]::ToInt16($final,$k)/32768))}
 foreach($k in 0,2,($final.Length-4),($final.Length-2)){$edges=[Math]::Max($edges,[Math]::Abs([double][BitConverter]::ToInt16($final,$k)/32768))}
 $entry=[ordered]@{file="$name.wav";seconds=$final.Length/192000.0;sample_rate=48000;channels=2;codec='pcm_s16le';bytes=(Get-Item $out).Length;measured_lufs=$fm.i;lufs_method=$(if($len -lt 0.4){'zero-padded to 400 ms for BS.1770 measurement only'}else{'standard integrated'});true_peak_dbtp=$fm.p;sample_peak_dbfs=20*[Math]::Log10($peak);edge_max_dbfs=$(if($edges -gt 0){20*[Math]::Log10($edges)}else{-120});start_seconds=$start/48000.0;end_seconds=$end/48000.0;gain_db=$gain;fade_out_seconds=$fade;lowpass_hz=$(if($name -like 'ui-*'){4500}else{$null})}
 if($fm.p -gt -1 -or $entry.bytes -gt 6000000){throw 'Audio limits failed'}
 $report+=[pscustomobject]$entry
 Remove-Item -LiteralPath $raw,$tmp
}
$report|ConvertTo-Json -Depth 8|Set-Content "$root/technical.json" -Encoding UTF8
$report|Format-Table file,seconds,measured_lufs,true_peak_dbtp,edge_max_dbfs,start_seconds -AutoSize
