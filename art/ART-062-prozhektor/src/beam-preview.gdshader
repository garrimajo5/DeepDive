shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform sampler2D mask_tex : filter_linear, repeat_enable;
uniform vec4 beam_color : source_color = vec4(0.81,0.965,1.0,0.06);
uniform float fog_density=0.018;
uniform float silt_k=0.0;
uniform float phase=0.0;
uniform float edge_power=1.2;
varying vec2 beam_uv;
void vertex(){
 beam_uv=vec2(atan(VERTEX.y,VERTEX.x)/6.2831853+0.5,clamp(-VERTEX.z/55.0,0.0,1.0));
}
void fragment(){
 vec2 p=beam_uv+vec2(phase*0.006,-phase*0.014);
 float m=texture(mask_tex,p).r;
 float facing=abs(dot(normalize(NORMAL),normalize(VIEW)));
 float trans=exp(-fog_density*length(VERTEX));
 float variation=0.28+0.72*m;
 ALBEDO=beam_color.rgb*COLOR.r*beam_color.a*pow(facing,edge_power)*variation*trans*(1.0-0.25*silt_k);
}
