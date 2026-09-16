extends Node2D
## Cápsula do jogador.
## Não lê input diretamente: reage às intenções emitidas pelo EventBus
## (originadas do painel de UI), mantendo a Capsule desacoplada da UI.
## Sempre "anda para frente" na direção atual e gira em incrementos de 90º.

enum Facing { UP, RIGHT, DOWN, LEFT }

const GRID_OFFSET := {
	Facing.UP: Vector2i(0, -1),
	Facing.RIGHT: Vector2i(1, 0),
	Facing.DOWN: Vector2i(0, 1),
	Facing.LEFT: Vector2i(-1, 0),
}

const FACING_ROTATION_DEGREES := {
	Facing.UP: 0.0,
	Facing.RIGHT: 90.0,
	Facing.DOWN: 180.0,
	Facing.LEFT: 270.0,
}

## Tamanho da célula do labirinto em pixels. Ainda não existe uma MazeGrid;
## este valor é local à Capsule até o sistema de grid ser implementado.
@export var cell_size: int = 64

## Célula onde a cápsula está - não é a posição em pixels;
## Conversão pra pixel acontece em _grid_to_pixel(), multiplicando pela cell_size.
@export var grid_position: Vector2i = Vector2i.ZERO

## Representa pra onde a cápsula está apontada.
var facing: Facing = Facing.UP


func _ready() -> void:
	position = _grid_to_pixel(grid_position)
	rotation_degrees = FACING_ROTATION_DEGREES[facing]

	EventBus.request_move_forward.connect(_on_request_move_forward)
	EventBus.request_rotate_left.connect(_on_request_rotate_left)
	EventBus.request_rotate_right.connect(_on_request_rotate_right)

## Pega o deslocamento correspondente à direção atual (dicionário GRID_OFFSET), soma à grid_position
## e atualiza a posição visual, e emite capsule_moved avisando "eu me movi, fui pra cá, nessa direção".
func _on_request_move_forward() -> void:
	var direction: Vector2i = GRID_OFFSET[facing]
	grid_position += direction
	position = _grid_to_pixel(grid_position)
	EventBus.capsule_moved.emit(grid_position, direction)

## Rotates chamam _rotate_facing(-1) ou _rotate_facing(1), que usa wrapi() 
## pra girar o enum ciclicamente (de LEFT pra UP e vice-versa, sem quebrar),
## atualiza a rotação visual (rotation_degrees, via o dicionário FACING_ROTATION_DEGREES) e emite capsule_rotated.
func _on_request_rotate_left() -> void:
	_rotate_facing(-1)


func _on_request_rotate_right() -> void:
	_rotate_facing(1)


func _rotate_facing(steps: int) -> void:
	facing = wrapi(facing + steps, 0, Facing.size())
	rotation_degrees = FACING_ROTATION_DEGREES[facing]
	EventBus.capsule_rotated.emit(GRID_OFFSET[facing])


func _grid_to_pixel(cell: Vector2i) -> Vector2:
	return Vector2(cell) * cell_size
