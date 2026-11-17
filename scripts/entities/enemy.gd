extends Node3D
## Criatura invisível que vive no labirinto. Age em turnos: cada ação da cápsula
## que a desloca ou faz barulho (andar, colidir, sonar) dá a ela um turno logo
## depois. Girar NÃO dá turno (rodada 2, R2): é mirar, não se deslocar.
## Período de calma (R1): nos primeiros CALM_TURNS turnos ela dorme (não se move
## nem reage ao sonar; trombar nela ainda é golpe) e nasce a INITIAL_SPAWN_DISTANCE
## passos ou mais, para o jogador aprender os instrumentos sem pressão.
## Comportamento (State Pattern via enum) — GDD §4.6 e §4.6.1:
##   WANDERING → vaga devagar (1 passo a cada WANDER_INTERVAL turnos), sem rumo.
##   HUNTING   → ouviu um pulso de sonar longe: segue o menor caminho até a célula
##               de onde ele saiu, 1 passo por turno. Chegou e não achou nada →
##               mergulha (DIVING).
##   STALKING  → sentiu a cápsula (a SENSE_RANGE passos ou menos): ronda devagar,
##               1 passo a cada STALK_INTERVAL turnos. Encostada (1 passo), joga o
##               dado a cada turno: ATTACK_CHANCE de atacar, senão hesita; a
##               primeira encostada da partida sempre hesita (R4). Se a
##               cápsula se afastar além de STALK_LOSE_RANGE, perde o rastro e vaga.
##   CHARGING  → o sonar foi usado com ela a CHARGE_RADIUS ou menos (R3: ver ≠
##               chamar; entre CHARGE_RADIUS e SONAR_DETECT_RADIUS o pulso a revela
##               mas ela só caça o ponto, como de longe): avança direto, 1 passo
##               por turno, e ataca sem dado ao encostar.
##   DIVING    → depois de atacar (ou de investigar um pulso à toa) some do labirinto
##               por DIVE_TURNS turnos e reaparece a MIN_SPAWN_DISTANCE passos ou
##               mais da cápsula. Enquanto isso, proximidade = -1 (alívio).
## A cápsula entrar na célula dela também é ataque, sem dado.
## Ataque = enemy_attacked; o GameState desconta o casco e decide se foi letal.
## Sonar emite enemy_detected (eco) se a criatura estiver a até SONAR_DETECT_RADIUS
## células da origem (em linha reta, através das paredes) ou no feixe reto de
## uma das 4 direções antes da parede.
## A posição 3D só existe para a cena de debug; da cabine ela nunca é vista.

enum State { WANDERING, HUNTING, STALKING, CHARGING, DIVING }

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
## Turnos entre passos enquanto vaga.
const WANDER_INTERVAL := 2
## Distância (em passos) a partir da qual a criatura sente a cápsula e passa a rondá-la.
const SENSE_RANGE := 2
## Turnos entre passos enquanto ronda (mais lenta que a cápsula: janela de fuga).
const STALK_INTERVAL := 2
## Além desta distância (em passos), a ronda perde o rastro.
const STALK_LOSE_RANGE := 4
## Encostada na cápsula, chance de atacar em cada turno (o resto é hesitação).
const ATTACK_CHANCE := 0.3
## Turnos fora do labirinto depois de mergulhar.
const DIVE_TURNS := 4
## Distância mínima (em passos) da cápsula ao reaparecer depois de mergulhar.
const MIN_SPAWN_DISTANCE := 10
## Distância mínima (em passos) do início ao nascer, no começo da partida.
const INITIAL_SPAWN_DISTANCE := 14
## Turnos iniciais em que ela dorme (período de calma).
const CALM_TURNS := 15
## Raio (células, em linha reta) em que o sonar a faz vir em carga. Menor que o
## raio em que o sonar a revela (GameState.SONAR_DETECT_RADIUS).
const CHARGE_RADIUS := 3.0

@export var maze: MazeGrid

var grid_position := Vector2i.ZERO
var state: State = State.WANDERING

var _capsule_cell := Vector2i.ZERO
var _target := Vector2i.ZERO
var _turn := 0
var _dive_turns_left := 0
var _previous_cell := Vector2i(-1, -1)
## A primeira encostada da partida sempre hesita (ensina a regra sem custar casco).
var _has_hesitated := false


func _ready() -> void:
	if maze == null:
		return
	_capsule_cell = maze.start_cell
	grid_position = _pick_far_cell(maze.start_cell, INITIAL_SPAWN_DISTANCE)
	position = Grid.grid_to_world(grid_position)

	EventBus.capsule_moved.connect(_on_capsule_moved)
	EventBus.capsule_collided.connect(func(_cell: Vector2i, _dir: Vector2i) -> void: _take_turn())
	EventBus.sonar_pinged.connect(_on_sonar_pinged)
	_emit_proximity.call_deferred()


## Entrar na célula da criatura é trombar com ela: ataque garantido (é o turno dela).
func _on_capsule_moved(new_position: Vector2i, _direction: Vector2i) -> void:
	_capsule_cell = new_position
	if state != State.DIVING and grid_position == _capsule_cell and _is_playing():
		_attack()
		return
	_take_turn()


## O pulso é barulho. Dentro do raio, ela vem direto (ataque garantido);
## fora dele, passa a caçar a célula de onde o pulso saiu.
## Há eco se ela está dentro do raio ou no caminho de um dos 4 sinais.
func _on_sonar_pinged(origin: Vector2i, hits: Array[Vector2i]) -> void:
	if state == State.DIVING:
		_take_turn()
		return
	var distance := Vector2(grid_position - origin).length()
	var detected := distance <= GameState.SONAR_DETECT_RADIUS
	for hit in hits:
		if _is_between(origin, hit, grid_position):
			detected = true
	if detected:
		EventBus.enemy_detected.emit(grid_position)
	# Dormindo, o pulso a revela, mas ela não reage.
	if is_calm():
		_take_turn()
		return
	if distance <= CHARGE_RADIUS:
		state = State.CHARGING
		EventBus.enemy_charging.emit(grid_position)
	else:
		state = State.HUNTING
		_target = origin
	EventBus.enemy_heard_sonar.emit(_distance_to_capsule())
	_take_turn()


func _take_turn() -> void:
	if not _is_playing():
		return
	_turn += 1
	if is_calm():
		_emit_proximity()
		return
	if state == State.DIVING:
		_dive_turns_left -= 1
		if _dive_turns_left <= 0:
			_surface()
		_emit_proximity()
		return

	var distance := _distance_to_capsule()
	if (state == State.WANDERING or state == State.HUNTING) and distance <= SENSE_RANGE:
		state = State.STALKING

	match state:
		State.CHARGING:
			_step_towards(_capsule_cell)
			if _distance_to_capsule() <= 1:
				_attack()
				return
		State.STALKING:
			if distance <= 1:
				var first_time := not _has_hesitated
				_has_hesitated = true
				if not first_time and randf() < ATTACK_CHANCE:
					_attack()
					return
				# Hesitou: fica rondando ao lado, sem avançar.
				EventBus.enemy_hesitated.emit(grid_position)
			elif distance > STALK_LOSE_RANGE:
				state = State.WANDERING
			elif _turn % STALK_INTERVAL == 0:
				_step_towards(_capsule_cell)
		State.HUNTING:
			_step_towards(_target)
			if grid_position == _target:
				if _distance_to_capsule() <= SENSE_RANGE:
					state = State.STALKING
				else:
					_dive()
					return
		State.WANDERING:
			if _turn % WANDER_INTERVAL == 0:
				_wander()

	position = Grid.grid_to_world(grid_position)
	_emit_proximity()


## Golpe no casco. Se não foi letal (a partida segue), ela mergulha.
func _attack() -> void:
	EventBus.enemy_attacked.emit(grid_position)
	if _is_playing():
		_dive()


func _dive() -> void:
	state = State.DIVING
	_dive_turns_left = DIVE_TURNS
	_emit_proximity()


func _surface() -> void:
	state = State.WANDERING
	_previous_cell = Vector2i(-1, -1)
	grid_position = _pick_far_cell(_capsule_cell, MIN_SPAWN_DISTANCE)
	position = Grid.grid_to_world(grid_position)


## Ainda no período de calma do início da partida?
func is_calm() -> bool:
	return _turn <= CALM_TURNS


func _is_playing() -> bool:
	return GameState.state == GameState.State.PLAYING


## Distância em passos pelo labirinto; sem caminho = um número enorme.
func _distance_to_capsule() -> int:
	return maze.get_distances_from(_capsule_cell).get(grid_position, 1 << 30)


## Um passo pelo menor caminho até `target` (BFS a partir do alvo).
## Nunca entra na célula da cápsula: contato só acontece por _attack().
func _step_towards(target: Vector2i) -> void:
	var distances := maze.get_distances_from(target)
	var best := grid_position
	var best_distance: int = distances.get(grid_position, 1 << 30)
	for dir in DIRECTIONS:
		var next := grid_position + dir
		if next != _capsule_cell and distances.has(next) and distances[next] < best_distance:
			best = next
			best_distance = distances[next]
	_move_to(best)


## Passo aleatório, evitando voltar para a célula anterior (exceto em becos sem saída).
func _wander() -> void:
	var options: Array[Vector2i] = []
	for dir in DIRECTIONS:
		var next := grid_position + dir
		if maze.is_walkable(next) and next != _previous_cell and next != _capsule_cell:
			options.append(next)
	if options.is_empty():
		var back_ok := maze.is_walkable(_previous_cell) and _previous_cell != _capsule_cell
		_move_to(_previous_cell if back_ok else grid_position)
	else:
		_move_to(options.pick_random())


func _move_to(cell: Vector2i) -> void:
	_previous_cell = grid_position
	grid_position = cell


## -1 = sem caminho ou fora do labirinto (mergulhada).
func _emit_proximity() -> void:
	var steps: int = -1
	if state != State.DIVING:
		steps = maze.get_distances_from(_capsule_cell).get(grid_position, -1)
	EventBus.enemy_proximity_changed.emit(steps)


## Célula a `min_distance` passos ou mais de `from` (a mais distante, se nenhuma).
func _pick_far_cell(from: Vector2i, min_distance: int) -> Vector2i:
	var distances := maze.get_distances_from(from)
	var candidates: Array[Vector2i] = []
	var farthest := from
	for cell: Vector2i in distances:
		if cell == maze.exit_cell:
			continue
		if distances[cell] >= min_distance:
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
