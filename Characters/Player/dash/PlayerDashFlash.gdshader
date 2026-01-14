shader_type canvas_item;

uniform bool flash_enabled = false;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // rgb = flash color, a = strength
uniform float alpha_multiplier = 1.0; // keep default 1

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Preserve sprite transparency
	float a = tex.a * alpha_multiplier;

	if (flash_enabled) {
		// Solid silhouette using the sprite alpha as the mask
		COLOR = vec4(flash_color.rgb, a * flash_color.a);
	} else {
		COLOR = vec4(tex.rgb, a);
	}
}
