shader_type spatial;
// Chão de debug: desenha as bordas das células da grade do labirinto em
// coordenadas de mundo. Os centros das células ficam em múltiplos de
// cell_size (ver Grid.grid_to_world), então as linhas ficam nos meios-termos.
render_mode unshaded;

uniform float cell_size = 4.0;
uniform float line_width = 0.06;
uniform vec4 base_color : source_color = vec4(0.08, 0.1, 0.13, 1.0);
uniform vec4 line_color : source_color = vec4(0.25, 0.45, 0.55, 1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 to_border = abs(fract(world_pos.xz / cell_size) - 0.5) * cell_size;
	float is_line = step(min(to_border.x, to_border.y), line_width);
	ALBEDO = mix(base_color.rgb, line_color.rgb, is_line);
}
