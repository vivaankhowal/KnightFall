shader_type canvas_item;

uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // If transparent, keep as-is
    float alpha = tex.a;

    // Mix RGB with white for silhouette flash
    vec3 color_rgb = mix(tex.rgb, vec3(1.0), flash_strength);

    COLOR = vec4(color_rgb, alpha);
}
