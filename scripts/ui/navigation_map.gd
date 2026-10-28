extends Control
## Tela do painel de navegação: mapa top-down do labirinto, desenhado em _draw().
## Começa sem nenhum obstáculo visível; só mostra o que a cápsula "descobriu":
##   - paredes reveladas por colisão (capsule_collided) e por sonar (sonar_pinged);
##   - o rastro de células já visitadas, a posição/direção atual e a saída;
##   - ecos do inimigo no sonar (enemy_detected): um ponto vermelho que some sozinho.
## "Dumb UI": não consulta a MazeGrid para regras, só para dimensões e saída;
## todo o conhecimento de paredes vem dos sinais do EventBus.

const SCREEN_COLOR := Color(0.02, 0.09, 0.09)
const GRID_COLOR := Color(0.1, 0.35, 0.33, 0.35)
const VISITED_COLOR := Color(0.12, 0.45, 0.42, 0.45)
const WALL_COLOR := Color(0.45, 0.95, 0.85)
const COLLISION_COLOR := Color(1.0, 0.35, 0.25)
const CAPSULE_COLOR := Color(1.0, 0.82, 0.3)
const EXIT_COLOR := Color(0.35, 1.0, 0.45)
const SONAR_COLOR := Color(0.5, 1.0, 0.95)
const SONAR_DURATION := 1.2
const FLASH_DURATION := 0.8
const ENEMY_ECHO_COLOR := Color(1.0, 0.2, 0.15)
const ENEMY_ECHO_DURATION := 2.5

var maze: MazeGrid:
	set(value):
		maze = value
		if maze:
			_capsule_cell = maze.start_cell
			_visited = {maze.start_cell: true}
		queue_redraw()

var _capsule_cell := Vector2i.ZERO
var _facing := Vector2i.UP
var _revealed := {}
var _visited := {}
var _sonar_origin := Vector2i.ZERO
var _sonar_hits: Array[Vector2i] = []
var _sonar_time := -1.0
var _flash_cell := Vector2i.ZERO
var _flash_time := -1.0
var _time := 0.0
var _echo_cell := Vector2i.ZERO
var _echo_time := -1.0


func _ready() -> void:
	EventBus.capsule_moved.connect(_on_capsule_moved)
	EventBus.capsule_rotated.connect(_on_capsule_rotated)
	EventBus.capsule_collided.connect(_on_capsule_collided)
	EventBus.sonar_pinged.connect(_on_sonar_pinged)
	EventBus.enemy_detected.connect(_on_enemy_detected)
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	_time += delta
	if _sonar_time >= 0.0:
		_sonar_time += delta
		if _sonar_time > SONAR_DURATION:
			_sonar_time = -1.0
	if _flash_time >= 0.0:
		_flash_time += delta
		if _flash_time > FLASH_DURATION:
			_flash_time = -1.0
	if _echo_time >= 0.0:
		_echo_time += delta
		if _echo_time > ENEMY_ECHO_DURATION:
			_echo_time = -1.0
	if is_visible_in_tree():
		queue_redraw()


func _on_capsule_moved(new_position: Vector2i, _direction: Vector2i) -> void:
	_capsule_cell = new_position
	_visited[new_position] = true


func _on_capsule_rotated(new_direction: Vector2i) -> void:
	_facing = new_direction


func _on_capsule_collided(blocked_cell: Vector2i, _direction: Vector2i) -> void:
	_reveal(blocked_cell)
	_flash_cell = blocked_cell
	_flash_time = 0.0


func _on_sonar_pinged(origin: Vector2i, hits: Array[Vector2i]) -> void:
	for cell in hits:
		_reveal(cell)
	_sonar_origin = origin
	_sonar_hits = hits
	_sonar_time = 0.0


func _on_enemy_detected(cell: Vector2i) -> void:
	_echo_cell = cell
	_echo_time = 0.0


func _reveal(cell: Vector2i) -> void:
	if maze and maze.is_inside(cell):
		_revealed[cell] = true


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SCREEN_COLOR)
	if maze == null or maze.width == 0:
		return

	var cell_px := floorf(minf(size.x / maze.width, size.y / maze.height))
	var origin := (size - Vector2(maze.width, maze.height) * cell_px) * 0.5

	for cell: Vector2i in _visited:
		draw_rect(_cell_rect(cell, origin, cell_px).grow(-1.0), VISITED_COLOR)

	for x in maze.width + 1:
		var px := origin.x + x * cell_px
		draw_line(Vector2(px, origin.y), Vector2(px, origin.y + maze.height * cell_px), GRID_COLOR)
	for y in maze.height + 1:
		var py := origin.y + y * cell_px
		draw_line(Vector2(origin.x, py), Vector2(origin.x + maze.width * cell_px, py), GRID_COLOR)

	for cell: Vector2i in _revealed:
		draw_rect(_cell_rect(cell, origin, cell_px).grow(-1.0), WALL_COLOR)

	if _flash_time >= 0.0:
		var alpha := 1.0 - _flash_time / FLASH_DURATION
		draw_rect(_cell_rect(_flash_cell, origin, cell_px).grow(cell_px * 0.15), Color(COLLISION_COLOR, alpha), false, 3.0)

	var exit_pulse := 0.6 + 0.4 * sin(_time * 4.0)
	var exit_rect := _cell_rect(maze.exit_cell, origin, cell_px).grow(-cell_px * 0.2)
	draw_rect(exit_rect, Color(EXIT_COLOR, exit_pulse))

	if _sonar_time >= 0.0:
		_draw_sonar(origin, cell_px)

	if _echo_time >= 0.0:
		var echo_alpha := (1.0 - _echo_time / ENEMY_ECHO_DURATION) * (0.6 + 0.4 * sin(_time * 12.0))
		var echo_center := _cell_center(_echo_cell, origin, cell_px)
		draw_circle(echo_center, cell_px * 0.3, Color(ENEMY_ECHO_COLOR, echo_alpha))
		draw_arc(echo_center, cell_px * (0.45 + _echo_time * 0.2), 0.0, TAU, 24, Color(ENEMY_ECHO_COLOR, echo_alpha * 0.6), 2.0)

	_draw_capsule(origin, cell_px)


func _draw_sonar(origin: Vector2, cell_px: float) -> void:
	var t := _sonar_time / SONAR_DURATION
	var from := _cell_center(_sonar_origin, origin, cell_px)
	for hit in _sonar_hits:
		var to := _cell_center(hit, origin, cell_px)
		var travel := clampf(t * 2.0, 0.0, 1.0)
		var alpha := 1.0 - clampf((t - 0.5) * 2.0, 0.0, 1.0)
		draw_line(from, from.lerp(to, travel), Color(SONAR_COLOR, alpha * 0.8), 2.0)
		if travel >= 1.0:
			draw_arc(to, cell_px * (0.3 + t), 0.0, TAU, 20, Color(SONAR_COLOR, alpha), 2.0)
	draw_arc(from, cell_px * t * maze.width * 0.5, 0.0, TAU, 48, Color(SONAR_COLOR, 0.4 * (1.0 - t)), 2.0)


## Triângulo apontando para a direção atual.
func _draw_capsule(origin: Vector2, cell_px: float) -> void:
	var center := _cell_center(_capsule_cell, origin, cell_px)
	var forward := Vector2(_facing).normalized() * cell_px * 0.38
	var side := Vector2(-forward.y, forward.x) * 0.75
	var points := PackedVector2Array([center + forward, center - forward + side, center - forward - side])
	draw_colored_polygon(points, CAPSULE_COLOR)


func _cell_rect(cell: Vector2i, origin: Vector2, cell_px: float) -> Rect2:
	return Rect2(origin + Vector2(cell) * cell_px, Vector2.ONE * cell_px)


func _cell_center(cell: Vector2i, origin: Vector2, cell_px: float) -> Vector2:
	return origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_px
