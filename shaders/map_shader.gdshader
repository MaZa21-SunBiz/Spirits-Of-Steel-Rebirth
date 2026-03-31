shader_type canvas_item;

const float max_dist = 5.0;
const float increment = 6.28/8.0;
const vec3 sea = vec3(126, 142, 158)/255.0;
const vec3 sea_border = vec3(105, 118, 132)/255.0;

const float ratio = 625.0/1275.0;
const float dist = 0.5/625.0;
uniform float sun_dist;

// --- INPUTS ---
uniform sampler2D region_id_map : filter_nearest;
uniform sampler2D type_map : filter_nearest;
uniform sampler2D state_colors : filter_nearest;

// NOISE TEXTURE (Generated in World.gd)
uniform sampler2D ocean_noise : filter_nearest, repeat_enable;
// ORIGINAL TEXTURE (To show the grid)
uniform sampler2D original_texture : filter_linear_mipmap;
uniform vec2 tex_size;
uniform float lower : hint_range(0.0, 1.0) = 0.5;
uniform float upper : hint_range(0.0, 1.0) = 0.8;
uniform float scanlines : hint_range(0.0, 0.5) = 0.05;
uniform int toggle = 1;
uniform float contrast : hint_range(0.0, 0.5) = 0.05;
uniform float smoothness : hint_range(0.0, 1.0) = 0.05;
uniform float clouds: hint_range(0.0, 1.0) = 0.05;
uniform float edgeness: hint_range(0.0, 5.0) = 0.05;



// --- COLORS ---
// Shallow/deep don't exist just named that way
uniform vec4 water_color_deep : source_color = vec4(0.10, 0.25, 0.45, 1.0);
uniform vec4 water_color_shallow : source_color = vec4(0.25, 0.45, 0.65, 1.0);
uniform vec4 sun_glint_color : source_color = vec4(0.9, 0.95, 1.0, 0.3);
uniform vec4 country_border_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);

// --- WATER SETTINGS ---
uniform float sea_speed : hint_range(0.0, 0.2) = 0.02;
uniform float wave_scale : hint_range(0.1, 5.0) = 1.5;
uniform float distortion_strength : hint_range(0.0, 1.0) = 0.15;
uniform float grid_opacity : hint_range(0.0, 1.0) = 0.3;
uniform float sea_pixel_size = 2.0;       // 1 = native pixels, 2–4 = chunkier
uniform float sea_height_steps = 10.0;    // number of discrete wave levels
uniform vec2 ocean_offset;
// --- BORDER SETTINGS (From Old Version) ---
uniform float internal_border_darkness : hint_range(0.0, 1.0) = 0.82;

// 8 constant directions for scanning neighbors
const vec2 DIRS[8] = vec2[8](
    vec2(0.0, -1.0), vec2(0.0,  1.0),
    vec2(-1.0, 0.0), vec2(1.0,  0.0),
    vec2(-1.0, -1.0), vec2(1.0,  -1.0),
    vec2(-1.0, 1.0), vec2(1.0,  1.0)
);

// --- ID HELPERS ---
int get_id(vec2 uv) {
    vec4 c = texture(region_id_map, clamp(uv, vec2(0.0), vec2(1.0)));
    return int(c.b * 255.0) + int(c.g * 255.0 * 256.0) + int(c.r * 255.0 * 256.0 * 256.0);
}

vec4 get_country_color(int id, float ev) {
    if (id <= 1) return vec4(0.0);
    return texture(state_colors, vec2((float(id) + 0.5) / float(textureSize(state_colors, 0).x), 0.25 + 0.5 * ev)); // This will return alpha 0 for sea provinces now
}
// --- BORDER SCANNING LOGIC ---
bool detect_border_at_distance(vec2 origin_uv, float dist_px, out vec4 out_color, out bool is_black) {
    vec2 pixel_size = 1.0 / tex_size;
    out_color = mix(water_color_shallow.rgba, vec4(.6, .6, .9, 1.), .75+.25*sin(PI*TIME));
    is_black = false;

    bool found_color = false;
    vec4 curr_country = vec4(0.0);
    
    // Check if the ORIGIN pixel itself is touching sea
    // We use the type_map to determine "Sea-ness" now
    float origin_type = texture(type_map, origin_uv).r;

    for (int i = 0; i < 8; i++) {
        vec2 sample_uv = clamp(origin_uv + DIRS[i] * pixel_size * dist_px, vec2(0.0), vec2(1.0));
        float sample_type = texture(type_map, sample_uv).r;
        int nid = get_id(sample_uv);

        // 1. If any neighbor is SEA, this is a COASTLINE
        if (sample_type < 0.5) { 
            return true; 
        }
        // 2. If neighbor is LAND
        if (nid > 1) {
            vec4 adj_country = get_country_color(nid, 0.0);
            if (!found_color) {
                curr_country = adj_country;
                found_color = true;
            } else {
                // If touching a DIFFERENT country, it's an international border
                if (curr_country.rgb != adj_country.rgb) {
                    is_black = true;
                    return true;
                }
            }
        }
    }

    if (found_color) {
        out_color = mix(curr_country, vec4(0.0, 0.0, 0.0, 1.0), internal_border_darkness);
        return true;
    }
    return false;
}

void fragment() {
		//weird magic offset thing trust me i checked
		float d = (PI*82.*ocean_offset.x) + (PI*43.43) +.6;
		float t = 0.55907372766767*cos(d/182.725);
		//float t = 1.;
		
		vec3 sphere_point = vec3(
			cos(UV.x*2.*PI)
			*sin(UV.y*PI)
			,
			sin(UV.x*2.*PI)
			*sin(UV.y*PI)
			,
			//mix(-1., 1, UV.y)
			cos(UV.y*PI)
		);
		vec3 sun_dir = vec3(
			sin(d)*cos(t),
			cos(d)*cos(t),
			sin(t)
		);
		
		float p_type = texture(type_map, UV).r;
		int id = get_id(UV);
		float black = UV.x * tex_size.x + UV.y * tex_size.y;
		

		// 1. If type_map says Sea (0.0), render the animated water
		if (p_type < 0.5) {
		    vec2 grid_uv = UV;
			//vec2 grid_uv = floor(UV * tex_size / sea_pixel_size) * sea_pixel_size / tex_size;
		    float h = asin(sin(2.0*texture((ocean_noise), grid_uv + ocean_offset).r+5.0*ocean_offset.x))/3.0;
		    h = floor(h * sea_height_steps) / sea_height_steps;
		    vec3 water = mix(
				water_color_deep.rgb
				+clamp(
					.5 -.5*pow(distance(sphere_point, sun_dir), .2),
					0.,
					1.
				)
				,
				water_color_shallow.rgb,
				h);
		    COLOR.xyz = water;
		} 
		// 2. If it's Land (type_map 1.0) and a real province
		else if (id > 1) {
		    COLOR = vec4(get_country_color(id, mod(floor(black), 2.0)).rgb, 1.0);
		} 
		// 3. If it's Land (type_map 1.0) and ID 1 (Border)
		else {
		    vec4 c_detect = vec4(0.0);
		    bool must_be_black = false;
		    bool decided = detect_border_at_distance(UV, 1.0, c_detect, must_be_black);
		    
		    if (!decided) decided = detect_border_at_distance(UV, 2.0, c_detect, must_be_black);

		    if (decided) {
		        COLOR = must_be_black ? country_border_color : c_detect;
		    } else {
		        COLOR = country_border_color;
		    }
		}
    	//COLOR = final_color;
	if (toggle == 1) {
		float vignette = 16.0*(SCREEN_UV.x-(SCREEN_UV.x*SCREEN_UV.x)) * (SCREEN_UV.y-(SCREEN_UV.y*SCREEN_UV.y));
		COLOR.rgb += (1.0+sin(800.0*SCREEN_UV.y+16.0*TIME))/2.0*scanlines;
		COLOR.rgb *= vec3(mix(lower, 1.+upper, vignette));
		

		float daynight = clamp(
			dot(
				sphere_point,
				sun_dir
			)
			,0
			,1
		);
		COLOR.xyz += vec3(
			contrast/smoothness*
			clamp(
				daynight
				,-smoothness
				,smoothness
			)
		);
		
		// fog clouds thing
		//COLOR.gb = vec2(0.);
		float clouds_tex = mix(
			0.,
			1.,
			(clouds)
			*(1.5-asin(sin(
				PI
				*(texture(ocean_noise, UV - ocean_offset).r
				+ 10.*ocean_offset.x)
			)))
			*(.5-.5*daynight) // nights hv more clouds
			*(0.8-round(p_type)) // makes the clouds more visible in water (kinda unrealistic but eh)
			*(1.-.4*sin(PI*UV.y)) // i think its more cloudy at poles???
			*(1.-vignette*edgeness)
		);
		
		COLOR.rgb += vec3(clouds_tex);
		//COLOR.rgb += vec3(round(dot(sun_dir, sphere_point)-.4999));
	}
}