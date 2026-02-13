shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D og_map : filter_nearest;
const float ratio = 625.0 / 1275.0;
uniform float c;
const float dist = 0.5 / 625.0;

void fragment() {
	vec2 loop_uv = mod(UV*vec2(2.0, 1.0), vec2(1.0, 1.0));
	vec4 map_color = texture(og_map, loop_uv);
    // Define the four offsets
    vec2 offsets[4] = vec2[](
        vec2(-ratio * dist, 0.0), // left
        vec2( ratio * dist, 0.0), // right
        vec2(0.0, -dist),         // top
        vec2(0.0,  dist)          // bottom
    );

    // Accumulate samples
    vec4 sum = vec4(0.0);
    for (int i = 0; i < 4; i++) {
        sum += texture(og_map, loop_uv + c * offsets[i]);
    }

    // Average, then divide by COLOR (component-wise)
    vec4 clamped = sum / 4.0;
    clamped /= texture(og_map, loop_uv);
    clamped.a = 1.0;

    // Apply threshold on green channel
    if (clamped.g <= 0.7 || texture(og_map, loop_uv).rgb == vec3(0.0)) {
        COLOR.rgb = vec3(0.0);
    } else {
		COLOR.a = 0.0;
	}
	//COLOR = texture(og_map, UV);
}
