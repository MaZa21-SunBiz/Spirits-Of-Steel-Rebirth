shader_type canvas_item;

const float a = 0.1;
const float ratio = 625.0 / 1275.0;
const float c = 0.5 / 625.0;

void fragment() {
    vec4 first = COLOR;
    vec4 second = COLOR;

    for (float idk = -1.0; idk < 1.0; idk += a) {
        // Common calculations for both directions
        float rx = ratio * idk;
        float ym = 1.0 - idk;  // y-component magnitude for dir1

        vec2 dir1 = vec2(rx, ym);
        vec2 dir2 = vec2(rx, -ym);  // dir2 is dir1 mirrored vertically

        vec2 offset1 = c * dir1;
        vec2 offset2 = c * dir2;

        // Fetch all four samples
        vec4 tex_front1 = texture(TEXTURE, UV + offset1);
        vec4 tex_back1  = texture(TEXTURE, UV - offset1);
        vec4 tex_front2 = texture(TEXTURE, UV + offset2);
        vec4 tex_back2  = texture(TEXTURE, UV - offset2);

        // Update first candidate
        if (tex_front1 != first && tex_front1 == tex_back1) {
            first.rgb = tex_back1.rgb;
        }
        // Update second candidate
        if (tex_front2 != second && tex_front2 == tex_back2) {
            second.rgb = tex_back2.rgb;
        }
    }

    COLOR = min(first, second);
}
