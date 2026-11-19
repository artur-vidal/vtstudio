shader_type spatial;
// Marca a silhueta original sem alterar a cor nem a profundidade da cena.
// Todas as máscaras são desenhadas antes dos cascos (render_priority).
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
stencil_mode write, compare_always, 1;

void fragment() {
	ALPHA = 0.0;
}
