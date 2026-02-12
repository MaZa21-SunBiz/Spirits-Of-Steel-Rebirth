shader_type canvas_item;

const float ratio = 625.0 / 1275.0;
uniform float c;
const float dist = 0.5 / 625.0;

void fragment() {
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
        sum += texture(TEXTURE, UV + c * offsets[i]);
    }

    // Average, then divide by COLOR (component-wise)
    vec4 clamped = sum / 4.0;
    clamped /= COLOR;
    clamped.a = 1.0;

    // Apply threshold on green channel
    if (clamped.g <= 0.7) {
        COLOR.rgb = vec3(0.0);
    }
}
