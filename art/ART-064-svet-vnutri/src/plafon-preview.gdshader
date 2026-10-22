shader_type spatial;
render_mode cull_back;
uniform sampler2D diffuser:source_color,filter_linear,repeat_disable;
uniform bool bridge=true;
uniform bool alarm=false;
uniform float pulse=1.0;
uniform float lamp_k=1.0;
varying vec3 pos;
void vertex(){pos=VERTEX;}
void fragment(){
 vec2 p;
 if(bridge){float z=-5.0+floor((pos.z+5.0)/1.5+0.5)*1.5;p=vec2((pos.z-z)/0.4+0.5,(pos.y-2.35)/0.28+0.5);}
 else{p=vec2(pos.x/0.15+0.5,fract(pos.z/0.4));}
 vec4 t=texture(diffuser,clamp(p,vec2(0),vec2(1)));
 float l=dot(t.rgb,vec3(0.2126,0.7152,0.0722));
 vec3 tint=bridge?(pos.x<0.0?vec3(1.0,.77,.46):vec3(.48,.76,.88)):vec3(.78,.85,.88);
 float k=.75;
 if(!bridge){
 if(pos.z<8.0)tint=vec3(.88,.75,.54);
 else if(pos.z<14.0)tint=vec3(.48,.81,.86);
 else if(pos.z<19.5)tint=vec3(.90,.69,.44);
}
 if(alarm){
 if((bridge&&pos.x<0.0)||(!bridge&&pos.z>8.0&&pos.z<14.0)){tint=vec3(.40,.74,.84);k=.25;}
 else{tint=vec3(1.0,.447,.1);k=.22+.48*pulse;}
 }
 ALBEDO=mix(vec3(.06,.055,.045),t.rgb*.2,t.a);
 EMISSION=tint*l*t.a*k*lamp_k;
 ROUGHNESS=.65;SPECULAR=.15;
}
