shader_type canvas_item;
const float ratio = 9.0/16.0;
uniform float c;
const float dist = 0.5 / 625.0;

void fragment() {
	vec2 topvec = vec2(0.0, 1.0);
	vec2 leftvec = vec2(ratio, 0.0);
	vec4 left = texture(TEXTURE, UV-dist*leftvec);
	vec4 right = texture(TEXTURE, UV+dist*leftvec);
	vec4 top = texture(TEXTURE, UV-dist*topvec);
	vec4 bottom = texture(TEXTURE, UV+dist*topvec);
	vec4 clamped = ((top+left+bottom+right)
				   //+(top2+left2+bottom2+right2)
				   )/(4.0);
	clamped /= COLOR;
	clamped.a = 1.0;
	//COLOR.rgb = vec3(clamped.g);

	if (clamped.g <= 0.7) {
		//COLOR.rgb = (COLOR.rgb + vec3(0.0))/2.0;
		COLOR.rgb = vec3(0.0);
	}
	//COLOR = texture(og_map, UV);
}
