shader_type canvas_item;
// Blotchy pixel-art Mars dust over a sprite. Mostly lands on the bluish solar cells,
// a little on everything else. `dust` 0..1 fades it in/out.

uniform float dust : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dust_color : source_color = vec4(0.79, 0.52, 0.35, 1.0);
uniform sampler2D noise_tex : filter_nearest, repeat_enable;
uniform vec2 pixels = vec2(48.0, 48.0); // texture size, so blotches snap to art pixels

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 puv = floor(UV * pixels) / pixels;
	float n = texture(noise_tex, puv).r;
	float panel = smoothstep(0.05, 0.25, c.b - c.r); // 1 on blue cells, 0 on frame/legs
	float coverage = clamp(panel + 0.2, 0.0, 1.0);
	// more dust = blotches spread wider, not just stronger
	float blotch = smoothstep(0.55 - dust * 0.45, 0.75 - dust * 0.35, n);
	float d = dust * coverage * blotch;
	COLOR = vec4(mix(c.rgb, dust_color.rgb * (0.8 + 0.4 * n), d), c.a);
}
