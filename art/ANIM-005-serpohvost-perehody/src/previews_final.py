"""Render the re-imported deliverable, sheets and GIFs; no third-party packages."""
import bpy,math,sys,struct,json,numpy as np
from pathlib import Path
from mathutils import Vector,Quaternion
out=Path(__file__).resolve().parents[1];tmp=out/'local'/'frames-final';tmp.mkdir(exist_ok=True)
font=bpy.data.fonts.load('C:/Windows/Fonts/arial.ttf') if False else None
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.render.fps=60
s.render.engine='CYCLES';s.cycles.samples=8;s.cycles.use_denoising=True
s.render.resolution_x=640;s.render.resolution_y=320;s.render.resolution_percentage=100
s.render.image_settings.file_format='PNG';s.view_settings.view_transform='AgX'
bpy.ops.import_scene.gltf(filepath=str(out/'serpohvost-anim.glb'))
arm=next(o for o in s.objects if o.type=='ARMATURE');acts={a.name:a for a in bpy.data.actions}
for o in s.objects:
 if o.type=='MESH' and not any(m.type=='ARMATURE' for m in o.modifiers):o.hide_render=True
s.world=bpy.data.worlds.new('World');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.025,.055,.075,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.6
for loc,power,size in [((4,1,5),1600,6),((-3,-4,3),1200,5),((4,-3,0),500,4)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.size=size;o.rotation_euler=(Vector((0,-1,0))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;s.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=7.6
font=bpy.data.fonts.load('C:/Windows/Fonts/arial.ttf')
mat=bpy.data.materials.new('Caption');mat.use_nodes=True;nt=mat.node_tree;nt.nodes.clear();a=nt.nodes.new('ShaderNodeEmission');a.inputs[0].default_value=(.62,.85,.91,1);z=nt.nodes.new('ShaderNodeOutputMaterial');nt.links.new(a.outputs[0],z.inputs[0])
def text_obj(body,loc,size=.18):
 c=bpy.data.curves.new('Caption','FONT');c.body=body;c.font=font;c.size=size;o=bpy.data.objects.new('Caption',c);s.collection.objects.link(o);o.parent=cam;o.location=loc;o.data.materials.append(mat);return o
caption=text_obj('',(-3.6,1.55,-5))
ruler=text_obj('0 ───── 1 м',(2.3,-1.65,-5),.14)
# Exact one metre ruler: projected camera-plane geometry, independent of view.
curve=bpy.data.curves.new('metre','CURVE');curve.dimensions='3D';curve.bevel_depth=.012
for pts in [[(2.3,-1.35,-5),(3.3,-1.35,-5)],[(2.3,-1.43,-5),(2.3,-1.27,-5)],[(3.3,-1.43,-5),(3.3,-1.27,-5)]]:
 sp=curve.splines.new('POLY');sp.points.add(1)
 for p,co in zip(sp.points,pts):p.co=(*co,1)
o=bpy.data.objects.new('metre',curve);s.collection.objects.link(o);o.parent=cam;o.data.materials.append(mat)
def camera(view):
 loc={'side':(10,-1.1,0),'front':(0,10,0),'top':(0,-1.1,10)}[view];target=Vector((0,-1.1,0));cam.location=loc;q=(target-cam.location).to_track_quat('-Z','Y')
 if view=='top':q=q@Quaternion((0,0,1),math.pi/2)
 cam.rotation_euler=q.to_euler()
def render(name,t,view,label,key):
 p=tmp/(key+'.png')
 if p.exists():return p
 camera(view);a=acts[name];arm.animation_data.action=a;arm.animation_data.action_slot=a.slots[0];s.frame_set(int(t*60),subframe=t*60-int(t*60));caption.data.body=label
 s.render.filepath=str(p);bpy.ops.render.render(write_still=True);return p

def pixels(p):
 im=bpy.data.images.load(str(p),check_existing=False);arr=np.array(im.pixels[:],dtype=np.float32).reshape(im.size[1],im.size[0],4);bpy.data.images.remove(im);return arr

def sheet(paths,cols,name):
 arr=[pixels(p) for p in paths];h,w=arr[0].shape[:2];rows=math.ceil(len(arr)/cols);canvas=np.ones((rows*h,cols*w,4),dtype=np.float32);canvas[:,:,:3]=.03
 for k,a in enumerate(arr):row=rows-1-k//cols;canvas[row*h:(row+1)*h,(k%cols)*w:(k%cols+1)*w]=a
 im=bpy.data.images.new('sheet',width=cols*w,height=rows*h);im.pixels.foreach_set(canvas.ravel());im.filepath_raw=str(out/name);im.file_format='JPEG';im.save();bpy.data.images.remove(im)

# GIF encoder with fixed 256 colour RGB palette and LZW; consumes rendered PNGs.
def gif(frames,path,delay=5):
 arrays=[];hist=np.zeros(32768,dtype=np.int64)
 for paths in frames:
  rgb=np.concatenate([pixels(p)[::-1,:,:3] for p in paths],axis=1)
  if len(paths)==1:rgb=rgb[np.linspace(0,rgb.shape[0]-1,240).astype(int)][:,np.linspace(0,rgb.shape[1]-1,480).astype(int)]
  rgb=np.clip(rgb*255+.5,0,255).astype(np.uint8)
  ids=((rgb[:,:,0].astype(np.int32)>>3)<<10)|((rgb[:,:,1].astype(np.int32)>>3)<<5)|(rgb[:,:,2]>>3)
  arrays.append(ids);hist+=np.bincount(ids.ravel(),minlength=32768)
 ids=np.arange(32768);colors=np.column_stack(((ids>>10)*8+4,((ids>>5)&31)*8+4,(ids&31)*8+4)).astype(float)
 boxes=[np.flatnonzero(hist)]
 while len(boxes)<256:
  scores=[np.ptp(colors[x],axis=0).max()*math.sqrt(hist[x].sum()) if len(x)>1 else -1 for x in boxes]
  ix=int(np.argmax(scores))
  if scores[ix]<0:break
  box=boxes.pop(ix);axis=int(np.argmax(np.ptp(colors[box],axis=0)));box=box[np.argsort(colors[box,axis])];cs=np.cumsum(hist[box]);mid=max(1,min(len(box)-1,int(np.searchsorted(cs,cs[-1]/2))))
  boxes.extend([box[:mid],box[mid:]])
 palette=np.array([np.average(colors[x],axis=0,weights=hist[x]) for x in boxes],dtype=np.uint8)
 while len(palette)<256:palette=np.vstack((palette,palette[-1]))
 lut=np.empty(32768,dtype=np.uint8)
 for start in range(0,32768,512):lut[start:start+512]=np.argmin(np.sum((colors[start:start+512,None,:]-palette[None,:,:])**2,axis=2),axis=1)
 arrays=[lut[x] for x in arrays]
 h,w=arrays[0].shape;data=bytearray(b'GIF89a'+struct.pack('<HHBBB',w,h,247,0,0));data+=palette.tobytes()
 data+=b'!\xff\x0bNETSCAPE2.0\x03\x01\x00\x00\x00'
 for arr in arrays:
  data+=b'!\xf9\x04\x04'+struct.pack('<H',delay)+b'\x00\x00,'+struct.pack('<HHHHB',0,0,w,h,0)+b'\x08'
  table={bytes([i]):i for i in range(256)};nextcode=258;bits=9;acc=0;nb=0;packed=bytearray()
  def emit(code,width):
   nonlocal acc,nb
   acc|=code<<nb;nb+=width
   while nb>=8:packed.append(acc&255);acc>>=8;nb-=8
  emit(256,bits);seq=b''
  for n in arr.tobytes():
   c=bytes([n]);both=seq+c
   if both in table:seq=both;continue
   if nextcode>(1<<bits) and bits<12:bits+=1
   emit(table[seq],bits)
   # Decoder dictionary is one emitted code behind encoder.
   if nextcode<4096:table[both]=nextcode;nextcode+=1
   else:
    emit(256,bits);table={bytes([i]):i for i in range(256)};nextcode=258;bits=9
   seq=c
  if nextcode>(1<<bits) and bits<12:bits+=1
  if seq:emit(table[seq],bits)
  if nextcode>(1<<bits) and bits<12:bits+=1
  emit(257,bits)
  if nb:packed.append(acc&255)
  for k in range(0,len(packed),255):block=packed[k:k+255];data.append(len(block));data+=block
  data.append(0)
 data+=b';';path.write_bytes(data)

for ix,(name,dur) in enumerate([('Swim',2.4),('SwimFast',1.2),('Bite',1.2)],11):
 paths=[render(name,dur*u,'side' if name=='Bite' else 'top',f'{name} · {int(u*100)}%',f'original_{name}_{k}') for k,u in enumerate([0,.25,.5,.75])]
 sheet(paths,2,f'{ix:02}-phases-{name}.jpg')
views=[render('Swim',0,v,'Серпохвост · '+lab,'preview_'+v) for v,lab in [('side','сбоку'),('top','сверху'),('front','спереди')]]
sheet(views,3,'01-preview.jpg')
clips={'TailStrike':.9,'Recoil':1.,'Hover':4.,'Coil':.5,'BendL':1/30,'BendR':1/30}
for ix,(name,dur) in enumerate(clips.items(),2):
 paths=[render(name,dur*u,'side' if name in ['TailStrike','Recoil'] else 'top',f'{name} · {int(u*100)}%',f'{name}_{k}') for k,u in enumerate([0,.25,.5,.75])]
 sheet(paths,2,f'{ix:02}-phases-{name}.jpg')
# Additional extreme poses: early strike maximum, lower maximum, and Recoil peak.
sheet([render(n,t,v,label,key) for n,t,v,label,key in [('TailStrike',.2,'side','Замах · 0,20 с','ext0'),('TailStrike',.55,'side','Удар · 0,55 с','ext1'),('Recoil',.5,'front','Отход · 0,50 с','ext2'),('Coil',.25,'top','Взвод · 0,25 с','ext3')]],2,'08-extremes.jpg')
# Import old asset into a separate collection, using its original animation action for comparison.
oldpaths=[]
newpaths=[render('TailStrike',i/20,'side','Стало · удар 0,9 с',f'new_{i}') for i in range(19)]
# Save new armature objects, hide them, import old file.
newobjs=[o for o in s.objects if o.type in ['ARMATURE','MESH']]
for o in newobjs:o.hide_render=True
oldacts=set(bpy.data.actions);bpy.ops.import_scene.gltf(filepath=str(out.parents[1]/'models/serpohvost-anim.glb'))
oldarm=next(o for o in s.objects if o.type=='ARMATURE' and o!=arm);oldact=next(a for a in bpy.data.actions if a not in oldacts and a.name.startswith('TailStrike'))
oldmeshes=[o for o in s.objects if o.type=='MESH' and o not in newobjs]
for o in oldmeshes:
 if not any(m.type=='ARMATURE' for m in o.modifiers):o.hide_render=True
savedarm=arm;arm=oldarm;acts['OldStrike']=oldact
oldlen=(oldact.frame_range[1]-oldact.frame_range[0])/60
for i in range(19):oldpaths.append(render('OldStrike',min(i/20,oldlen),'side',f'Было · {oldlen:.1f} с',f'old_{i}'))
gif([[a,b] for a,b in zip(oldpaths,newpaths)],out/'09-tailstrike-before-after.gif')
for o in oldmeshes:o.hide_render=True
oldarm.hide_render=True
arm=savedarm
for o in newobjs:
 if o.type=='ARMATURE' or any(m.type=='ARMATURE' for m in o.modifiers):o.hide_render=False
frames=[]
for name,dur in [('Coil',.5),('SwimFast',1.2),('TailStrike',.9),('Recoil',1),('Swim',2.4)]:
 for i in range(round(dur*20)):frames.append([render(name,i/20,'side',name,f'seq_{name}_{i}')])
gif(frames,out/'10-attack-sequence.gif')
print('PREVIEWS COMPLETE',[(p.name,p.stat().st_size) for p in out.iterdir() if p.suffix in ['.jpg','.gif']])
