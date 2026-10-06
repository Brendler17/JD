extends Node3D
## Cápsula do jogador.
## Não lê input diretamente: reage às intenções emitidas pelo EventBus
## (originadas do painel de UI), mantendo a Capsule desacoplada da UI.
## Sempre "anda para frente" na direção atual e gira em incrementos de 90º.
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

## Representa pra onde a cápsula está apontada.
var facing: Facing = Facing.UP


func _ready() -> void:
	if maze:
		grid_position = maze.start_cell
	position = Grid.grid_to_world(grid_position)
	rotation_degrees.y = FACING_ROTATION_DEGREES[facing]

	EventBus.request_move_forward.connect(_on_request_move_forward)
	EventBus.request_rotate_left.connect(_on_request_rotate_left)
	EventBus.request_rotate_right.connect(_on_request_rotate_right)

## Pega o deslocamento correspondente à direção atual (dicionário GRID_OFFSET) e calcula a célula alvo.
## Se a matriz disser que ela é bloqueada, a cápsula fica parada e emite capsule_collided;
## senão, atualiza grid_position e a posição 3D, e emite capsule_moved ("fui pra cá, nessa direção").
## Se a célula for a saída, emite capsule_reached_exit antes de capsule_moved (vitória tem prioridade sobre o custo do passo).
func _on_request_move_forward() -> void:
	var direction: Vector2i = GRID_OFFSET[facing]
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
	_rotate_facing(-1)


func _on_request_rotate_right() -> void:
	_rotate_facing(1)


func _rotate_facing(steps: int) -> void:
	facing = wrapi(facing + steps, 0, Facing.size())
	rotation_degrees.y = FACING_ROTATION_DEGREES[facing]
	EventBus.capsule_rotated.emit(GRID_OFFSET[facing])
