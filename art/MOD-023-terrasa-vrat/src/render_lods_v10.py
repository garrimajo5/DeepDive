import bpy,pathlib,math,numpy as np
from mathutils import Vector
p=pathlib.Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.ops.import_scene.gltf(filepath=str(p/'terrasa-draft-v10.glb'))
for o in bpy.context.scene.objects:
 if o.type=='MESH' and o.name.startswith(('LOD1_','LOD2_')):o.hide_render=True
bpy.ops.object.light_add(type='AREA',location=(0,-70,90));l=bpy.context.object;l.data.energy=250000;l.data.shape='DISK';l.data.size=100;l.rotation_euler=(Vector((0,0,25))-l.location).to_track_quat('-Z','Y').to_euler()
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=16;s.cycles.use_denoising=True;s.render.resolution_x=512;s.render.resolution_y=512;s.render.resolution_percentage=100;s.world.color=(.012,.025,.04)
bpy.ops.object.camera_add();cam=bpy.context.object;cam.data.type='ORTHO';s.camera=cam
mat=bpy.data.materials.new('Ruler');mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.7,.85,.9,1);bs.inputs['Emission Color'].default_value=(.7,.85,.9,1);bs.inputs['Emission Strength'].default_value=1
font=bpy.data.fonts.load('C:/Windows/Fonts/arial.ttf');overlays=[]
def text(body,loc,size,rot):
 c=bpy.data.curves.new('Caption','FONT');c.body=body;c.font=font;c.size=size;o=bpy.data.objects.new('Caption',c);bpy.context.collection.objects.link(o);o.location=loc;o.rotation_euler=rot;o.data.materials.append(mat);overlays.append(o)
def line(a,b,r):
 c=bpy.data.curves.new('Scale','CURVE');c.dimensions='3D';c.bevel_depth=r;c.bevel_resolution=0;sp=c.splines.new('POLY');sp.points.add(1);sp.points[0].co=(*a,1);sp.points[1].co=(*b,1);o=bpy.data.objects.new('Scale',c);bpy.context.collection.objects.link(o);o.data.materials.append(mat);overlays.append(o)
views=[(f'LOD{i}',(0,-190,29),(0,0,29),140,20) for i in range(3)]
images=[]
for i,(title,pos,target,scale,metres) in enumerate(views):
 for ob in bpy.context.scene.objects:
  if ob.type=='MESH' and ob.name.startswith('LOD'):ob.hide_render=not ob.name.startswith(f'LOD{i}_')
 for o in overlays:bpy.data.objects.remove(o,do_unlink=True)
 overlays=[];target=Vector(target);cam.location=pos;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
 q=cam.rotation_euler.to_quaternion();right=q@Vector((1,0,0));up=q@Vector((0,1,0));toward=q@Vector((0,0,1));plane=target+toward*min(100,(cam.location-target).length*.5)
 text(title,plane-right*scale*.46+up*scale*.43,scale*.032,cam.rotation_euler)
 a=plane-right*scale*.43-up*scale*.4;b=a+right*metres;line(a,b,scale*.0015)
 for point in (a,b):line(point-up*scale*.008,point+up*scale*.008,scale*.0015)
 text(str(metres)+' м',a+up*scale*.02,scale*.03,cam.rotation_euler)
 if i==3:
  lid=bpy.data.objects['Stvorka2'];lid.rotation_mode='XYZ';lid.rotation_euler.x=-math.pi/2
 s.render.filepath=str(p/f'lod-view-v10-{i}.png');bpy.ops.render.render(write_still=True);im=bpy.data.images.load(s.render.filepath);images.append(np.array(im.pixels[:],dtype=np.float32).reshape(512,512,4))
a=np.concatenate(images,axis=1);out=bpy.data.images.new('LOD Preview',1536,512);out.pixels.foreach_set(a.ravel());out.filepath_raw=str(p/'lods-v10.png');out.file_format='PNG';out.save()
