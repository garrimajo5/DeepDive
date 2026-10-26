"""Convert generated loop sources to PCM16 WAV; no synthesis."""
from pathlib import Path
import subprocess,sys,json,tempfile,wave,hashlib
import numpy as np
ROOT=Path(__file__).resolve().parent
FF=sys.argv[1]
def run(args):
 r=subprocess.run([FF,'-hide_banner','-nostdin',*args],capture_output=True)
 if r.returncode:raise RuntimeError(r.stderr.decode(errors='replace'))
 return r
def scan(path):
 s=run(['-i',str(path),'-af','loudnorm=I=-18:TP=-3.2:LRA=11:print_format=json','-f','null','-']).stderr.decode(errors='replace')
 return json.loads(s[s.rfind('{'):s.rfind('}')+1])
report=[]
with tempfile.TemporaryDirectory() as td:
 for src in sorted((ROOT/'source').glob('*.mp3')):
  a=np.frombuffer(run(['-i',str(src),'-ar','48000','-ac','2','-f','f32le','-']).stdout,dtype='<f4').reshape(-1,2)
  n=2400;w=(.5-.5*np.cos(np.linspace(0,np.pi,n)))[:,None]
  b=np.concatenate([a[n:-n],a[-n:]*(1-w)+a[:n]*w]).astype('<f4')
  # Rotate the same circular recording to a low-discontinuity, steady-level boundary.
  jumps=np.max(np.abs(b-np.roll(b,1,axis=0)),axis=1)
  overall=float(np.sqrt(np.mean(b*b)));seam=0
  for k in np.argsort(jumps)[:5000]:
   pre=b[(np.arange(k-2400,k)%len(b))];post=b[(np.arange(k,k+2400)%len(b))]
   r0=float(np.sqrt(np.mean(pre*pre)));r1=float(np.sqrt(np.mean(post*post)))
   if min(r0,r1)>.3*overall and abs(20*np.log10(max(r0,1e-12)/max(r1,1e-12)))<.5:
    seam=int(k);break
  b=np.roll(b,-seam,axis=0)
  raw=Path(td)/'loop.raw';raw.write_bytes(b.tobytes());wav=Path(td)/'loop.wav'
  run(['-y','-f','f32le','-ar','48000','-ac','2','-i',str(raw),'-c:a','pcm_f32le',str(wav)])
  before=scan(wav);gain=min(-18-float(before['input_i']),-3.2-float(before['input_tp']))
  out=ROOT/(src.stem+'.wav')
  run(['-y','-i',str(wav),'-af',f'volume={gain}dB','-c:a','pcm_s16le','-ar','48000',str(out)])
  after=scan(out)
  with wave.open(str(out),'rb') as wf:
   assert wf.getframerate()==48000 and wf.getsampwidth()==2 and wf.getnchannels()==2
   x=np.frombuffer(wf.readframes(wf.getnframes()),dtype='<i2').reshape(-1,2).astype(float)/32768
  peak=20*np.log10(np.abs(x).max());delta=float(np.abs(x[0]-x[-1]).max())
  rms=lambda z:float(np.sqrt(np.mean(z*z)))
  rmsdiff=20*np.log10(rms(x[:2400])/rms(x[-2400:]))
  assert 3<=len(x)/48000<=4 and peak<=-3 and float(after['input_tp'])<=-3
  assert out.stat().st_size<6000000
  item=dict(file=out.name,seconds=len(x)/48000,bytes=out.stat().st_size,rate=48000,bits=16,channels=2,sample_peak_dbfs=float(peak),true_peak_dbtp=float(after['input_tp']),lufs=float(after['input_i']),gain_db=gain,crossfade_ms=50,boundary_rotation_seconds=seam/48000,seam_jump_dbfs=float(20*np.log10(max(delta,1e-12))),edge_50ms_rms_difference_db=float(rmsdiff),sha256=hashlib.sha256(out.read_bytes()).hexdigest())
  report.append(item);print(item)
(ROOT/'technical-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
