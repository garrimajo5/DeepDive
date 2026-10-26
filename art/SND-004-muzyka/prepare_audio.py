"""Prepare generated music as circular loops; no audio synthesis."""
from pathlib import Path
import subprocess,json,sys,tempfile,hashlib
import numpy as np
root=Path(__file__).resolve().parent
ff=sys.argv[1]
def run(args):
 r=subprocess.run([ff,'-hide_banner','-nostdin',*args],capture_output=True)
 if r.returncode: raise RuntimeError(r.stderr.decode(errors='replace'))
 return r
def scan(p):
 t=run(['-i',str(p),'-af','loudnorm=I=-18:TP=-2:LRA=11:print_format=json','-f','null','-']).stderr.decode(errors='replace')
 return json.loads(t[t.rfind('{'):t.rfind('}')+1])
report=[]
with tempfile.TemporaryDirectory() as td:
 for src in sorted((root/'source').glob('*.mp3')):
  a=np.frombuffer(run(['-i',str(src),'-ar','44100','-ac','2','-f','f32le','-']).stdout,dtype='<f4').reshape(-1,2)
  # Crossfade tail into head over 4 seconds, keep continuous source at both joins.
  n=4*44100
  w=(.5-.5*np.cos(np.linspace(0,np.pi,n)))[:,None]
  blend=a[-n:]*(1-w)+a[:n]*w
  b=np.concatenate([a[n:-n],blend]).astype('<f4')
  # 5 ms edge ramps suppress MP3 decoder boundary transients.
  k=221
  b[:k]*=np.linspace(0,1,k)[:,None]
  b[-k:]*=np.linspace(1,0,k)[:,None]
  raw=Path(td)/'loop.raw';raw.write_bytes(b.tobytes())
  wav=Path(td)/'loop.wav'
  run(['-y','-f','f32le','-ar','44100','-ac','2','-i',str(raw),'-c:a','pcm_f32le',str(wav)])
  before=scan(wav);gain=min(-18-float(before['input_i']),-2-float(before['input_tp']))
  out=root/src.name
  run(['-y','-i',str(wav),'-af',f'volume={gain}dB','-ar','44100','-ac','2','-c:a','libmp3lame','-b:a','192k','-write_xing','1',str(out)])
  after=scan(out)
  c=np.frombuffer(run(['-i',str(out),'-ar','44100','-ac','2','-f','f32le','-']).stdout,dtype='<f4').reshape(-1,2)
  sec=len(c)/44100;delta=float(np.max(np.abs(c[0]-c[-1])))
  rms=lambda x:float(np.sqrt(np.mean(x.astype(float)**2)))
  edge_ratio=20*np.log10(max(rms(c[:44100]),1e-12)/max(rms(c[-44100:]),1e-12))
  assert float(after['input_tp'])<=-1 and out.stat().st_size<6000000
  assert (90<=sec<=150) if 'menu' in src.name else (45<=sec<=60)
  info=run(['-i',str(out),'-f','null','-']).stderr.decode(errors='replace')
  assert '44100 Hz' in info and '192 kb/s' in info
  report.append(dict(file=out.name,seconds=sec,bytes=out.stat().st_size,lufs=float(after['input_i']),true_peak_dbtp=float(after['input_tp']),gain_db=gain,crossfade_seconds=4,edge_ramp_ms=5,seam_delta_dbfs=float(20*np.log10(max(delta,1e-12))),edge_rms_difference_db=float(edge_ratio),sha256=hashlib.sha256(out.read_bytes()).hexdigest()))
  print(report[-1],flush=True)
(root/'technical-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
