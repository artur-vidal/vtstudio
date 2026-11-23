shader_type spatial;
// Outline de imagens com a transformação do objeto. Desenhado num quad um pouco maior que
// a imagem: acende os pixels transparentes que têm algum pixel visível por perto, então
// a borda acompanha o formato da imagem e não só o retângulo dela.
render_mode unshaded, cull_disabled;

uniform sampler2D tex : source_color, filter_linear;
uniform vec4 outline_color : source_color = vec4(1.0, 0.8, 0.1, 1.0);
// Tamanho do quad dividido pelo tamanho da imagem (o quad tem margem para o outline)
uniform vec2 uv_scale = vec2(1.0);
// Espessura do outline, em UV da imagem
uniform vec2 width_uv = vec2(0.02);

float alpha_at(vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(tex, uv).a;
}

void fragment() {
	vec2 uv = (UV - 0.5) * uv_scale + 0.5;
	float center_alpha = alpha_at(uv);
	float nearby = 0.0;
	for (int i = 0; i < 16; i++) {
		float angle = float(i) * 0.39269908;
		vec2 direction = vec2(cos(angle), sin(angle));
		nearby = max(nearby, alpha_at(uv + direction * width_uv));
		nearby = max(nearby, alpha_at(uv + direction * width_uv * 0.5));
	}
	ALBEDO = outline_color.rgb;
	ALPHA = clamp(nearby * 2.0 - 0.2, 0.0, 1.0) * (1.0 - center_alpha) * outline_color.a;
}
