extends Node
## Autoload com o estado da partida (State Pattern, via enum) e o oxigênio.
## Não conhece Capsule, UI nem labirinto: reage apenas a fatos do EventBus
## e publica de volta oxygen_changed / game_over.
## UIs podem LER `state` e `oxygen` diretamente (ex.: valor inicial ao entrar na cena),
## mas mudanças de estado só acontecem por sinais.

enum State { PLAYING, WON, LOST }
## Por que a partida terminou (lido pela tela de fim).
enum EndReason { NONE, REACHED_EXIT, OUT_OF_OXYGEN, CAUGHT }

const MAX_OXYGEN := 240.0
const OXYGEN_COST_MOVE := 1.0
const OXYGEN_COST_ROTATE := 1.0
const OXYGEN_COST_SONAR := 4.0
const OXYGEN_COST_COLLISION := 8.0
## Raio (em células, distância em linha reta) em que um pulso de sonar revela a
## criatura, atravessando paredes. Além dele, só o feixe reto das 4 direções a pega.
const SONAR_DETECT_RADIUS := 4.5
## Golpes da criatura que o casco aguenta; o último dispara a derrota por contato.
const MAX_HULL := 3

var state: State = State.PLAYING
var oxygen: float = MAX_OXYGEN
var hull: int = MAX_HULL
var end_reason: EndReason = EndReason.NONE


func _ready() -> void:
	EventBus.capsule_moved.connect(_on_capsule_moved)
	EventBus.capsule_rotated.connect(_on_capsule_rotated)
	EventBus.capsule_collided.connect(_on_capsule_collided)
	EventBus.sonar_pinged.connect(_on_sonar_pinged)
	EventBus.capsule_reached_exit.connect(_on_capsule_reached_exit)
	EventBus.enemy_attacked.connect(_on_enemy_attacked)
	EventBus.capsule_caught.connect(_on_capsule_caught)
	EventBus.session_ended.connect(_on_session_ended)
	_start_run()


func _start_run() -> void:
	state = State.PLAYING
	oxygen = MAX_OXYGEN
	hull = MAX_HULL
	end_reason = EndReason.NONE
	EventBus.oxygen_changed.emit(oxygen, MAX_OXYGEN)
	EventBus.hull_changed.emit(hull, MAX_HULL)


func _on_capsule_moved(_new_position: Vector2i, _direction: Vector2i) -> void:
	_consume_oxygen(OXYGEN_COST_MOVE)


func _on_capsule_rotated(_new_direction: Vector2i) -> void:
	_consume_oxygen(OXYGEN_COST_ROTATE)


func _on_capsule_collided(_blocked_cell: Vector2i, _direction: Vector2i) -> void:
	_consume_oxygen(OXYGEN_COST_COLLISION)


func _on_sonar_pinged(_origin: Vector2i, _hits: Array[Vector2i]) -> void:
	_consume_oxygen(OXYGEN_COST_SONAR)


## Chegar à saída vence mesmo que o passo use o último oxigênio:
## a Capsule emite este sinal antes de capsule_moved, então o custo do passo
## já encontra a partida encerrada e é ignorado.
func _on_capsule_reached_exit(_exit_cell: Vector2i) -> void:
	if state == State.PLAYING:
		_end_run(State.WON, EndReason.REACHED_EXIT)


## Cada golpe tira 1 ponto do casco. Sem pontos, o casco cede: capsule_caught.
func _on_enemy_attacked(cell: Vector2i) -> void:
	if state != State.PLAYING:
		return
	hull = maxi(hull - 1, 0)
	EventBus.hull_changed.emit(hull, MAX_HULL)
	if hull > 0:
		EventBus.capsule_attacked.emit(hull)
	else:
		EventBus.capsule_caught.emit(cell)


func _on_capsule_caught(_cell: Vector2i) -> void:
	if state == State.PLAYING:
		_end_run(State.LOST, EndReason.CAUGHT)


func _consume_oxygen(amount: float) -> void:
	if state != State.PLAYING:
		return
	oxygen = maxf(oxygen - amount, 0.0)
	EventBus.oxygen_changed.emit(oxygen, MAX_OXYGEN)
	if oxygen <= 0.0:
		_end_run(State.LOST, EndReason.OUT_OF_OXYGEN)


func _end_run(final_state: State, reason: EndReason) -> void:
	state = final_state
	end_reason = reason
	EventBus.game_over.emit(final_state == State.WON)


## A cena da partida vai ser trocada (reinício, novo jogo ou menu), com a tela
## já preta: zera o estado para a próxima. Quem troca a cena é o SceneFlow.
## Não zera no pedido (request_restart etc.) para quem registra a partida
## (telemetria) ainda ler os valores finais.
func _on_session_ended() -> void:
	_start_run()
