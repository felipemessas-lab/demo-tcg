shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform float thickness = 2.0;   // pixels
uniform float intensity = 1.0;   // força do brilho
uniform float alpha = 0.9;       // alpha do brilho

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * thickness;

	float a = 0.0;
	a = max(a, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);

	a = max(a, texture(TEXTURE, UV + vec2(px.x, px.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2(-px.x, px.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2(px.x, -px.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2(-px.x, -px.y)).a);

	// borda = tem alpha nos vizinhos, mas o pixel atual não
	float edge = clamp(a - base.a, 0.0, 1.0);

	// ✅ agora o glow inteiro (RGB e A) depende do edge
	vec4 glow = glow_color * edge;
	glow.a *= alpha;

	// adiciona só nas bordas
	COLOR = base + glow * intensity;
}
