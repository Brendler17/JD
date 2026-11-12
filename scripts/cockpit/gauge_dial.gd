extends Control
## Mostrador analógico redondo, desenhado em _draw() para cobrir os relógios
## brancos do painel amarelo. Um ponteiro varre um arco de 270º.
##   OXYGEN       → nível de O₂ (oxygen_changed); faixa vermelha nos 25% finais.
##   INTERFERENCE → proximidade do inimigo (enemy_proximity_changed); o ponteiro
##                  treme mais quanto mais perto, como um sensor sob interferência.
## "Dumb UI": só reflete sinais do EventBus.

enum Kind { OXYGEN, INTERFERENCE }

const LOW_OXYGEN_RATIO := 0.25
## A partir desta distância (em passos) a interferência é zero.
const INTERFERENCE_RANGE := 8.0
const ARC_START := deg_to_rad(135.0)
const ARC_SPAN := deg_to_rad(270.0)
const FACE_COLOR := Color(0.9, 0.9, 0.86)
const INK_COLOR := Color(0.12, 0.12, 0.13)
const DANGER_COLOR := Color(0.78, 0.12, 0.08)
const NEEDLE_COLOR := Color(0.75, 0.1, 0.06)

@export var kind := Kind.OXYGEN
@export var caption := "O₂"

## Valor alvo (0..1) e valor exibido, suavizado para o ponteiro "andar".
var _target := 1.0
var _shown := 1.0
var _time := 0.0


func _ready() -> void:
	if kind == Kind.OXYGEN:
		EventBus.oxygen_changed.connect(_on_oxygen_changed)
		_on_oxygen_changed(GameState.oxygen, GameState.MAX_OXYGEN)
		_shown = _target
	else:
		_target = 0.0
		_shown = 0.0
		EventBus.enemy_proximity_changed.connect(_on_enemy_proximity_changed)


func _process(delta: float) -> void:
	_time += delta
	_shown = lerpf(_shown, _target, 1.0 - exp(-delta * 5.0))
	queue_redraw()


func _on_oxygen_changed(current: float, maximum: float) -> void:
	_target = clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0


func _on_enemy_proximity_changed(steps: int) -> void:
	_target = 0.0 if steps < 0 else clampf(1.0 - float(steps - 1) / INTERFERENCE_RANGE, 0.0, 1.0)


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 2.0
	draw_circle(center, radius, FACE_COLOR)
	draw_arc(center, radius - 1.0, 0.0, TAU, 64, INK_COLOR, 3.0)

	# Faixa de perigo: fim da escala para O₂ (pouco ar), início alto para interferência.
	var danger_from := 0.0 if kind == Kind.OXYGEN else 0.75
	var danger_to := LOW_OXYGEN_RATIO if kind == Kind.OXYGEN else 1.0
	draw_arc(center, radius * 0.78, _angle(danger_from), _angle(danger_to), 24, DANGER_COLOR, radius * 0.1)

	for i in 11:
		var t := i / 10.0
		var dir := Vector2.from_angle(_angle(t))
		var inner := radius * (0.66 if i % 5 == 0 else 0.72)
		draw_line(center + dir * inner, center + dir * radius * 0.84, INK_COLOR, 3.0 if i % 5 == 0 else 1.5)

	var font := get_theme_default_font()
	var font_size := int(radius * 0.22)
	draw_string(font, center + Vector2(-radius, radius * 0.45), caption, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, INK_COLOR)

	var value := _shown
	if kind == Kind.INTERFERENCE and _shown > 0.02:
		value += sin(_time * 37.0) * 0.04 * _shown + sin(_time * 13.0) * 0.02 * _shown
	var needle_dir := Vector2.from_angle(_angle(clampf(value, 0.0, 1.02)))
	draw_line(center - needle_dir * radius * 0.12, center + needle_dir * radius * 0.8, NEEDLE_COLOR, 4.0)
	draw_circle(center, radius * 0.08, INK_COLOR)


func _angle(t: float) -> float:
	return ARC_START + ARC_SPAN * t
