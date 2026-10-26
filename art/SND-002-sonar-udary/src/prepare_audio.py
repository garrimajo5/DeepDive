"""Convert generated MP3s to 48 kHz PCM WAV and verify peaks; no synthesis."""
from pathlib import Path
import json,subprocess,re,wave,math,sys
import numpy as np
root=Path(__file__).resolve().parents[1]
ff=sys.argv[1]
report=[]
def run(args):
 r=subprocess.run([ff,'-hide_banner','-nostdin',*args],capture_output=True)
 if r.returncode: raise RuntimeError(r.stderr.decode(errors='replace'))
 return r
for src in sorted((root/'source').glob('*.mp3')):
 raw=run(['-i',str(src),'-f','f32le','-ar','48000','-ac','2','-']).stdout
 a=np.frombuffer(raw,dtype='<f4').reshape(-1,2)
 duration=len(a)/48000
 scan=run(['-i',str(src),'-af','loudnorm=I=-18:TP=-2:LRA=11:print_format=json','-f','null','-']).stderr.decode(errors='replace')
 loud=json.loads(scan[scan.rfind('{'):scan.rfind('}')+1])
 gain=-3.-float(loud['input_tp'])
 out=root/(src.stem+'.wav')
 filt=f'volume={gain:.6f}dB,afade=t=in:d=0.005,afade=t=out:st={duration-.05:.6f}:d=0.05'
 run(['-y','-i',str(src),'-af',filt,'-ar','48000','-ac','2','-c:a','pcm_s16le',str(out)])
 check=run(['-i',str(out),'-af','loudnorm=I=-18:TP=-2:LRA=11:print_format=json','-f','null','-']).stderr.decode(errors='replace')
 loud2=json.loads(check[check.rfind('{'):check.rfind('}')+1])
 with wave.open(str(out),'rb') as w:
  assert w.getframerate()==48000 and w.getsampwidth()==2 and w.getnchannels()==2
  data=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').astype(float)/32768
  frames=w.getnframes()
 peak=20*math.log10(max(np.abs(data).max(),1e-12))
 assert peak<=-1 and float(loud2['input_tp'])<=-1 and out.stat().st_size<6000000
 limits=(3,4) if src.stem.startswith('sonar') else (2,3) if 'scrape' in src.stem else (1,2)
 assert limits[0]<=frames/48000<=limits[1]
 source_info=run(['-i',str(src),'-f','null','-']).stderr.decode(errors='replace')
 item={'file':out.name,'seconds':frames/48000,'bytes':out.stat().st_size,'sample_rate':48000,'channels':2,'bits':16,'sample_peak_dbfs':round(peak,3),'true_peak_dbtp':float(loud2['input_tp']),'integrated_lufs':float(loud2['input_i']),'gain_db':gain,'source_info':source_info,'source_peak':loud['input_tp'],'sha256':__import__('hashlib').sha256(out.read_bytes()).hexdigest()}
 report.append(item)
 print(out.name,round(duration,3),'peak',round(peak,2),'true',loud2['input_tp'])
(root/'technical-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')

