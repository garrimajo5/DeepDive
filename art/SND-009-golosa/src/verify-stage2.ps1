$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$rows=Get-Content -Raw "$root/stage2-20261116-technical.json" | ConvertFrom-Json
$verified=@()
foreach($r in $rows){
 $path="$root/audio/voice/$($r.file)"
 $s=[IO.File]::OpenRead($path);$br=[IO.BinaryReader]::new($s)
 try {
  if([Text.Encoding]::ASCII.GetString($br.ReadBytes(4)) -ne 'RIFF'){throw 'RIFF'}
  $null=$br.ReadUInt32();$null=$br.ReadBytes(4);$data=$null
  while($s.Position+8 -le $s.Length){
   $tag=[Text.Encoding]::ASCII.GetString($br.ReadBytes(4));$size=$br.ReadUInt32();$next=$s.Position+$size+($size%2)
   if($tag -eq 'fmt '){$fmt=$br.ReadUInt16();$channels=$br.ReadUInt16();$rate=$br.ReadUInt32();$null=$br.ReadUInt32();$null=$br.ReadUInt16();$bits=$br.ReadUInt16()}
   if($tag -eq 'data'){$data=$br.ReadBytes($size)}
   $s.Position=$next
  }
 }finally{$br.Dispose()}
 $duration=$data.Length/($rate*$channels*$bits/8);$peak=0;$first=-1;$last=-1
 for($j=0;$j -lt $data.Length/2;$j++){
  $a=[Math]::Abs([int][BitConverter]::ToInt16($data,$j*2));$peak=[Math]::Max($peak,$a)
  if($a -gt 103){if($first -lt 0){$first=$j};$last=$j}
 }
 $lead=$first/$rate;$tail=$duration-($last+1)/$rate
 $pass=($fmt -eq 1 -and $channels -eq 1 -and $rate -eq 48000 -and $bits -eq 16 -and $duration -ge 1.499 -and $duration -le 5 -and $r.LUFS -ge -21 -and $r.LUFS -le -19 -and $r.dBTP -le -1 -and $lead -le .1 -and $tail -ge .2 -and $tail -le .3 -and $r.bytes -le 6000000)
 $verified += [pscustomobject]@{file=$r.file;format=$fmt;channels=$channels;rate=$rate;bits=$bits;duration=$duration;leading_silence_at_minus50dB=$lead;trailing_silence_at_minus50dB=$tail;sample_peak_db=20*[Math]::Log10($peak/32768);LUFS=$r.LUFS;dBTP=$r.dBTP;bytes=$r.bytes;pass=$pass}
}
$verified | ConvertTo-Json -Depth 4 | Set-Content "$root/stage2-20261116-verification.json" -Encoding UTF8
$verified | Where-Object {!$_.pass} | Format-Table
Write-Output "Verified $($verified.Count); failed $(@($verified | Where-Object {!$_.pass}).Count)"
