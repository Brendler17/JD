extends Node3D
## Cápsula do jogador.
## Não lê input diretamente: reage às intenções emitidas pelo EventBus
## (originadas do painel de UI), mantendo a Capsule desacoplada da UI.
## Sempre "anda para frente" na direção atual e gira em incrementos de 90º.
## Cada ação é uma MANOBRA com duração: emite maneuver_started, espera e só então
## executa e emite o fato (moved/collided/rotated/sonar_pinged) + maneuver_finished.
## Assim o impacto numa parede chega no fim do deslocamento (antecipação), o eco
## do sonar "volta" depois do ping, e cliques durante a manobra são ignorados.
## A posição lógica (grid_position) é a fonte de verdade; a posição 3D é
## apenas o reflexo dela no mundo, recalculada via Grid.grid_to_world().

enum Facing { UP, RIGHT, DOWN, LEFT }

const GRID_OFFSET := {
	Facing.UP: Vector2i(0, -1),
	Facing.RIGHT: Vector2i(1, 0),
	Facing.DOWN: Vector2i(0, 1),
	Facing.LEFT: Vector2i(-1, 0),
}

## Rotação em torno do eixo Y. No Godot, +Y gira no sentido anti-horário
## (visto de cima), por isso "direita" é -90º e "esquerda" é +90º.
const FACING_ROTATION_DEGREES := {
	Facing.UP: 0.0,
	Facing.RIGHT: -90.0,
	Facing.DOWN: 180.0,
	Facing.LEFT: 90.0,
}

## Labirinto em que a cápsula está. Se definido, a posição inicial vem de
## maze.start_cell e cada "Andar" consulta a matriz antes de mover.
## Sem labirinto, a cápsula anda livremente (útil para testes isolados).
@export var maze: MazeGrid

## Célula onde a cápsula está - não é a posição no mundo;
## a conversão para metros acontece em Grid.grid_to_world().
@export var grid_position: Vector2i = Vector2i.ZERO

## Duração de cada manobra, em segundos.
@export var move_duration := 1.0
@export var rotate_duration := 0.8
@export var sonar_duration := 0.9

## Representa pra onde a cápsula está apontada.
var facing: Facing = Facing.UP

## Há uma manobra em andamento (novos pedidos são ignorados até terminar).
var maneuvering := false

var _maneuver_timer: Timer
var _maneuver_kind := &""
var _maneuver_action: Callable


func _ready() -> void:
	if maze:
		grid_position = maze.start_cell
	position = Grid.grid_to_world(grid_position)
	rotation_degrees.y = FACING_ROTATION_DEGREES[facing]

	# Timer filho (e não SceneTreeTimer): é liberado junto com a cena no reinício,
	# então uma manobra pendente nunca executa numa cápsula que já não existe.
	_maneuver_timer = Timer.new()
	_maneuver_timer.one_shot = true
	_maneuver_timer.timeout.connect(_finish_maneuver)
	add_child(_maneuver_timer)

	EventBus.request_move_forward.connect(_on_request_move_forward)
	EventBus.request_move_backward.connect(_on_request_move_backward)
	EventBus.request_rotate_left.connect(_on_request_rotate_left)
	EventBus.request_rotate_right.connect(_on_request_rotate_right)
	EventBus.request_sonar_ping.connect(_on_request_sonar_ping)


## Começa uma manobra: avisa a apresentação e agenda `action` para o fim.
## Ignorada se já houver outra em andamento ou se a partida acabou.
func _begin_maneuver(kind: StringName, duration: float, action: Callable) -> void:
	if maneuvering or GameState.state != GameState.State.PLAYING:
		return
	maneuvering = true
	_maneuver_kind = kind
	_maneuver_action = action
	EventBus.maneuver_started.emit(kind, duration)
	_maneuver_timer.start(duration)


func _finish_maneuver() -> void:
	maneuvering = false
	if GameState.state == GameState.State.PLAYING:
		_maneuver_action.call()
	EventBus.maneuver_finished.emit(_maneuver_kind)


func _on_request_move_forward() -> void:
	_begin_maneuver(&"forward", move_duration, func() -> void: _try_move(GRID_OFFSET[facing]))


## Ré: anda uma célula no sentido oposto ao que a cápsula aponta, sem girar.
func _on_request_move_backward() -> void:
	_begin_maneuver(&"backward", move_duration, func() -> void: _try_move(-GRID_OFFSET[facing]))

## Calcula a célula alvo a partir do deslocamento `direction`.
## Se a matriz disser que ela é bloqueada, a cápsula fica parada e emite capsule_collided;
## senão, atualiza grid_position e a posição 3D, e emite capsule_moved ("fui pra cá, nessa direção").
## Se a célula for a saída, emite capsule_reached_exit antes de capsule_moved (vitória tem prioridade sobre o custo do passo).
func _try_move(direction: Vector2i) -> void:
	var target := grid_position + direction
	if maze and not maze.is_walkable(target):
		EventBus.capsule_collided.emit(target, direction)
		return
	grid_position = target
	position = Grid.grid_to_world(grid_position)
	if maze and maze.is_exit(grid_position):
		EventBus.capsule_reached_exit.emit(grid_position)
	EventBus.capsule_moved.emit(grid_position, direction)

## Rotates chamam _rotate_facing(-1) ou _rotate_facing(1), que usa wrapi()
## pra girar o enum ciclicamente (de LEFT pra UP e vice-versa, sem quebrar),
## atualiza a rotação 3D (eixo Y, via o dicionário FACING_ROTATION_DEGREES) e emite capsule_rotated.
func _on_request_rotate_left() -> void:
	_begin_maneuver(&"rotate_left", rotate_duration, _rotate_facing.bind(-1))


func _on_request_rotate_right() -> void:
	_begin_maneuver(&"rotate_right", rotate_duration, _rotate_facing.bind(1))


func _rotate_facing(steps: int) -> void:
	facing = wrapi(facing + steps, 0, Facing.size())
	rotation_degrees.y = FACING_ROTATION_DEGREES[facing]
	EventBus.capsule_rotated.emit(GRID_OFFSET[facing])


## Sonar: um sinal em cada uma das 4 direções da grade, que segue reto até
## a primeira célula bloqueada. Só o primeiro obstáculo de cada sinal é revelado.
func _on_request_sonar_ping() -> void:
	_begin_maneuver(&"sonar", sonar_duration, _emit_sonar)


func _emit_sonar() -> void:
	var hits: Array[Vector2i] = []
	if maze:
		for direction: Vector2i in GRID_OFFSET.values():
			var cell := grid_position + direction
			while maze.is_walkable(cell):
				cell += direction
			hits.append(cell)
	EventBus.sonar_pinged.emit(grid_position, hits)
