shader_type spatial;
// Outline de imagens (billboard preso ao eixo Y). Desenhado num quad um pouco maior que
// a imagem: acende os pixels transparentes que têm algum pixel visível por perto, então
// a borda acompanha o formato da imagem e não só o retângulo dela.
render_mode unshaded, cull_disabled;

uniform sampler2D tex : source_color, filter_linear;
uniform vec4 outline_color : source_color = vec4(1.0, 0.95, 0.55, 1.0);
// Tamanho do quad dividido pelo tamanho da imagem (o quad tem margem para o outline)
uniform vec2 uv_scale = vec2(1.0);
// Espessura do outline, em UV da imagem
uniform vec2 width_uv = vec2(0.02);

void vertex() {
	// Billboard preso ao eixo Y, igual ao Sprite3D com BILLBOARD_FIXED_Y
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 to_camera = INV_VIEW_MATRIX[3].xyz - center;
	to_camera.y = 0.0;
	if (length(to_camera) < 0.0001) {
		to_camera = vec3(0.0, 0.0, 1.0);
	}
	to_camera = normalize(to_camera);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), to_camera));
	float scale_x = length(MODEL_MATRIX[0].xyz);
	float scale_y = length(MODEL_MATRIX[1].xyz);
	vec3 world = center + right * VERTEX.x * scale_x + vec3(0.0, 1.0, 0.0) * VERTEX.y * scale_y;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

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
