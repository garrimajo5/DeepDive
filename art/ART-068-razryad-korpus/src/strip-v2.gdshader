shader_type spatial;
render_mode unshaded,cull_disabled,blend_add,depth_draw_never;
uniform sampler2D arcs : filter_linear,repeat_disable;
uniform float age=0.0;
varying float kind;
void vertex(){kind=COLOR.r;if(kind<0.5){VERTEX.x+=age*12.0;}}
void fragment(){
 float fr=min(floor(age*10.0),7.0);
 float a=texture(arcs,(vec2(mod(fr,4.0),floor(fr/4.0))+UV)/vec2(4.0,2.0)).r;
 float t=kind<0.5 ? (1.0-smoothstep(0.0,0.22,age)) : smoothstep(0.12,0.28,age)*(1.0-smoothstep(0.4,0.8,age));
 if(kind>1.5){
 vec2 q=UV-vec2(0.5);
 float rad=length(q);float theta=atan(q.y,q.x);
 a=exp(-rad*rad/0.008)+pow(abs(cos(theta*3.0)),24.0)*exp(-rad*rad/0.05);
 t=smoothstep(0.12,0.22,age)*(1.0-smoothstep(0.4,0.8,age));
 }
 t*=1.0-step(0.8,age);
 ALBEDO=vec3(0.11,0.89,0.68)*3.0;ALPHA=a*t;
}
