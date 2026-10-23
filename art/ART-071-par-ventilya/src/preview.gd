extends Node3D
# Artistic reference, not installed into the game. CPU age/position, one MultiMesh.
var mm: MultiMesh
var material: ShaderMaterial
var clock:=0.0
var count:=48
var lifetime:=1.25
var live:=false
func _ready() -> void:
 var q:=QuadMesh.new()
 q.size=Vector2.ONE
 material=ShaderMaterial.new()
 material.shader=load("res://art/ART-071-par-ventilya/src/par.gdshader")
 material.set_shader_parameter("atlas",ImageTexture.create_from_image(Image.load_from_file("res://art/ART-071-par-ventilya/par-atlas.png")))
 q.material=material
 mm=MultiMesh.new()
 mm.transform_format=MultiMesh.TRANSFORM_3D
 mm.use_custom_data=true
 mm.mesh=q
 mm.instance_count=count
 var m:=MultiMeshInstance3D.new()
 m.multimesh=mm
 m.layers=OceanView.LAYER_SHIP
 m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(m)
 sample(0.0)
func sample(t:float) -> void:
 for i in count:
  var a:=fmod(float(i)/count+t/lifetime,1.0)
  var seconds:=a*lifetime
  var seed_angle:=float(i)*2.39996
  var outward:=0.70*seconds/(1.0+2.5*seconds)
  var rise:=0.75*seconds-0.10*seconds*seconds-0.30*smoothstep(0.62,1.0,a)
  var spread:=sin(a*PI)*0.075
  var pos:=EngineRoom.VALVE_POS+Vector3(0.18+outward,0.12+rise,0.0)+Vector3(0,cos(seed_angle),sin(seed_angle))*spread
  var size:=lerpf(0.09,0.42,smoothstep(0.0,0.85,a))
  var tr:=Transform3D(Basis.from_scale(Vector3(size*(0.6+0.4*a),size,1.0)),pos)
  mm.set_instance_transform(i,tr)
  var fade:=smoothstep(0.0,0.045,a)*(1.0-smoothstep(0.55,1.0,a))*0.25
  mm.set_instance_custom_data(i,Color(a,fade,0,0))
func _process(dt:float)->void:
 if live:
  clock+=dt
  sample(clock)
