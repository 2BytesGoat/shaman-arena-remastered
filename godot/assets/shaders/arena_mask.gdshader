shader_type canvas_item;

// Cuts the arena's tiles to the play ellipse (D-019 addendum). The floor art keeps everything
// inside it and the liquid keeps everything outside, so the two meet on one smooth curve instead
// of the stair-step of whole tiles the mask paints. The material is attached per tile
// (`TileData.material` in `arena_tileset.tres`); `Arena` keeps the uniforms in step with
// `current_radius`.

// Arena origin and shape in world space (px). `squash_sq` is `Arena.SHAPE_SQUASH_SQ`: the vertical
// offset weighs that many times, which makes the mask twice as wide as it is tall.
uniform vec2 arena_origin = vec2(0.0, 0.0);
uniform float radius : hint_range(0.0, 4096.0) = 800.0;
uniform float edge : hint_range(0.0, 512.0) = 16.0;
uniform float squash_sq : hint_range(1.0, 16.0) = 4.0;

// true: keep the inside (floor art). false: keep the outside (liquid).
uniform bool keep_inside = true;

// Warning-band tint for the `[radius, radius + edge]` ring of the floor art. Transparent by
// default, so the untinted band still draws exactly like the floor.
uniform vec4 band_tint : source_color = vec4(0.0, 0.0, 0.0, 0.0);

// Arena-local pixel position. `MODEL_MATRIX` (local to world) is a vertex-only built-in, and
// world space is the camera-independent space `arena_origin` is given in.
varying vec2 arena_pos;

void vertex() {
	arena_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - arena_origin;
}

void fragment() {
	float d = sqrt(arena_pos.x * arena_pos.x + squash_sq * arena_pos.y * arena_pos.y);
	float outer = radius + edge;
	// Feather by one shape-space pixel, so reading the cut as an oval wins over reading it as
	// pixels (the tiles themselves are cut mid-diamond, that is the point).
	float feather = max(fwidth(d), 0.001);
	float alpha = keep_inside
			? 1.0 - smoothstep(outer - feather, outer, d)
			: smoothstep(outer - feather, outer, d);
	if (alpha <= 0.0) {
		discard;
	}
	COLOR.a *= alpha;
	if (keep_inside && band_tint.a > 0.0 && d > radius) {
		COLOR.rgb = mix(COLOR.rgb, band_tint.rgb, band_tint.a);
	}
}
