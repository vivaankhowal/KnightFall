shader_type canvas_item;

uniform bool flash = false;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    if (flash) {
        // Tint red but keep original alpha
        COLOR = vec4(1.0, 0.2, 0.2, tex.a);
    } else {
        COLOR = tex;
    }
}
