shader_type spatial;
// ART-077 preview only. Keep the native glass mesh, UV split, lights and ART-057 maps.
render_mode blend_mix, cull_disabled, depth_draw_never, fog_disabled;
uniform vec3 tint : source_color = vec3(0.6, 0.85, 0.9);
uniform sampler2D mask : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_disable;
uniform vec2 split = vec2(0.328947, 0.671053);
uniform float normal_depth = 0.12;
uniform bool relief = true;
uniform sampler2D condensation : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D scene_color : hint_screen_texture, filter_linear, repeat_disable;
uniform float humidity = 0.0;
uniform float ice_k = 0.0;
uniform float gain = 1.0;
void fragment() {
 float u=UV.x;
 vec2 uv; vec2 flip=vec2(1.0);float section_width;
 if(u<split.x){uv=vec2(u/split.x,UV.y);section_width=split.x;}
 else if(u<split.y){section_width=split.y-split.x;uv=vec2(1.0-(u-split.x)/section_width,UV.y);flip.x=-1.0;}
 else{section_width=1.0-split.y;uv=vec2((u-split.y)/section_width,1.0-UV.y);flip.y=-1.0;}
 vec2 dx=dFdx(UV)*vec2(1.0/section_width,1.0);
 vec2 dy=dFdy(UV)*vec2(1.0/section_width,1.0);
 vec4 m=textureGrad(mask,uv,dx,dy);
 vec4 c=textureGrad(condensation,uv,dx,dy); // extra read 1, both quality levels
 float gate=smoothstep(c.a,c.a+0.18,humidity)*gain;
 float drops=max(c.r,c.g*0.65)*gate;
 float bead=smoothstep(0.10,0.32,c.r)*(1.0-smoothstep(0.60,0.95,c.r))*gate;
 float frost=c.b*ice_k*gate;
 float base_alpha=relief ? 0.07+0.26*m.a : 0.07+0.12*m.a;
 ALBEDO=tint; METALLIC=0.0;
 SPECULAR=0.55*mix(0.3,1.0,smoothstep(0.0,0.15,m.a));
 ROUGHNESS=relief ? clamp(0.12+0.50*m.r+0.14*m.g,0.12,0.70) : 0.6;
 ALPHA=base_alpha;
 if(relief){
  vec3 n=textureGrad(normal_map,uv,dx,dy).rgb*2.0-1.0;
  n.xy*=flip;
  // Height derivative in window UV, converted to metres per 2.5 x 1.9 m pane.
  // Derive before gate: a changing humidity threshold cannot create a false ridge.
  float h=0.0006*c.r+0.00025*c.g;
  vec2 qx=dx*flip; vec2 qy=dy*flip;
  float det=qx.x*qy.y-qx.y*qy.x;
  vec2 dh=vec2(dFdx(h),dFdy(h));
  vec2 slope=vec2(0.0);
  if(abs(det)>1e-12) slope=vec2(dh.x*qy.y-dh.y*qx.y, qx.x*dh.y-qy.x*dh.x)/det/vec2(2.5,1.9);
  slope=clamp(slope,vec2(-0.35),vec2(0.35))*flip*gate;
  if (dot(slope,slope)>0.0) n=normalize(vec3(n.xy+vec2(-slope.x,slope.y)/max(normal_depth,0.01),n.z));
  NORMAL_MAP=n*0.5+0.5; NORMAL_MAP_DEPTH=normal_depth;
  float dc=0.60*drops*(1.0-frost);
  float fc=0.72*frost;
  float bc=0.09*bead;
  float a=1.0-(1.0-base_alpha)*(1.0-dc)*(1.0-fc)*(1.0-bc);
  vec3 cold=vec3(0.38,0.62,0.70); // linear, approx sRGB #A6CEDA
  ALBEDO=(tint*base_alpha+cold*(fc+bc*(1.0-fc))*(1.0-base_alpha))/a;
  SPECULAR=SPECULAR*base_alpha/a+0.25*drops;
  ROUGHNESS=mix(ROUGHNESS,0.08,drops*0.8);
  ROUGHNESS=mix(ROUGHNESS,0.86,frost);
  // Opaque exterior only, a bounded small offset; no probe or extra geometry.
  vec3 bend=TANGENT*(-slope.x)+BINORMAL*slope.y;
  vec2 offset=clamp(bend.xy*vec2(1.0,-1.0)*0.009,vec2(-0.002),vec2(0.002));
  vec3 behind=texture(scene_color,clamp(SCREEN_UV+offset,vec2(0.001),vec2(0.999))).rgb; // extra read 2
  EMISSION=behind*((1.0-base_alpha)*dc*(1.0-fc)*(1.0-bc)/a);
  ALPHA=a;
 }else{
  float fc=0.42*frost;
  ALPHA=1.0-(1.0-base_alpha)*(1.0-0.16*drops-fc);
  ALBEDO=mix(tint,vec3(0.38,0.62,0.70),frost);
  ROUGHNESS=mix(0.6,0.85,frost);
 }
}
