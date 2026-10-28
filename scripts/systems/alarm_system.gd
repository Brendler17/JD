extends Node
## Decide quando há perigo e publica alarm_started/alarm_stopped(reason).
## Não toca som nem acende luz: a apresentação (luz vermelha da cabine,
## alerta no painel) só escuta esses sinais.
## Causas: &"enemy" (inimigo a ENEMY_ALARM_STEPS passos ou menos) e
## &"low_oxygen" (oxigênio em LOW_OXYGEN_RATIO do máximo ou menos).

const ENEMY_ALARM_STEPS := 4
const LOW_OXYGEN_RATIO := 0.25

var _active := {}


func _ready() -> void:
	EventBus.enemy_proximity_changed.connect(_on_enemy_proximity_changed)
	EventBus.oxygen_changed.connect(_on_oxygen_changed)
	EventBus.game_over.connect(_on_game_over)


func _on_enemy_proximity_changed(steps: int) -> void:
	_set_alarm(&"enemy", steps >= 0 and steps <= ENEMY_ALARM_STEPS)


func _on_oxygen_changed(current: float, maximum: float) -> void:
	_set_alarm(&"low_oxygen", current <= maximum * LOW_OXYGEN_RATIO)


func _on_game_over(_won: bool) -> void:
	for reason: StringName in _active.keys():
		_set_alarm(reason, false)


func _set_alarm(reason: StringName, on: bool) -> void:
	if on == _active.has(reason):
		return
	if on:
		_active[reason] = true
		EventBus.alarm_started.emit(reason)
	else:
		_active.erase(reason)
		EventBus.alarm_stopped.emit(reason)
