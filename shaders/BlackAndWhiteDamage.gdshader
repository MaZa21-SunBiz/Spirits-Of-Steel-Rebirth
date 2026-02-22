shader_type canvas_item;
uniform sampler2D NOISE_PATTERN;

void fragment(){
	vec2 uhh = UV - 0.5;
	float ooo = uhh.x * uhh.x + uhh.y * uhh.y;
	float eee = (2.0 - UV.x - UV.y) * 0.5;
	COLOR.rgb *= vec3((eee * 0.9 + 0.1) * (1.365 - ooo * 0.606));
	COLOR.rgb -= vec3(texture(NOISE_PATTERN, SCREEN_UV).x * ooo) * 0.2;
	COLOR.rgb = vec3((COLOR.r + COLOR.g + COLOR.b) * 0.333);
}