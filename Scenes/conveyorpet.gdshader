shader_type canvas_item;

uniform float count = 10.0;
uniform float gas = 10.0;
void fragment() {
	vec2 clone_uv = UV;
	clone_uv.x = count * mod(UV.x, 1./count);
	float offset = floor(UV.x*count)*2.*PI/count;
	COLOR = texture(TEXTURE, clone_uv + vec2(.1*(1.0-asin(sin(offset + gas*TIME))), .1*(1.0-asin(sin(offset + 2.0*gas*TIME)))));
}

