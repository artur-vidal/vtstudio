shader_type spatial;
// Expande a malha em pixels. A máscara elimina TODOS os pixels internos,
// inclusive em malhas abertas/dupla face onde cull_front não basta.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
stencil_mode read, compare_not_equal, 1;

uniform vec4 outline_color : source_color = vec4(1.0, 0.95, 0.55, 1.0);
uniform float width_pixels = 2.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal = MODELVIEW_NORMAL_MATRIX * NORMAL;
	vec2 direction = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy * VIEWPORT_SIZE;
	float direction_length = length(direction);
	if (direction_length > 0.0001) {
		clip.xy += (direction / direction_length) * (2.0 * width_pixels / VIEWPORT_SIZE) * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	// A leitura do stencil precisa da passagem transparente do Godot.
	ALPHA = outline_color.a;
}
