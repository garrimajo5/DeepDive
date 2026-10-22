shader_type spatial;
render_mode cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D mask_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D norm_tex : hint_normal, filter_linear_mipmap, repeat_disable;
void fragment(){
 float pane=UV.x<0.328947?0.0:(UV.x<0.671053?1.0:2.0);
 float start=pane<0.5?0.0:(pane<1.5?0.328947:0.671053);
 float span=pane==1.0?0.342106:0.328947;
 vec2 uv=vec2((UV.x-start)/span,UV.y);
 if(pane==1.0){uv.x=1.0-uv.x;}
 if(pane>1.5){uv.y=1.0-uv.y;}
 vec4 m=texture(mask_tex,uv);
 vec3 n=texture(norm_tex,uv).rgb;
 if(pane==1.0){n.r=1.0-n.r;}
 if(pane>1.5){n.g=1.0-n.g;}
 ALBEDO=mix(vec3(0.60,0.85,0.90),vec3(0.83,0.83,0.77),m.r);
 ALPHA=0.07+0.26*m.a;
 ROUGHNESS=clamp(0.12+0.5*m.r+0.14*m.g,0.12,0.7);
 SPECULAR=0.55;
 NORMAL_MAP=n;
 NORMAL_MAP_DEPTH=0.12;
}
