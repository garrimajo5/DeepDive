shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D ripple : filter_linear, repeat_enable;
uniform sampler2D rings : filter_linear, repeat_disable;
uniform vec3 water_color : source_color = vec3(0.06,0.15,0.22);
uniform vec3 lamp_color : source_color = vec3(0.78,0.84,0.87);
uniform vec3 camera_ship = vec3(1.5,1.65,22.0);
uniform vec3 lamp_ship = vec3(0.0,2.98,21.75);
uniform vec2 lamp_extent=vec2(0.72,2.15);
uniform float water_y=-1.12;
uniform float clock=1.0;
uniform float amplitude=0.35;
uniform float event_age=-1.0;
uniform float event_kind=0.0;
uniform float ambient=0.36;
uniform float deepness=0.0;
uniform float lamp_k=1.0;
uniform vec2 rope_uv=vec2(0.5);
varying vec3 ship_pos;
varying vec2 water_uv;
void vertex(){ship_pos=vec3(VERTEX.x,water_y,22.+VERTEX.z);water_uv=(VERTEX.xz+vec2(1.1))/2.2;}
vec2 stamp(float frame,vec2 uv){
 vec2 cell=vec2(mod(frame,4.),floor(frame/4.));
 vec4 s=texture(rings,(cell+clamp(uv,vec2(0.008),vec2(0.992)))/4.);
 return vec2(s.r,s.a);
}
vec2 animated(float n,float end,vec2 uv){
 return mix(stamp(floor(n),uv),stamp(min(floor(n)+1.,end),uv),smoothstep(0.,1.,fract(n)));
}
vec2 event(vec2 uv){
 if(event_age<0. || event_age>1.4){return vec2(0.);}
 float extent=event_kind>0.5 ? 1.8 : 1.25;
 vec2 e=(uv-rope_uv)*2.2/extent+0.5;
 float inside=step(0.,e.x)*step(e.x,1.)*step(0.,e.y)*step(e.y,1.);
 float n=clamp(event_age/1.4,0.,1.)*7.;float end=7.;
 if(event_kind>0.5){n=8.+clamp(event_age/0.8,0.,1.)*3.;end=11.;}
 vec2 wave=animated(n,end,e);
 vec2 bubble=animated(12.+clamp(event_age/1.1,0.,1.)*3.,15.,e);
 return (wave+0.25*bubble)*smoothstep(0.,0.06,event_age)*(1.-smoothstep(1.0,1.4,event_age))*inside;
}
void fragment(){
 vec3 a=texture(ripple,water_uv*2.75+clock*vec2(0.018,0.012)).rgb*2.-1.;
 vec3 b=texture(ripple,water_uv*4.125-clock*vec2(0.012,0.015)).rgb*2.-1.;
 vec2 nxy=(a.xy+b.xy)*0.5*amplitude;
 vec2 ev=event(water_uv);
 float dx=event(water_uv+vec2(0.008,0.)).x-event(water_uv-vec2(0.008,0.)).x;
 float dz=event(water_uv+vec2(0.,0.008)).x-event(water_uv-vec2(0.,0.008)).x;
 vec3 n=normalize(vec3(nxy.x+dx*0.5,1.,nxy.y+dz*0.5));
 vec3 v=normalize(camera_ship-ship_pos);
 float f=0.02+0.98*pow(1.-clamp(dot(n,v),0.,1.),5.);
 vec3 reflection=reflect(-v,n);
 float lamp=0.;
 if(reflection.y>0.01){
  vec3 q=ship_pos+reflection*((lamp_ship.y-ship_pos.y)/reflection.y);
  vec2 d=(q.xz-lamp_ship.xz)/lamp_extent;
  lamp=exp(-d.x*d.x-pow(abs(d.y),4.));
 }
 float center=1.-smoothstep(0.0,0.67,length(water_uv-vec2(0.5)));
 float edge=min(min(water_uv.x,water_uv.y),min(1.-water_uv.x,1.-water_uv.y));
 vec3 base=water_color*(1.-0.42*center);
 vec3 sky=vec3(0.035,0.065,0.085);
 vec3 c=mix(base,sky,f*0.75);
 c+=lamp_color*lamp*lamp_k*(0.24+f*0.6);
 c+=vec3(0.08,0.16,0.20)*ambient*0.12*(1.-center*0.5);
 c+=vec3(0.07,0.13,0.16)*pow(clamp(ev.x,0.,1.),4.)*ev.y*0.6;

 ALBEDO=c;
 ALPHA=clamp(0.80+0.13*center+f*0.06+0.08*deepness,0.,0.98);
}
