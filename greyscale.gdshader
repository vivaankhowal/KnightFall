shader_type canvas_item;

// 0.0 = normal color, 1.0 = full greyscale
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

// Use the screen texture
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	// sample the screen color at this pixel
	vec4 color = texture(screen_tex, SCREEN_UV);
	
	// convert to greyscale using luminance coefficients
	float grey = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	
	// blend between original and greyscale based on intensity
	vec3 final_rgb = mix(color.rgb, vec3(grey), intensity);
	
	COLOR = vec4(final_rgb, color.a);
}


