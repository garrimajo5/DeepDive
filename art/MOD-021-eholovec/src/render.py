import bpy,json,math
from pathlib import Path
from mathutils import Vector,Matrix
R=Path(__file__).parent;OUT=R.parent/'DeepDive/art/MOD-021-eholovec';stats=json.loads((R/'stats.json').read_text());bpy.ops.wm.read_factory_settings(use_empty=True)
objs={}
for name in ['telo','meshok','chelyust','uho']:
 before=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(OUT/('eholovec-'+name+'.glb')));o=next(o for o in bpy.context.scene.objects if o not in before and o.type=='MESH');objs[name]=o;o.rotation_mode='XYZ'
 if name!='uho':
  p=stats[name]['pivot_godot'];o.location=(p[0],-p[2],p[1]+.7)
left=objs['uho'];right=left.copy();right.data=left.data.copy();bpy.context.collection.objects.link(right)
for o,x in [(left,.23),(right,-.23)]:o.location=(x,-.60,.68)
right.scale.x=-1
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=24;s.render.resolution_x=900;s.render.resolution_y=650;s.render.resolution_percentage=100;s.world=bpy.data.worlds.new('world');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.08,.12,.16,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.6
s.render.film_transparent=True
bpy.ops.mesh.primitive_plane_add(size=200);floor=bpy.context.object;mat=bpy.data.materials.new('floor');mat.diffuse_color=(.025,.045,.055,1);floor.data.materials.append(mat)
for pos in [(3,-4,5),(-3,-1,3),(1,4,4)]:
 bpy.ops.object.light_add(type='AREA',location=pos);l=bpy.context.object;l.data.energy=400;l.data.size=4;l.rotation_euler=(Vector((0,0,.7))-l.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();c=bpy.context.object;c.data.type='ORTHO';c.data.ortho_scale=4.5;s.camera=c
for o,yaw,tilt in [(left,-30,20),(right,50,-15)]:o.rotation_euler=(Matrix.Rotation(math.radians(yaw),3,'Z')@Matrix.Rotation(math.radians(tilt),3,'X')).to_euler()
for i,pos in enumerate([(3,-4,2.5),(4,0,1.3),(0,-4,1.5),(0,0,6)]):
 c.location=pos;c.rotation_euler=(Vector((0,0,.7))-c.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(R/f'assembly{i}.png');bpy.ops.render.render(write_still=True)
# Extreme pointing poses: full yaw/tilt product around the base, mesh and pivot travel together.
for i,(yaw,tilt) in enumerate([(-130,-20),(130,63)]):
 for j,o in enumerate([left,right]):o.rotation_euler=(Matrix.Rotation(math.radians(yaw if j==0 else -yaw),3,'Z')@Matrix.Rotation(math.radians(tilt),3,'X')).to_euler()
 c.location=(3,-4,2.5);c.rotation_euler=(Vector((0,0,.7))-c.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(R/f'pose{i}.png');bpy.ops.render.render(write_still=True)



floor.hide_render=True
for i,k in enumerate([.9,1.1]):
 objs['meshok'].scale=(k,k,k)
 c.data.ortho_scale=1.7;c.location=(2,-4,.1);c.rotation_euler=(Vector((0,-1,.34))-c.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(R/f'breath{i}.png');bpy.ops.render.render(write_still=True)
