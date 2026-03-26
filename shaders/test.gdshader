shader_type canvas_item;

const vec2 ocean_offset = vec2(2., 0.);
uniform float t_deg;
uniform float d_deg;


void fragment() {
	float t = radians(t_deg);
	float d = radians(d_deg);

	//float d = 2.*TIME;
	vec3 sphere_point = vec3(
		cos(UV.x*2.*PI),
		sin(UV.x*2.*PI),
		mix(-1., 1, UV.y)
	);
	vec3 sun_dir = vec3(
		sin(d)*cos(t),
		cos(d)*cos(t),
		sin(t)
	);
	
	COLOR.xyz = vec3(ceil(dot(sphere_point, sun_dir)));

}

