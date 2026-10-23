shader_type spatial;
// ART-077 Eco: no screen sampler, no backbuffer request, no normal texture or derivatives of height.
render_mode blend_mix, cull_disabled, depth_draw_never, fog_disabled;
uniform vec3 tint : source_color = vec3(0.6,0.85,0.9);
uniform sampler2D mask : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D condensation : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform vec2 split = vec2(0.328947,0.671053);
uniform float humidity=0.0;
uniform float ice_k=0.0;
uniform float gain=1.0;
void fragment(){
 float u=UV.x; vec2 uv;float width;
 if(u<split.x){width=split.x;uv=vec2(u/width,UV.y);}
 else if(u<split.y){width=split.y-split.x;uv=vec2(1.0-(u-split.x)/width,UV.y);}
 else{width=1.0-split.y;uv=vec2((u-split.y)/width,1.0-UV.y);}
 vec2 dx=dFdx(UV)*vec2(1.0/width,1.0);
 vec2 dy=dFdy(UV)*vec2(1.0/width,1.0);
 vec4 m=textureGrad(mask,uv,dx,dy);
 vec4 c=textureGrad(condensation,uv,dx,dy); // sole extra read
 float gate=smoothstep(c.a,c.a+0.18,humidity)*gain;
 float drops=max(c.r,c.g*0.65)*gate;
 float frost=c.b*ice_k*gate;
 float base_alpha=0.07+0.12*m.a;
 ALBEDO=mix(tint,vec3(0.38,0.62,0.70),frost);
 METALLIC=0.0;
 SPECULAR=0.55*mix(0.3,1.0,smoothstep(0.0,0.15,m.a));
 ALPHA=1.0-(1.0-base_alpha)*(1.0-0.16*drops-0.42*frost);
 ROUGHNESS=mix(0.6,0.85,frost);
}
