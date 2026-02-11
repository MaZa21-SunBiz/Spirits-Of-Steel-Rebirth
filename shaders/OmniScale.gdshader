shader_type canvas_item;

const float ratio = 625.0/1275.0;
const float c = 0.5/625.0;

void fragment(){
	vec2 b = UV;
	vec2 topvec = vec2(0.0, 1.0);
	vec2 leftvec = vec2(ratio, 0.0);
	 //COLOR.rgb = (b+COLOR.rgb)/2.0;
	vec4 left = texture(TEXTURE, b-c*leftvec);
	vec4 right = texture(TEXTURE, b+c*leftvec);
	vec4 top = texture(TEXTURE, b-c*topvec);
	vec4 bottom = texture(TEXTURE, b+c*topvec);
	
	vec4 left2 = texture(TEXTURE, b-2.0*c*leftvec);
	vec4 right2 = texture(TEXTURE, b+2.0*c*leftvec);
	vec4 top2 = texture(TEXTURE, b-2.0*c*topvec);
	vec4 bottom2 = texture(TEXTURE, b+2.0*c*topvec);
	
	//vec4 topleft = texture(TEXTURE, b+c*(-topvec - leftvec));
	//vec4 topright = texture(TEXTURE, b+c*(-topvec + leftvec));
	//vec4 bottomleft = texture(TEXTURE, b+c*(topvec - leftvec));
	//vec4 bottomright = texture(TEXTURE, b+c*(topvec + leftvec));
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
}
