extends Control
## Impressão sobre o mostrador original de um relógio do painel: só a faixa
## vermelha de perigo e a legenda. O fundo, a escala e o ponteiro são os da malha
## (o ponteiro gira via GaugeNeedle), então o relógio mantém o visual realista.
## Exibida por uma PanelScreen transparente e sombreada, do tamanho do mostrador
## (o desenho ocupa o círculo inscrito no viewport).
## A faixa fica em 0,75–1,0 do arco nos dois relógios (perigo sempre à direita),
## com o mesmo arco do GaugeNeedle: 270º em sentido horário, início embaixo à esquerda.
## Desenho estático: não reage a sinais.

const DANGER_FROM := 0.75
const ARC_START := deg_to_rad(135.0)
const ARC_SPAN := deg_to_rad(270.0)
## Vermelho de tinta, levemente translúcido para a textura do mostrador aparecer.
const DANGER_COLOR := Color(0.62, 0.07, 0.05, 0.8)
const INK_COLOR := Color(0.12, 0.11, 0.1, 0.85)

@export var caption := "O₂"


func _notification(what: int) -> void:
	# Desenho estático: refaz quando o viewport define o tamanho do Control.
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5
	# Anel interno, logo abaixo dos números da escala original.
	draw_arc(center, radius * 0.6, _angle(DANGER_FROM), _angle(1.0), 32, DANGER_COLOR, radius * 0.07, true)
	for t in [DANGER_FROM, 1.0]:
		var dir := Vector2.from_angle(_angle(t))
		draw_line(center + dir * radius * 0.54, center + dir * radius * 0.66, DANGER_COLOR, radius * 0.02, true)

	var font := get_theme_default_font()
	var font_size := int(radius * 0.16)
	draw_string(font, center + Vector2(-radius, radius * 0.42), caption, HORIZONTAL_ALIGNMENT_CENTER,
			radius * 2.0, font_size, INK_COLOR)


func _angle(t: float) -> float:
	return ARC_START + ARC_SPAN * t
