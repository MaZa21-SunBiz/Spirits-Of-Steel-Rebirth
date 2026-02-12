shader_type canvas_item;

const float a = 36.0;
const float ratio = 625.0/1275.0;
const float c = 2.0/625.0;


void fragment() {
	for (float angle=0.0; angle<=6.28; angle += 6.28/a) {
		vec2 dir = vec2(ratio*cos(angle), sin(angle));
		vec2 front = UV+c*dir;
		vec2 back = UV-c*dir;
		//COLOR = texture(TEXTURE, front);
		if (texture(TEXTURE, front) != COLOR && texture(TEXTURE, back) != COLOR && texture(TEXTURE, front) == texture(TEXTURE, back)) {
			COLOR = texture(TEXTURE, back);
			if (texture(TEXTURE, back).rgb == vec3(0.0)) {
				break;
			}
		}
	}
}