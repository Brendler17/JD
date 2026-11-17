extends PanelContainer
## Monitor lateral esquerdo do posto ("SUPORTE DE VIDA"): oxigênio em número
## grande + barra, integridade do casco em blocos e tabela de custos de O₂.
## Saiu do monitor superior (que ficou só com o registro de navegação) porque,
## lá, O₂ e casco ficavam pequenos demais para ler do assento.
## Barra e blocos são desenhados com _draw (sem glifos): não dependem de fonte
## de fallback e continuam legíveis mesmo com a tela tremendo nas falhas.
## "Dumb UI": só exibe o que o EventBus informa; valores iniciais vêm do GameState.

## Abaixo desta fração do máximo, O₂ muda para a cor de alerta.
const LOW_OXYGEN_RATIO := 0.25
const NORMAL_COLOR := Color(1.0, 0.72, 0.38)
const ALERT_COLOR := Color(1.0, 0.2, 0.16)
const DIM_COLOR := Color(0.35, 0.16, 0.08)
## Espaço entre os blocos do casco, em pixels.
const HULL_GAP := 18.0

@onready var _oxygen_value: Label = %OxygenValue
@onready var _oxygen_bar: Control = %OxygenBar
@onready var _hull_value: Label = %HullValue
@onready var _hull_blocks: Control = %HullBlocks
@onready var _costs_label: Label = %CostsLabel

var _oxygen_ratio := 1.0
var _oxygen_low := false
var _hull := GameState.MAX_HULL
var _hull_max := GameState.MAX_HULL


func _ready() -> void:
	_costs_label.text = "MOVER %d   ·   GIRAR %d   ·   SONAR %d   ·   COLISÃO %d" % [
		GameState.OXYGEN_COST_MOVE, GameState.OXYGEN_COST_ROTATE,
		GameState.OXYGEN_COST_SONAR, GameState.OXYGEN_COST_COLLISION,
	]
	_oxygen_bar.draw.connect(_draw_oxygen_bar)
	_hull_blocks.draw.connect(_draw_hull_blocks)
	EventBus.oxygen_changed.connect(_on_oxygen_changed)
	EventBus.hull_changed.connect(_on_hull_changed)
	_on_oxygen_changed(GameState.oxygen, GameState.MAX_OXYGEN)
	_on_hull_changed(GameState.hull, GameState.MAX_HULL)


func _on_oxygen_changed(current: float, maximum: float) -> void:
	_oxygen_ratio = clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	_oxygen_low = current <= maximum * LOW_OXYGEN_RATIO
	_oxygen_value.text = "%d / %d" % [ceili(current), int(maximum)]
	_oxygen_value.add_theme_color_override(&"font_color", ALERT_COLOR if _oxygen_low else NORMAL_COLOR)
	_oxygen_bar.queue_redraw()


func _on_hull_changed(current: int, maximum: int) -> void:
	_hull = current
	_hull_max = maximum
	_hull_value.text = "%d / %d" % [current, maximum]
	_hull_value.add_theme_color_override(&"font_color", ALERT_COLOR if current <= 1 else NORMAL_COLOR)
	_hull_blocks.queue_redraw()


## Barra horizontal com marcas a cada 10%; vazia fica só o contorno escuro.
func _draw_oxygen_bar() -> void:
	var size := _oxygen_bar.size
	var color := ALERT_COLOR if _oxygen_low else NORMAL_COLOR
	_oxygen_bar.draw_rect(Rect2(Vector2.ZERO, size), DIM_COLOR, false, 3.0)
	_oxygen_bar.draw_rect(Rect2(Vector2(6, 6), Vector2((size.x - 12.0) * _oxygen_ratio, size.y - 12.0)), color)
	for i in range(1, 10):
		var x := size.x * i / 10.0
		_oxygen_bar.draw_line(Vector2(x, size.y - 10.0), Vector2(x, size.y), DIM_COLOR, 2.0)


## Um bloco por golpe que o casco ainda aguenta: cheio = intacto, contorno = perdido.
func _draw_hull_blocks() -> void:
	var size := _hull_blocks.size
	var width := (size.x - HULL_GAP * (_hull_max - 1)) / float(_hull_max)
	var color := ALERT_COLOR if _hull <= 1 else NORMAL_COLOR
	for i in _hull_max:
		var rect := Rect2(Vector2(i * (width + HULL_GAP), 0.0), Vector2(width, size.y))
		if i < _hull:
			_hull_blocks.draw_rect(rect, color)
		else:
			_hull_blocks.draw_rect(rect, DIM_COLOR, false, 4.0)
			_hull_blocks.draw_line(rect.position, rect.end, DIM_COLOR, 3.0)
