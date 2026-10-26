import array, hashlib, json, math, re, subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
ffmpeg = next(Path('C:/Users/FEDYA/Documents/ChatGPT/Pogrujenie/output/snd001-test/deps/imageio_ffmpeg/binaries').glob('*.exe'))
state = json.loads((root/'generation-state.json').read_text(encoding='utf-8-sig'))
def run(args):
    return subprocess.run([str(ffmpeg),'-nostdin','-hide_banner',*args],capture_output=True,check=True)
def measure(path):
    log=run(['-i',str(path),'-af','loudnorm=I=-18:TP=-2:LRA=7:print_format=json','-f','null','-']).stderr.decode()
    return json.loads(re.findall(r'\{[^{}]+\}',log)[-1]),log
reports=[]
for item in state['items']:
    if not item.get('downloaded'): continue
    src=root/'source'/(item['name']+'.mp3')
    ext='.mp3' if item['loop'] else '.wav'
    dest=root/(item['name']+ext)
    if dest.exists(): continue
    source,log=measure(src)
    gain=min(-18-float(source['input_i']),-2-float(source['input_tp']))
    duration=item['duration']
    if item['loop']:
        d=duration
        filt=f'[0:a]asplit=3[mid][tail][head];[mid]atrim=start=0.05:end={d-0.05},asetpts=PTS-STARTPTS[m];[tail]atrim=start={d-0.05}:end={d},asetpts=PTS-STARTPTS,afade=t=out:st=0:d=0.05[t];[head]atrim=start=0:end=0.05,asetpts=PTS-STARTPTS,afade=t=in:st=0:d=0.05[h];[t][h]amix=inputs=2:duration=shortest:normalize=0[c];[m][c]concat=n=2:v=0:a=1,volume={gain:.4f}dB[out]'
        run(['-i',str(src),'-filter_complex',filt,'-map','[out]','-ar','44100','-c:a','libmp3lame','-b:a','192k','-map_metadata','-1',str(dest)])
    else:
        run(['-i',str(src),'-af',f'volume={gain:.4f}dB','-ar','48000','-c:a','pcm_s16le','-map_metadata','-1',str(dest)])
    final,flog=measure(dest)
    hz=44100 if item['loop'] else 48000
    pcm=array.array('f',run(['-i',str(dest),'-f','f32le','-acodec','pcm_f32le','-']).stdout)
    report=dict(file=dest.name,duration_seconds=len(pcm)/2/hz,stream=re.search(r'Audio:.*',flog).group(0).strip(),source_stream=re.search(r'Audio:.*',log).group(0).strip(),gain_db=gain,source_loudness=source,final_loudness=final,sample_peak_dbfs=20*math.log10(max(abs(x) for x in pcm)),boundary_jump_dbfs=[20*math.log10(max(abs(pcm[c]-pcm[-2+c]),1e-12)) for c in range(2)],bytes=dest.stat().st_size,sha256=hashlib.sha256(dest.read_bytes()).hexdigest())
    assert report['sample_peak_dbfs']<=-1 and float(final['input_tp'])<=-1
    assert report['bytes']<6000000
    assert abs(report['duration_seconds']-duration)<0.1
    (root/(item['name']+'-technical.json')).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    reports.append(report)
print(json.dumps(reports,indent=2))
