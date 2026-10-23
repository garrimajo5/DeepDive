extends Node3D
# Artist's analytical motion reference. Parent: BreachView.spot_node, +Z inward.
var counts: Array[int]=[48,32,32]
var groups: Array[MultiMeshInstance3D]=[]
var material: ShaderMaterial
var water_h:=0.1
var hole_y:=1.0
var welding:=false
var clock:=0.0
var live:=false
var hit_z:=2.3
var jet_life:=0.65
var bounds_min_y:=100.0
var bounds_splash_min:=100.0
func _ready()->void:
 material=ShaderMaterial.new()
 material.shader=load("res://art/ART-072-proboina-chastitsy/src/particles.gdshader")
 material.set_shader_parameter("atlas",ImageTexture.create_from_image(Image.load_from_file("res://art/ART-072-proboina-chastitsy/proboina-atlas.png")))
 material.set_shader_parameter("water_tint",Color("C0E1EB"))
 material.set_shader_parameter("spark_hot",Color("FFF2D5"))
 material.set_shader_parameter("spark_cool",Color("F18A3D"))
 var d:=Vector3(0,Breach.JET_UP,1).normalized()*Breach.JET_V
 jet_life=(d.y+sqrt(d.y*d.y+2.0*Breach.JET_G*(hole_y-water_h)))/Breach.JET_G
 hit_z=d.z*jet_life
 for n in 3:
  var q:=QuadMesh.new();q.size=Vector2.ONE;q.material=material
  var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.mesh=q;mm.instance_count=counts[n]
  var m:=MultiMeshInstance3D.new();m.multimesh=mm;m.layers=OceanView.LAYER_SHIP;m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  add_child(m);groups.append(m)
 groups[2].visible=welding
 sample(0.0)
func put(g:int,i:int,pos:Vector3,vel:Vector3,size:Vector2,a:float,alpha:float,kind:float)->void:
 var b:=Basis(Vector3(size.x,0,0),Vector3(0,size.y,0),vel)
 groups[g].multimesh.set_instance_transform(i,Transform3D(b,pos))
 groups[g].multimesh.set_instance_custom_data(i,Color(a,alpha,kind,0))
func sample(t:float)->void:
 var d:=Vector3(0,Breach.JET_UP,1).normalized()*Breach.JET_V
 bounds_min_y=100.0;bounds_splash_min=100.0
 for i in counts[0]:
  var a:=fmod(float(i)/counts[0]+t/jet_life,1.0);var s:=a*jet_life
  var angle:=float(i)*2.39996
  var pos:=Vector3(sin(angle)*(0.035+0.18*s*s),d.y*s-0.5*Breach.JET_G*s*s,0.05+d.z*s)
  var vel:=Vector3(0.36*s*sin(angle),d.y-Breach.JET_G*s,d.z)
  var size:=Vector2(0.14+0.18*a,0.30+0.12*a)
  if counts[0]<48: size.y*=1.45
  var alpha:float=0.58*smoothstep(0.0,0.025,a)*(1.0-smoothstep(0.85,1.0,a))
  put(0,i,pos,vel,size,a,alpha,0.0)
 for i in counts[1]:
  var a:=fmod(float(i)/counts[1]+t/0.45,1.0);var s:=a*0.45;var angle:=float(i)*2.39996
  var h:=0.06+0.10*sin(a*PI)
  var y:float=maxf(0.0,0.9*s-4.5*s*s)
  var pos:=Vector3(sin(angle)*0.75*s,water_h-hole_y+0.012+y+h*0.5,hit_z+cos(angle)*0.75*s)
  bounds_splash_min=minf(bounds_splash_min,pos.y-h*0.5)
  put(1,i,pos,Vector3(0,1,0.01),Vector2(0.12+0.25*a,h),a,0.45*smoothstep(0.0,0.08,a)*(1.0-smoothstep(0.15,1.0,a)),1.0)
 for i in counts[2]:
  var a:=fmod(float(i)/counts[2]+t/0.72,1.0);var s:=a*0.72;var angle:=float(i)*2.39996
  var v:=Vector3(sin(angle)*1.5,-0.7+0.6*cos(angle),0.8+absf(cos(angle))*1.4)
  var wet:=water_h>0.02
  var floor_y:float=(water_h if wet else 0.0)-hole_y+0.015
  var quench:=1.0
  var impact:float=(v.y+sqrt(v.y*v.y-18.0*(floor_y-0.02)))/9.0
  var pos:=Vector3(0.11,0.02,0.10)+v*s+Vector3(0,-4.5*s*s,0)
  var vel:=v+Vector3(0,-9.0*s,0)
  if s>impact:
   var u:=s-impact;var rebound:float=0.0 if wet else absf(v.y-9.0*impact)*0.23
   if wet: quench=1.0-smoothstep(0.0,0.08,u)
   pos=Vector3(0.11+v.x*impact+v.x*0.55*u,floor_y+maxf(0.0,rebound*u-4.5*u*u),0.10+v.z*impact+v.z*0.55*u)
   vel=Vector3(v.x*0.55,rebound-9.0*u,v.z*0.55)
  pos.y=maxf(floor_y,pos.y)
  bounds_min_y=minf(bounds_min_y,pos.y)
  put(2,i,pos,vel,Vector2(0.12,clampf(vel.length()*0.09,0.12,0.32)),a,quench*smoothstep(0.0,0.02,a)*(1.0-smoothstep(0.55,1.0,a))*0.95,2.0)
 # One of the 32 instances is the stationary electrode flash, not an extra system.
 put(2,counts[2]-1,Vector3(0.11,0.02,0.11),Vector3(0,1,0.01),Vector2(0.13,0.13),0.0,0.8,3.0)
func _process(dt:float)->void:
 if live:
  clock+=dt;sample(clock)
