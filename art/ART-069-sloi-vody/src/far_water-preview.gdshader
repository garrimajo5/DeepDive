shader_type spatial;
// Дальняя вода (OceanView.far_wall, issue #456): сфера вокруг камеры радиусом Seabed.FAR_WALL изнутри, цвета тумана.
// В щели между дальним краем льда и дна раньше был виден фон BG_COLOR — на Forward Mobile он темнее тумана на
// геометрии, и у горизонта шла чёрная полоса. Сфера проходит тот же туман, что и дно, — щель того же цвета.
render_mode unshaded, cull_front, shadows_disabled, depth_draw_opaque;

uniform vec3 water : source_color = vec3(0.16, 0.42, 0.50);

varying vec3 w_pos;
void vertex(){w_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
uniform vec3 base_fog : source_color=vec3(0.1);
uniform float base_density=.01;
uniform float layer_phase=0.0;
uniform float layer_gain=1.0;
uniform vec3 layer_ice : source_color=vec3(0.227,0.506,0.565);
uniform vec3 layer_thermo : source_color=vec3(0.137,0.310,0.412);
uniform vec3 layer_dust : source_color=vec3(0.169,0.325,0.349);
float soft_integral(float y,float a,float b){
 if(y<=a)return 0.0;
 if(y>=b)return y-(a+b)*0.5;
 float t=(y-a)/(b-a);
 return (b-a)*(t*t*t-0.5*t*t*t*t);
}
float band_integral(float y,float lo,float hi,float e){return soft_integral(y,lo-e,lo+e)-soft_integral(y,hi-e,hi+e);}
float segment_band(vec3 a,vec3 b,float y0,float y1){
 float e=y0< -10.0 ? 1.0:1.5;
 float dy=b.y-a.y;
 if(abs(dy)<0.0001)return (smoothstep(y0-e,y0+e,a.y)-smoothstep(y1-e,y1+e,a.y))*length(b-a);
 return max(0.0,(band_integral(b.y,y0,y1,e)-band_integral(a.y,y0,y1,e))/dy)*length(b-a);
}

void fragment() {
	ALBEDO = water;
vec3 ray_start=CAMERA_POSITION_WORLD;
 float wave=0.12*sin(w_pos.x*0.09+layer_phase*0.25)*sin(w_pos.z*0.07-layer_phase*0.15);
 float ice_len=segment_band(ray_start,w_pos,-6.0,0.0);
 float thermo_len=segment_band(ray_start,w_pos,-31.5+wave,-28.5+wave);
 float ai=min(0.11,1.0-exp(-ice_len*0.008));
 float at=min(0.10,1.0-exp(-thermo_len*0.017));
 float dust=0.0;

 float total=ai+at+dust;
 vec3 lc=(layer_ice*ai+layer_thermo*at+layer_dust*dust)/max(total,0.00001);
 float base_a=1.0-exp(-length(w_pos-ray_start)*base_density);
 float la=clamp(total*layer_gain,0.0,0.16);
 float fa=base_a+la*(1.0-base_a);
 vec3 fc=(base_fog*base_a*(1.0-la)+lc*la)/max(fa,0.00001);
 FOG=vec4(fc,fa);
}
