shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,fog_disabled;
uniform sampler2D atlas : source_color,filter_linear_mipmap,repeat_disable;
varying vec4 particle;
void vertex(){
 particle=INSTANCE_CUSTOM;
 mat4 m=MODELVIEW_MATRIX;
 m[0]=vec4(length(MODEL_MATRIX[0].xyz),0,0,0);
 m[1]=vec4(0,length(MODEL_MATRIX[1].xyz),0,0);
 m[2]=vec4(0,0,1,0);
 MODELVIEW_MATRIX=m;
}
vec4 cell_sample(float f, vec2 uv){
 vec2 cell=vec2(mod(f,4.0),floor(f/4.0));
 return texture(atlas,(uv+cell)/4.0);
}
void fragment(){
 float f=particle.r;
 float last=f<4.0 ? 3.0 : (f<8.0 ? 7.0 : 15.0);
 vec4 a=cell_sample(floor(f),UV);
 vec4 b=cell_sample(min(floor(f)+1.0,last),UV);
 float t=smoothstep(0.0,1.0,fract(f));
 float alpha=mix(a.a,b.a,t);
 vec3 col=mix(a.rgb*a.a,b.rgb*b.a,t)/max(alpha,0.00001);
 ALBEDO=col;
 ALPHA=alpha*particle.g;
 EMISSION= f>=4.0 && f<8.0 ? col*particle.g*1.2 : vec3(0.0);
}
