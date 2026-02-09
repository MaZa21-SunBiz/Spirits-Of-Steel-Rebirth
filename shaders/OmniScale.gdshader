shader_type canvas_item;

const float max_dist = 5.0;
const float increment = 6.28/8.0;
const float ratio = 9.0/16.0;
const vec3 sea = vec3(126, 142, 158)/255.0;
const vec3 sea_border = vec3(105, 118, 132)/255.0;

void fragment(){
	for (float dist=0.0; dist <= max_dist; dist++) {
		for (float angle = 0.0; angle<6.28; angle+=increment) {
			vec4 color1 = texture(TEXTURE, UV + dist/600.0*vec2(ratio*cos(angle), sin(angle)));
			if (COLOR.rgb == vec3(0.0) && color1.rgb != vec3(0.0)) {
				COLOR.rgb = color1.rgb;
				break;
			} else if ((COLOR.rgb == sea || COLOR.rgb == sea_border)
			&& (color1.rgb != sea && color1.rgb != sea_border)) {
				COLOR.rgb += 0.2*(0.4 - vec3(dist/10.0));
				break;
			} else if ((COLOR.rgb != sea && COLOR.rgb != sea_border) && (COLOR.rgb != color1.rgb) && color1.rgb != vec3(0.0)) {
				COLOR.rgb += 0.3*(0.4 - vec3(dist/10.0));
				break;
			}
		}
	}
}
