shader_type canvas_item;

uniform float outline_size : hint_range(0.0, 10.0) = 2.0;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    float edge_alpha = 0.0;

    // Only check neighbors if this pixel is transparent
    if (tex_color.a == 0.0) {
        for (float x = -outline_size; x <= outline_size; x++) {
            for (float y = -outline_size; y <= outline_size; y++) {
                vec2 offset = vec2(x, y) * TEXTURE_PIXEL_SIZE;
                edge_alpha = max(edge_alpha, texture(TEXTURE, UV + offset).a);
            }
        }
    }

    // If we found opaque neighbors, draw outline; otherwise show sprite
    if (edge_alpha > 0.0 && tex_color.a == 0.0) {
        COLOR = vec4(outline_color.rgb, 1.0);
    } else {
        COLOR = tex_color;
    }
}
