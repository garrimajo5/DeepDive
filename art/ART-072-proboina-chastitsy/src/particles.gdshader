shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform vec4 water_tint : source_color = vec4(0.75,0.88,0.92,1.0);
uniform vec4 spark_hot : source_color = vec4(1.0,0.95,0.84,1.0);
uniform vec4 spark_cool : source_color = vec4(0.94,0.54,0.24,1.0);
varying float age;
varying float opacity;
varying float group;
void vertex(){
 age=INSTANCE_CUSTOM.x; opacity=INSTANCE_CUSTOM.y; group=INSTANCE_CUSTOM.z;
 if(group>1.5 && group<2.5){ VERTEX.y-=0.5; } // spark head at trajectory, trail behind velocity
 mat4 mv=VIEW_MATRIX*MODEL_MATRIX;
 float sx=length(MODEL_MATRIX[0].xyz), sy=length(MODEL_MATRIX[1].xyz);
 vec2 velocity=(VIEW_MATRIX*vec4(MODEL_MATRIX[2].xyz,0.)).xy;
 float angle=atan(velocity.y,velocity.x)-1.5707963;
 if(group>0.5 && group<1.5){ angle=0.; }
 vec2 r=vec2(cos(angle),sin(angle));
 MODELVIEW_MATRIX=mat4(vec4(r.x*sx,r.y*sx,0.,0.),vec4(-r.y*sy,r.x*sy,0.,0.),vec4(0.,0.,1.,0.),mv[3]);
}
vec4 frame(float n, vec2 uv){
 vec2 cell=vec2(mod(n,4.),floor(n/4.));
 return texture(atlas,(cell+clamp(uv,vec2(0.008),vec2(0.992)))/4.);
}
void fragment(){
 float n=clamp(age,0.,1.)*7.; float end=7.;
 if(group>0.5){n=8.+clamp(age,0.,1.)*3.;end=11.;}
 if(group>1.5){n=12.+clamp(age,0.,1.)*2.;end=14.;}
 if(group>2.5){n=15.;end=15.;}
 vec4 a=frame(floor(n),UV), b=frame(min(floor(n)+1.,end),UV);
 float w=smoothstep(0.,1.,fract(n)); float alpha=mix(a.a,b.a,w);
 vec3 rgb=mix(a.rgb*a.a,b.rgb*b.a,w)/max(alpha,0.0001);
 vec3 tint=water_tint.rgb;
 if(group>1.5){tint=mix(spark_hot.rgb,spark_cool.rgb,smoothstep(0.05,0.70,age));}
 ALBEDO=rgb*tint;
 ALPHA=alpha*opacity;
 EMISSION=group>1.5 ? rgb*tint*1.5 : vec3(0.);
}
