shader_type canvas_item;
render_mode unshaded;
// Display-referred RGB. Canvas HDR 2D is off in this preview.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D lut_tex : repeat_disable, filter_linear;
uniform vec3 blue_column = vec3(0.015, 0.04, 0.925);
uniform float strength = 0.34;
uniform float identity_mode = 0.0;
void fragment() {
 vec3 c = texture(screen_tex, SCREEN_UV).rgb;
 float z = floor(clamp(c.b,0.0,1.0)*15.0+0.5);
 vec2 uv = vec2((16.0*z + c.r*15.0 + 0.5)/256.0, (c.g*15.0+0.5)/16.0);
 // LUT is affine: blue residual restores interpolation with ONE texture fetch.
 vec3 g = texture(lut_tex, uv).rgb + blue_column*(c.b-z/15.0);
 g=clamp(g,vec3(0.0),vec3(1.0));
 float peak=max(c.r,max(c.g,c.b));
 float bright=smoothstep(0.38,0.72,peak);
 float cold=smoothstep(0.08,0.22,min(c.g,c.b)-c.r);
 float lit=smoothstep(0.16,0.38,peak);
 float protect=max(bright,cold*lit);
 // Preserve original display luminance in the centre, permit a slight shadow lift.
 const vec3 Y=vec3(0.2126,0.7152,0.0722);
 float old_y=dot(c,Y), new_y=dot(g,Y);
 g*=max(1.0,old_y/max(new_y,0.00001));
 g=mix(g,c,protect);
 vec2 p=(SCREEN_UV-vec2(0.5))*2.0;
 float oval=length(p*vec2(0.90,1.0));
 float edge=smoothstep(0.36,1.28,oval);
 // Do not crush near-black gradients; emissive-looking colours and highlights bypass.
 float toe=smoothstep(0.015,0.09,old_y);
 float amount=strength*edge*(1.0-protect)*toe;
 g*=vec3(1.0-amount,1.0-amount*0.88,1.0-amount*0.65);
 COLOR=vec4(mix(clamp(g,vec3(0.0),vec3(1.0)),c,identity_mode),1.0);
}
