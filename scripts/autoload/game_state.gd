extends Node
## Autoload com o estado da partida (State Pattern, via enum) e o oxigênio.
## Não conhece Capsule, UI nem labirinto: reage apenas a fatos do EventBus
## e publica de volta oxygen_changed / game_over.
## UIs podem LER `state` e `oxygen` diretamente (ex.: valor inicial ao entrar na cena),
## mas mudanças de estado só acontecem por sinais.

enum State { PLAYING, WON, LOST }

const MAX_OXYGEN := 150.0
const OXYGEN_COST_MOVE := 1.0
const OXYGEN_COST_COLLISION := 5.0

var state: State = State.PLAYING
var oxygen: float = MAX_OXYGEN


func _ready() -> void:
	EventBus.capsule_moved.connect(_on_capsule_moved)
	EventBus.capsule_collided.connect(_on_capsule_collided)
	EventBus.capsule_reached_exit.connect(_on_capsule_reached_exit)
	EventBus.request_restart.connect(_on_request_restart)
	_start_run()


func _start_run() -> void:
	state = State.PLAYING
	oxygen = MAX_OXYGEN
	EventBus.oxygen_changed.emit(oxygen, MAX_OXYGEN)


func _on_capsule_moved(_new_position: Vector2i, _direction: Vector2i) -> void:
	_consume_oxygen(OXYGEN_COST_MOVE)


func _on_capsule_collided(_blocked_cell: Vector2i, _direction: Vector2i) -> void:
	_consume_oxygen(OXYGEN_COST_COLLISION)


## Chegar à saída vence mesmo que o passo use o último oxigênio:
## a Capsule emite este sinal antes de capsule_moved, então o custo do passo
## já encontra a partida encerrada e é ignorado.
func _on_capsule_reached_exit(_exit_cell: Vector2i) -> void:
	if state == State.PLAYING:
		_end_run(State.WON)


func _consume_oxygen(amount: float) -> void:
	if state != State.PLAYING:
		return
	oxygen = maxf(oxygen - amount, 0.0)
	EventBus.oxygen_changed.emit(oxygen, MAX_OXYGEN)
	if oxygen <= 0.0:
		_end_run(State.LOST)


func _end_run(final_state: State) -> void:
	state = final_state
	EventBus.game_over.emit(final_state == State.WON)


## Reinicia a partida: zera o estado e recarrega a cena atual
## (Capsule, labirinto e UI voltam ao estado inicial).
func _on_request_restart() -> void:
	_start_run()
	get_tree().reload_current_scene()
