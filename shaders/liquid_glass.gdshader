shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 offset = vec2(-1.0, 1.0);
	float edge = 1.0/(32.0*((UV-UV*UV).x + (UV-UV*UV).y));
	//COLOR.r = edge;
	//COLOR.bg = vec2(0.0);
	COLOR = texture(SCREEN_TEXTURE,SCREEN_UV + edge * (UV - vec2(0.5)));
	COLOR.a = 1.0;
	COLOR += edge/2.0;
	// Called for every pixel the material is visible on.
}
