extends OmniLight3D
## Luz vermelha de alerta da cabine (estilo giroflex). Pisca enquanto houver
## qualquer alarme ativo; mais rápido quando a causa é o inimigo.
## Só escuta alarm_started/alarm_stopped do EventBus.

@export var max_energy := 3.0

var _reasons := {}
var _time := 0.0


func _ready() -> void:
	light_energy = 0.0
	EventBus.alarm_started.connect(func(reason: StringName) -> void: _reasons[reason] = true)
	EventBus.alarm_stopped.connect(func(reason: StringName) -> void: _reasons.erase(reason))


func _process(delta: float) -> void:
	if _reasons.is_empty():
		light_energy = move_toward(light_energy, 0.0, delta * max_energy * 2.0)
		return
	_time += delta
	var speed := 7.0 if _reasons.has(&"enemy") else 3.5
	light_energy = max_energy * maxf(sin(_time * speed), 0.0)
