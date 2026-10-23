shader_type spatial;
render_mode unshaded,cull_disabled,blend_add,depth_draw_never;
uniform sampler2D arcs : filter_linear,repeat_disable;
uniform float age=0.0;
varying float kind;
void vertex(){kind=COLOR.r;}
void fragment(){
 float fr=min(floor(age*10.0),7.0);
 float a=texture(arcs,(vec2(mod(fr,4.0),floor(fr/4.0))+UV)/vec2(4.0,2.0)).r;
 float t=kind<0.5 ? (1.0-smoothstep(0.0,0.22,age)) : smoothstep(0.12,0.28,age)*(1.0-smoothstep(0.4,0.8,age));
 t*=1.0-step(0.8,age);
 ALBEDO=vec3(0.11,0.89,0.68)*3.0;ALPHA=a*t;
}
