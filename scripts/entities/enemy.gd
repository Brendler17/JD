extends Node3D
## Criatura invisível que vive no labirinto. Age em turnos: cada ação da cápsula
## (andar, girar, colidir, sonar) dá a ela um turno logo depois.
## Comportamento (State Pattern via enum):
##   WANDERING → vaga devagar (1 passo a cada WANDER_INTERVAL turnos), sem rumo.
##   HUNTING   → ouviu um pulso de sonar: segue o menor caminho até a célula de onde
##               ele foi emitido, 1 passo por turno. Ao chegar e não achar nada,
##               volta a vagar. Se estiver a SENSE_RANGE passos da cápsula, persegue
##               a cápsula diretamente, onde quer que ela esteja.
## Ocupar a mesma célula que a cápsula (ela entra na célula do inimigo ou o
## inimigo entra na dela) emite capsule_caught → derrota.
## Sonar que passa pelo inimigo antes da parede emite enemy_detected (eco).
## A posição 3D só existe para a cena de debug; da cabine ele nunca é visto.

enum State { WANDERING, HUNTING }

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
## Turnos entre passos enquanto vaga.
const WANDER_INTERVAL := 2
## Distância (em passos) a partir da qual o inimigo "sente" a cápsula e a persegue.
const SENSE_RANGE := 2
## Distância mínima (em passos) da célula inicial do jogador ao nascer.
const MIN_SPAWN_DISTANCE := 10

@export var maze: MazeGrid

var grid_position := Vector2i.ZERO
var state: State = State.WANDERING

var _capsule_cell := Vector2i.ZERO
var _target := Vector2i.ZERO
var _turn := 0
var _previous_cell := Vector2i(-1, -1)


func _ready() -> void:
	if maze == null:
		return
	_capsule_cell = maze.start_cell
	grid_position = _pick_spawn_cell()
	position = Grid.grid_to_world(grid_position)

	EventBus.capsule_moved.connect(_on_capsule_moved)
	EventBus.capsule_rotated.connect(func(_dir: Vector2i) -> void: _take_turn())
	EventBus.capsule_collided.connect(func(_cell: Vector2i, _dir: Vector2i) -> void: _take_turn())
	EventBus.sonar_pinged.connect(_on_sonar_pinged)
	_emit_proximity.call_deferred()


func _on_capsule_moved(new_position: Vector2i, _direction: Vector2i) -> void:
	_capsule_cell = new_position
	if _check_caught():
		return
	_take_turn()


## O pulso é barulho: o inimigo passa a caçar a célula de onde ele veio.
## Se algum dos 4 sinais passou por ele antes de bater na parede, há um eco.
func _on_sonar_pinged(origin: Vector2i, hits: Array[Vector2i]) -> void:
	for hit in hits:
		if _is_between(origin, hit, grid_position):
			EventBus.enemy_detected.emit(grid_position)
	state = State.HUNTING
	_target = origin
	_take_turn()


func _take_turn() -> void:
	if GameState.state != GameState.State.PLAYING:
		return
	_turn += 1
	var distances := maze.get_distances_from(_capsule_cell)
	if distances.get(grid_position, INF) <= SENSE_RANGE:
		state = State.HUNTING
		_target = _capsule_cell

	match state:
		State.HUNTING:
			_step_towards(_target)
			if grid_position == _target and grid_position != _capsule_cell:
				state = State.WANDERING
		State.WANDERING:
			if _turn % WANDER_INTERVAL == 0:
				_wander()

	position = Grid.grid_to_world(grid_position)
	if not _check_caught():
		_emit_proximity()


func _check_caught() -> bool:
	if grid_position != _capsule_cell or GameState.state != GameState.State.PLAYING:
		return false
	EventBus.capsule_caught.emit(grid_position)
	return true


## Um passo pelo menor caminho até `target` (BFS a partir do alvo).
func _step_towards(target: Vector2i) -> void:
	var distances := maze.get_distances_from(target)
	var best := grid_position
	var best_distance: int = distances.get(grid_position, 1 << 30)
	for dir in DIRECTIONS:
		var next := grid_position + dir
		if distances.has(next) and distances[next] < best_distance:
			best = next
			best_distance = distances[next]
	_move_to(best)


## Passo aleatório, evitando voltar para a célula anterior (exceto em becos sem saída).
func _wander() -> void:
	var options: Array[Vector2i] = []
	for dir in DIRECTIONS:
		var next := grid_position + dir
		if maze.is_walkable(next) and next != _previous_cell:
			options.append(next)
	if options.is_empty():
		_move_to(_previous_cell if maze.is_walkable(_previous_cell) else grid_position)
	else:
		_move_to(options.pick_random())


func _move_to(cell: Vector2i) -> void:
	_previous_cell = grid_position
	grid_position = cell


func _emit_proximity() -> void:
	EventBus.enemy_proximity_changed.emit(maze.get_distances_from(_capsule_cell).get(grid_position, -1))


func _pick_spawn_cell() -> Vector2i:
	var distances := maze.get_distances_from(maze.start_cell)
	var candidates: Array[Vector2i] = []
	var farthest := maze.start_cell
	for cell: Vector2i in distances:
		if cell == maze.exit_cell:
			continue
		if distances[cell] >= MIN_SPAWN_DISTANCE:
			candidates.append(cell)
		if distances[cell] > distances[farthest]:
			farthest = cell
	return candidates.pick_random() if not candidates.is_empty() else farthest


## `cell` está no segmento reto entre `origin` (exclusivo) e `hit` (exclusivo)?
func _is_between(origin: Vector2i, hit: Vector2i, cell: Vector2i) -> bool:
	if cell == origin or cell == hit:
		return false
	if origin.x == hit.x and cell.x == origin.x:
		return cell.y > mini(origin.y, hit.y) and cell.y < maxi(origin.y, hit.y)
	if origin.y == hit.y and cell.y == origin.y:
		return cell.x > mini(origin.x, hit.x) and cell.x < maxi(origin.x, hit.x)
	return false

