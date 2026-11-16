shader_type spatial;
// Outline de modelos 3D por "casco invertido": desenha as faces de trás da malha,
// levemente expandidas ao longo das normais, por cima do material original
// (GeometryInstance3D.material_overlay). Só aparece fora da silhueta do modelo.
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(1.0, 0.95, 0.55, 1.0);
// Espessura em unidades do MUNDO. A escala do objeto é compensada aqui.
uniform float width = 0.04;

void vertex() {
	float object_scale = length(MODEL_MATRIX[0].xyz);
	VERTEX += NORMAL * (width / max(object_scale, 0.0001));
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
