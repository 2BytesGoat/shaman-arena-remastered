shader_type canvas_item;

uniform vec4 from_colors[5] : source_color;
uniform vec4 to_colors[5]   : source_color;
uniform float tolerance = 0.01;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    vec4 result = tex_color;

    for (int i = 0; i < 5; i++) {
        if (distance(tex_color.rgb, from_colors[i].rgb) < tolerance) {
            result.rgb = to_colors[i].rgb;
            break;
        }
    }

    COLOR = result;
}
