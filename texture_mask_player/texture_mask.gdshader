// Adapted from Scene Manager's Dissolve2d.gdshader.
// Copyright © 2021 GlassBrick. See LICENSE.
shader_type canvas_item;

uniform sampler2D mask_texture : filter_linear, repeat_disable;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform bool inverted = false;
uniform bool has_mask = false;
uniform bool use_content = false;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	float coverage = progress;
	if (has_mask && progress > 0.0 && progress < 1.0) {
		float threshold = texture(mask_texture, UV).r;
		if (inverted) { threshold = 1.0 - threshold; }
		coverage = step(threshold, progress);
	}
	if (use_content) {
		COLOR = vec4(base.rgb, base.a * coverage);
	} else {
		COLOR = vec4(tint.rgb * base.rgb, tint.a * base.a * coverage);
	}
}
