shader_type canvas_item;

uniform bool silhouette = false;
uniform bool damage_flash = false;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	if (tex.a <= 0.01) {
		COLOR = vec4(0.0);
	}
	else if (silhouette) {
		COLOR = vec4(1.0, 1.0, 1.0, tex.a);
	}
	else if (damage_flash) {
		COLOR = vec4(1.0, 0.0, 0.0, tex.a);
	}
	else {
		COLOR = tex;
	}
}
