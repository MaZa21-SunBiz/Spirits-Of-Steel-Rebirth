shader_type canvas_item;
uniform sampler2D NOISE_PATTERN;

void fragment(){
    float noiseValue = texture(NOISE_PATTERN, SCREEN_UV).x;
    // COLOR += vec4(noiseValue)/20.0;
	float thicc = 0.02;
	float lower = 0.4;
	vec2 uhh = UV-0.5;
	float ooo = uhh.x*uhh.x+uhh.y*uhh.y;
	// float hmm = 0.5;
	float eee = (2.0 - (UV.x + UV.y))/2.0;
	//eee = pow(eee, 3.0);
	//COLOR.rgb += vec3(eee);
	COLOR.rgb *= (vec3(eee)+(1.0-eee)*lower)/(1.0+lower);
	if (0.0 < UV.x && UV.x < 1.0 && 0.0 < UV.y && UV.y < 1.0) {
		COLOR.rgb *= 1.5-vec3((ooo))/1.5;
	}
	COLOR.rgb -= vec3(noiseValue*ooo)/5.0;
	//if (0.0 < UV.x && UV.x < 1.0 && 0.0 < UV.y && UV.y < 1.0) {
	//	if (1.0-thicc < UV.x || 1.0-thicc < UV.y) {
	//		COLOR *= vec4(vec3(0.5), 1.0);
	//	}
	//	if (UV.x < thicc || UV.y < thicc) {
	//		COLOR += vec4(0.5);
	//	}
	//}
	//COLOR = vec4(vec3(hmm), 1.0);
	
}