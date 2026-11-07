shader_type spatial;
render_mode unshaded;
uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform vec3 values=vec3(0.0,20.0,0.0); // heading, depth, speed
uniform vec3 k=vec3(1.0);
uniform vec2 status=vec2(1.0,1.0);
varying vec2 pos;
void vertex(){pos=VERTEX.xy;}
float glyph(vec2 p,vec2 start,vec2 size,float index){
 vec2 q=(p-start)/size;
 if(q.x<0.0||q.y<0.0||q.x>1.0||q.y>1.0)return 0.0;
 vec2 uv=(vec2(index*64.0+12.0,384.0)+q*vec2(40.0,64.0))/vec2(1024.0,512.0);
 return texture(atlas,uv).a;
}
void fragment(){
 float panel=pos.x<-.48?0.0:(pos.x>.48?2.0:1.0);
 vec2 q=vec2((pos.x+.36)/.72,(1.32-pos.y)/.30);
 if(panel==0.0)q=vec2((pos.x+1.03)/.44,(1.22-pos.y)/.19);
 if(panel==2.0)q=vec2((pos.x-.59)/.44,(1.22-pos.y)/.19);
 q=clamp(q,vec2(.006),vec2(.994));
 vec2 p=q*vec2(320,136);
 vec3 col=texture(atlas,(vec2(panel*352.0,0.0)+p)/vec2(1024,512)).rgb;
 float ink=0.0;
 if(panel==0.0){
  float h=floor(values.x+.5);
  ink+=glyph(p,vec2(126,40),vec2(36,58),floor(h/100.0));
  ink+=glyph(p,vec2(162,40),vec2(36,58),mod(floor(h/10.0),10.0));
  ink+=glyph(p,vec2(198,40),vec2(36,58),mod(h,10.0));
  ink+=glyph(p,vec2(236,35),vec2(26,40),12.0);
  float tri=step(89.0,p.y)*step(p.y,102.0)*step(abs(p.x-160.0),(p.y-89.0)*.5);ink=max(ink,tri);
 }
 if(panel==1.0){
  float dd=floor(values.y*10.0+.5);
  if(dd>=1000.0){ink+=glyph(p,vec2(10,32),vec2(18,42),floor(dd/1000.0));}
  ink+=glyph(p,vec2(28,32),vec2(18,42),mod(floor(dd/100.0),10.0));
  ink+=glyph(p,vec2(46,32),vec2(18,42),mod(floor(dd/10.0),10.0));
  ink+=glyph(p,vec2(64,32),vec2(10,42),10.0);
  ink+=glyph(p,vec2(76,32),vec2(18,42),mod(dd,10.0));
  float sp=floor(abs(values.z)*10.0+.5);
  if(values.z<-.05)ink+=glyph(p,vec2(68,82),vec2(20,42),14.0);
  ink+=glyph(p,vec2(92,82),vec2(24,42),floor(sp/10.0));
  ink+=glyph(p,vec2(116,82),vec2(14,42),10.0);
  ink+=glyph(p,vec2(134,82),vec2(24,42),mod(sp,10.0));
 }
 if(panel==2.0){
  ink+=smoothstep(13.0,11.0,length(p-vec2(282,28)))*status.x;
  ink+=smoothstep(13.0,11.0,length(p-vec2(282,100)))*status.y;
 }
 float kk=panel==0.0?k.x:(panel==1.0?k.y:k.z);
 col=mix(col,vec3(.13,.72,.83),clamp(ink,0.0,1.0));
 ALBEDO=col*.55*kk;
 EMISSION=col*.15*kk;
}
