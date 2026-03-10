shader_type canvas_item;

const float gas = 40.0;
void fragment() {
	COLOR = texture(TEXTURE, UV + vec2(.1*(1.0-asin(sin(pow(mod(TIME, gas), 2)))), .1*(1.0-asin(sin(2.0*pow(mod(TIME, gas), 2))))));
}

