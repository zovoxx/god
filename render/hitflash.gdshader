shader_type canvas_item;
// White hit-flash silhouette + attack glow for every sprite.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.35, 0.15, 1.0);

void fragment() {
	vec4 t = texture(TEXTURE, UV) * COLOR;
	vec3 c = mix(t.rgb, glow_color.rgb, glow * 0.45);
	c = mix(c, flash_color.rgb, flash);
	COLOR = vec4(c, t.a);
}
