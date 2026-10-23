extends Node3D
var hull=15.0
var eco=false
var count=24
var mm:MultiMesh
func _ready():
 count=12 if eco else 24
 mm=MultiMesh.new()
 mm.transform_format=MultiMesh.TRANSFORM_3D
 mm.use_custom_data=true
 var q=QuadMesh.new()
 q.size=Vector2.ONE
 mm.mesh=q
 mm.instance_count=count
 var obj=MultiMeshInstance3D.new()
 obj.multimesh=mm
 obj.layers=OceanView.LAYER_SHIP
 obj.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var mat=ShaderMaterial.new()
 mat.shader=load("res://art/ART-074-ustalost-korpusa/src/particle.gdshader")
 mat.set_shader_parameter("atlas",texture_file("res://art/ART-074-ustalost-korpusa/ustalost-atlas.png"))
 obj.material_override=mat
 add_child(obj)
func sample(t:float):
 var loss=1.0-hull/100.0
 for i in count:
  var per=3 if eco else 6
  var group=i/per
  var type=0 if group<2 else (1 if group==2 else 2)
  var zone=group if group<2 else (0 if group==2 else 1)
  var index=i%per
  var p=Vector3.ZERO
  var size=Vector2.ZERO
  var alpha=0.0
  var frame=0.0
  var side=-1.0 if index%2==0 else 1.0
  var age=fposmod(t+float(index)*1.713,3.8)/3.8
  if type==0:
   var strength=smoothstep(0.38,0.82,loss)
   p=Vector3(side*(4.66 if zone==0 else 2.72),3.05-2.8*age,[-4.65,-.35,1.2][index%3] if zone==0 else [14.7,15.4,18.8][index%3])
   if zone==0 and side<0.0 and index==4: p.z=.8
   size=Vector2(.028,.12)
   alpha=strength*.8*sin(PI*age)
   frame=minf(2.999,age*3.0)
  elif type==1:
   var phase=fposmod(t+zone*4.1,9.0)
   var strength=smoothstep(.62,.86,loss)
   p=Vector3(-4.58,.38,-.98) if zone==0 else Vector3(2.78,.64,18.65)
   p+=Vector3(index*.018,-index*.026,0)
   size=Vector2(.18,.07)
   alpha=strength*.8*(1.0-phase/.16) if phase<.16 and zone==0 else 0.0
   frame=4+index%4
  else:
   var strength=smoothstep(.48,.85,loss)
   p=Vector3(-2.92,1.58,17.2)
   p+=Vector3(-side*.12*age,.48*age,.03*sin(age*6.28+index))
   size=Vector2(.12+.13*age,.26+.3*age)
   alpha=strength*.11*sin(PI*age) if zone==1 else 0.0
   frame=8.0+minf(6.999,age*7.0)
  mm.set_instance_transform(i,Transform3D(Basis().scaled(Vector3(size.x,size.y,1)),p))
  mm.set_instance_custom_data(i,Color(frame,alpha,0,0))

func texture_file(path:String):
 var im=Image.load_from_file(path)
 im.generate_mipmaps()
 return ImageTexture.create_from_image(im)
