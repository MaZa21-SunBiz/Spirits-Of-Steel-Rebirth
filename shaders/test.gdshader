shader_type canvas_item;

const vec2 ocean_offset = vec2(2., 0.);

void fragment() {
	// goes to 1.0 after a day
	float daynight = 42.5*ocean_offset.x;
	COLOR.rgb = vec3(0.);
	float phase = sin(daynight/30.);
	vec2 centered_uv = 2.*UV - vec2(1.);
	COLOR.r = ceil(
				tan(PI*.25*centered_uv.y*phase)*.5
				+ sin(PI*centered_uv.x+TIME*.5)
			);
	
}

