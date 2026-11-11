from pathlib import Path
H=Path(__file__).resolve().parent
code=(H/'render.py').read_text();exec(compile(code[:code.index("for sex in ['muzhchina'")],str(H/'render.py'),'exec'))
from mathutils import Matrix
out=ROOT/'v2'/'renders'
for sex in ['muzhchina','zhenshchina']:
 for version in ['before','after']:
  for role in ['engineer','biologist']:
   bpy.ops.import_scene.gltf(filepath=str((ROOT if version=='before' else ROOT/'v2')/('ekipazh-'+sex+'.glb')))
   added=set(bpy.data.objects)-base;arm=next(o for o in added if o.type=='ARMATURE');ad=arm.animation_data;actions={t.name:t.strips[0].action for t in ad.nla_tracks};ad.use_nla=False;ad.action=actions['Walk'];sc.frame_set(7);bpy.context.view_layer.update()
   gearlist=[('gear-fartuk','Spine01',(0,1.3,0)),('gear-shchitok','Head',(0,1.7,-.075))] if role=='engineer' else [('gear-tunika','Spine01',(0,1.3,0)),('gear-proby','Hips',(0,1.03,0))]
   for name,bn,point in gearlist:
    prior=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(ROOT.parents[1]/'models'/(name+'.glb')));gear=set(bpy.data.objects)-prior
    x,y,z=point;transform=arm.matrix_world@arm.pose.bones[bn].matrix@arm.data.bones[bn].matrix_local.inverted()@Matrix.Translation((x,-z,y))
    if name in ('gear-fartuk','gear-tunika'):
     fit={'muzhchina':{'gear-fartuk':((.73,.89,.84),(0,0,-.01)),'gear-tunika':((.70,.99,.87),(0,.033,0))},'zhenshchina':{'gear-fartuk':((.78,.87,.77),(0,-.047,0)),'gear-tunika':((.75,.93,.74),(0,.032,.01))}}[sex][name];scale,shift=fit;transform=transform@Matrix.Translation((shift[0],-shift[2],shift[1]))@Matrix.Diagonal((scale[0],scale[2],scale[1],1))
    for obj in gear:
     if obj.parent not in gear:obj.matrix_world=transform@obj.matrix_world
   camera('three');sc.render.filepath=str(out/(sex+'-'+role+'-'+version+'.png'));bpy.ops.render.render(write_still=True)
   for obj in set(bpy.data.objects)-base:bpy.data.objects.remove(obj,do_unlink=True)
