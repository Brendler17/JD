shader_type canvas_item;
// Visão se apagando (cena de fim por falta de oxigênio): escurece a partir das
// bordas, tira a cor e "pulsa" como batimento. Usado por EndingSequence num
// ColorRect de tela cheia, abaixo da UI (legendas continuam legíveis).
//   radius       raio da área visível (1,5 = tela toda; 0 = tudo preto)
//   softness     largura da borda do escurecimento
//   desaturation 0 = cor normal, 1 = cinza
//   pulse        encolhe o raio por um instante (batimento)

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float radius = 1.5;
uniform float softness = 0.55;
uniform float desaturation = 0.0;
uniform float pulse = 0.0;

void fragment() {
	vec3 color = texture(screen_tex, SCREEN_UV).rgb;
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(gray) * 0.85, desaturation);
	// Distância ao centro com correção de proporção (0 no centro, ~1 nas bordas laterais).
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float dist = length((SCREEN_UV - 0.5) * aspect) * 2.0 / aspect.x * 1.15;
	float visible_radius = radius - pulse;
	float dark = smoothstep(visible_radius - softness, visible_radius, dist);
	COLOR = vec4(color * (1.0 - dark), 1.0);
}
