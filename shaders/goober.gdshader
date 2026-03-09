shader_type canvas_item;

const float gas = 20.0;
void fragment() {
	COLOR = texture(TEXTURE, vec2(1.0, (1.0+.1*asin(sin(2.0*pow(mod(TIME, gas), 2)))))*(UV - vec2(0.0, .1*(1.0+asin(sin(2.0*pow(mod(TIME, gas), 2)))))));
}

