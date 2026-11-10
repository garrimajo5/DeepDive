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
 if(index==12.0)uv=(vec2(789.0,393.0)+q*vec2(22.0,24.0))/vec2(1024.0,512.0);
 if(index==11.0)uv=(vec2(716.0,397.0)+q*vec2(40.0,38.0))/vec2(1024.0,512.0);
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
  float v=abs(values.z); float n=floor(v*10.0+.5);
  ink+=glyph(p,vec2(95,40),vec2(30,58),mod(floor(n/10.0),10.0));
  ink+=glyph(p,vec2(126,40),vec2(14,58),10.0);
  ink+=glyph(p,vec2(141,40),vec2(30,58),mod(n,10.0));
  ink+=glyph(p,vec2(186,56),vec2(20,32),11.0);
  ink+=glyph(p,vec2(207,56),vec2(18,32),13.0);
  ink+=glyph(p,vec2(226,56),vec2(20,32),15.0);
 } if(panel==1.0){
  col=vec3(.015,.04,.055);
  float d=floor(values.y+.5); float h=floor(values.x+.5);
  ink+=glyph(p,vec2(75,4),vec2(13,66),mod(floor(d/100.0),10.0));
  ink+=glyph(p,vec2(88,4),vec2(13,66),mod(floor(d/10.0),10.0));
  ink+=glyph(p,vec2(101,4),vec2(13,66),mod(d,10.0));
  ink+=glyph(p,vec2(115,24),vec2(11,34),11.0);
  ink+=glyph(p,vec2(204,4),vec2(13,66),mod(floor(h/100.0),10.0));
  ink+=glyph(p,vec2(217,4),vec2(13,66),mod(floor(h/10.0),10.0));
  ink+=glyph(p,vec2(230,4),vec2(13,66),mod(h,10.0));
  ink+=glyph(p,vec2(244,4),vec2(10,34),12.0);
 }
 if(panel==1.0 && p.x>=204.0 && p.x<=254.0){
  float tick=mod(p.x-204.0+mod(values.x,10.0)*.8,8.0);
  float bar=step(tick,1.0)*step(64.0,p.y)*step(p.y,73.0);
  float base=step(72.0,p.y)*step(p.y,73.0);
  float pointer=step(58.0,p.y)*step(p.y,63.0)*step(abs(p.x-229.0),(63.0-p.y)*.5);
  ink=max(ink,max(max(bar*.6,base*.45),pointer));
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
