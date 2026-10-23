shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform vec4 tint : source_color = vec4(0.78,0.86,0.9,1.0);
varying float age;
varying float opacity;
void vertex(){
 age=INSTANCE_CUSTOM.x;
 opacity=INSTANCE_CUSTOM.y;
 mat4 mv=VIEW_MATRIX*MODEL_MATRIX;
 float sx=length(MODEL_MATRIX[0].xyz);
 float sy=length(MODEL_MATRIX[1].xyz);
 MODELVIEW_MATRIX=mat4(vec4(sx,0.,0.,0.),vec4(0.,sy,0.,0.),vec4(0.,0.,1.,0.),mv[3]);
}
vec4 frame(float n, vec2 uv){
 vec2 cell=vec2(mod(n,4.),floor(n/4.));
 return texture(atlas,(cell+clamp(uv,vec2(0.008),vec2(0.992)))/4.);
}
void fragment(){
 float n=clamp(age,0.,1.)*15.;
 vec4 a=frame(floor(n),UV); vec4 b=frame(min(floor(n)+1.,15.),UV);
 float w=smoothstep(0.,1.,fract(n));
 // Blend in premultiplied space; output straight alpha. No dark edge.
 float alpha=mix(a.a,b.a,w);
 vec3 rgb=mix(a.rgb*a.a,b.rgb*b.a,w)/max(alpha,0.0001);
 ALBEDO=rgb*tint.rgb;
 ALPHA=alpha*opacity*tint.a;
}
