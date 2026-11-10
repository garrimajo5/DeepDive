import bpy, math, json
from mathutils import Vector
from pathlib import Path
P=Path('C:/Users/FEDYA/Documents/ChatGPT/Pogrujenie/work/model-schedule-20261107/art/MOD-022-kupolnik')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(P/'source-v1/model.glb'))
obs=[o for o in bpy.context.scene.objects if o.type=='MESH']
pts=[o.matrix_world@v.co for o in obs for v in o.data.vertices]
lo=Vector([min(p[i] for p in pts) for i in range(3)]); hi=Vector([max(p[i] for p in pts) for i in range(3)])
c=(lo+hi)/2; size=max(hi-lo)
report={'bounds_blender':[list(lo),list(hi)],'meshes':[]}
for o in obs:
 o.data.calc_loop_triangles(); report['meshes'].append({'name':o.name,'triangles':len(o.data.loop_triangles),'vertices':len(o.data.vertices)})
 for m in o.data.materials:
  if m and m.use_nodes:
   for n in m.node_tree.nodes:
    if n.type=='BSDF_PRINCIPLED':
     for name,val in [('Metallic',0),('Roughness',.85)]:
      for l in list(n.inputs[name].links):m.node_tree.links.remove(l)
      n.inputs[name].default_value=val
(P/'source-inspection.json').write_text(json.dumps(report,indent=2))
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=12
s.render.resolution_x=640;s.render.resolution_y=640;s.render.resolution_percentage=100
s.world=bpy.data.worlds.new('World');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.035,.05,.07,1)
s.world.node_tree.nodes['Background'].inputs[1].default_value=.5
for p in [(2,-3,4),(-3,-1,2),(1,3,3)]:
 bpy.ops.object.light_add(type='AREA',location=c+Vector(p)*size);bpy.context.object.data.energy=350*size*size;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=size*3
 bpy.context.object.rotation_euler=(c-bpy.context.object.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;s.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=size*1.25
for name,pos in [('front',(0,-4,0)),('back',(0,4,0)),('side',(4,0,0)),('top',(0,0,4))]:
 cam.location=c+Vector(pos)*size;cam.rotation_euler=(c-cam.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(P/('inspect-'+name+'.png'));bpy.ops.render.render(write_still=True)
