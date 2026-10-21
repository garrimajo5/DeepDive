import math
M=0xffffffff
def h(x,z):
 a=(x*374761393+z*668265263)&M;a=((a^(a>>13))*1274126177)&M;a^=a>>16;return a/4294967295
def v(x,z):
 ix,iz=math.floor(x),math.floor(z);fx,fz=x-ix,z-iz;u,w=fx*fx*(3-2*fx),fz*fz*(3-2*fz);a,b,c,d=h(ix,iz),h(ix+1,iz),h(ix,iz+1),h(ix+1,iz+1);return a+(b-a)*u+(c-a)*w+(a-b-c+d)*u*w
def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def height(x,z):
 n=sum(.5**(i+1)*v(x*.006*2**i+i*17.3,z*.006*2**i-i*9.1) for i in range(4))/sum(.5**(i+1) for i in range(4));r=math.hypot(x+10,z+10);p=smooth(250,110,r);rn=v(x*.028+3.1,z*.028-1.7);ridge=1-abs(rn*2-1);e=max(abs(x),abs(z));return min(-64+(n-.5)*34+p*25+ridge**3*9*p-smooth(150,240,x)*55+smooth(285,345,e)*80+(v(x*.13,z*.13)-.5)*1.4,-7)
for x,z in [(215,90),(-170,-70),(162,-36),(-30,-148)]:print(x,z,height(x,z))
