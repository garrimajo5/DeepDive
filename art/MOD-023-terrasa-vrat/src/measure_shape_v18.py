import bpy,pathlib,numpy as np,json
p=pathlib.Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.ops.import_scene.gltf(filepath=str(p/'terrasa-vrat-v18.glb'));o=bpy.data.objects['LOD0_Mineral'];o.data.calc_loop_triangles();points=np.array([tuple(o.matrix_world@v.co) for v in o.data.vertices]);t=points[np.array([list(t.vertices) for t in o.data.loop_triangles])];a=t;b=np.roll(t,-1,axis=1)
report={'side_body_width_at_height':{},'upper_body_height_at_x':{}}
def intersections(axis,value,target):
 q=np.divide(value-a[:,:,axis],b[:,:,axis]-a[:,:,axis],out=np.zeros_like(a[:,:,axis]),where=abs(b[:,:,axis]-a[:,:,axis])>1e-8);valid=(q>=0)&(q<=1)&(abs(b[:,:,axis]-a[:,:,axis])>1e-8);return (a[:,:,target]+q*(b[:,:,target]-a[:,:,target]))[valid]
for z in [10,20,25,30,35,36]:
 x=intersections(2,z,0);x=x[x>0];report['side_body_width_at_height'][str(z)]={'inner_x':float(x.min()),'outer_x':float(x.max()),'width':float(x.max()-x.min())}
for x in [0,20,25,30]:
 z=intersections(0,x,2);z=z[z>30];report['upper_body_height_at_x'][str(x)]={'bottom':float(z.min()),'top':float(z.max()),'thickness':float(z.max()-z.min())}
(p/'shape-v18.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
