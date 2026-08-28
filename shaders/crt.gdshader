shader_type canvas_item;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float intensity : hint_range(0.0, 1.0) = 0.22;
uniform float scanline_density : hint_range(10.0, 200.0) = 90.0;
uniform float scanline_speed : hint_range(0.0, 2.0) = 0.35;
uniform float noise_amount : hint_range(0.0, 1.0) = 0.06;

void fragment() {
	vec2 uv = SCREEN_UV;
	float scan = sin((uv.y * scanline_density) + TIME * scanline_speed);
	float scanlines = mix(1.0, 0.86, step(0.0, scan) * intensity);
	float grain = fract(sin(dot(uv * 640.0, vec2(12.9898, 78.233)) + TIME) * 43758.5453);
	vec3 col = texture(SCREEN_TEXTURE, uv).rgb;
	col *= scanlines;
	col += (grain - 0.5) * noise_amount;
	col *= 1.0 + 0.06 * sin(uv.y * 160.0 + TIME * 0.8);
	COLOR = vec4(col, 1.0);
}