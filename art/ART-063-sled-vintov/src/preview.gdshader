shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D atlas : source_color,filter_linear,repeat_disable;
uniform float light_k=0.7;
varying vec2 atlas_uv;
varying float opacity;
void vertex(){
 float id=INSTANCE_CUSTOM.x;
 atlas_uv=UV*0.25+vec2(mod(id,4.0),floor(id/4.0))*0.25;
 opacity=COLOR.a;
}
void fragment(){
 vec4 tex=texture(atlas,atlas_uv);
 ALBEDO=tex.rgb*light_k;
 ROUGHNESS=0.65;
 SPECULAR=0.25;
 ALPHA=tex.a*opacity;
}
