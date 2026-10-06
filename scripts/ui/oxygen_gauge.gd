extends VBoxContainer
## Indicador de oxigênio (barra + texto). "Dumb UI": só exibe o que o
## EventBus informa; o valor inicial é lido do GameState ao entrar na cena,
## pois o primeiro oxygen_changed pode ter sido emitido antes da UI existir.

## Abaixo desta fração do máximo, o indicador muda para a cor de alerta.
const LOW_OXYGEN_RATIO := 0.25
const NORMAL_COLOR := Color(0.8, 0.9, 1.0)
const LOW_COLOR := Color(1.0, 0.35, 0.3)

@onready var _label: Label = %OxygenLabel
@onready var _bar: ProgressBar = %OxygenBar


func _ready() -> void:
	EventBus.oxygen_changed.connect(_on_oxygen_changed)
	_on_oxygen_changed(GameState.oxygen, GameState.MAX_OXYGEN)


func _on_oxygen_changed(current: float, maximum: float) -> void:
	_bar.max_value = maximum
	_bar.value = current
	_label.text = "O₂  %d / %d" % [ceili(current), int(maximum)]
	modulate = LOW_COLOR if current <= maximum * LOW_OXYGEN_RATIO else NORMAL_COLOR
