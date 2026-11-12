extends CharacterBody3D
## Jogador em 1ª pessoa dentro da cabine da cápsula (sem malha própria).
## Dono dos modos de controle (State Pattern via enum):
##   WALKING    → WASD + mouse-look; clique esquerdo aciona o Interactable sob a mira.
##   NAVIGATING → sentado no posto: câmera vai para `seat_view` e o cursor fica livre.
##                Com o cursor na faixa das bordas, o olhar gira naquela direção e
##                fica onde parou quando o cursor sai dela (edge-pan): o que se vê
##                não escorrega de baixo do cursor na hora de clicar. Cliques/movimento do cursor são
##                lançados como raio na camada do painel (PanelScreen.PANEL_LAYER) e
##                repassados ao controle atingido — tela (PanelScreen) ou tecla física
##                (PanelButton3D), ambos com forward_mouse()/release_hover().
##                Clique direito levanta e volta a WALKING.
##   READING    → um texto está aberto; o jogador fica parado até note_closed.
##   DISABLED   → fim de partida; mouse livre para a tela de fim.
## Fala com a UI só pelo EventBus (navigation_mode_changed, interaction_prompt_changed).

enum Mode { WALKING, NAVIGATING, READING, DISABLED }

const PITCH_LIMIT := deg_to_rad(85.0)
const SEAT_TWEEN_TIME := 0.6
## Quanto o olhar gira quando o cursor encosta nas bordas, sentado no posto.
const SEAT_YAW_RANGE := deg_to_rad(20.0)
const SEAT_PITCH_UP := deg_to_rad(34.0)
const SEAT_PITCH_DOWN := deg_to_rad(14.0)
## A partir desta fração (0..1, do centro até a borda) o cursor gira o olhar.
const SEAT_EDGE_START := 0.8
## Velocidade do giro com o cursor encostado na borda (fração do alcance por segundo).
const SEAT_EDGE_SPEED := 1.4
const PANEL_RAY_LENGTH := 4.0

@export var walk_speed := 2.5
@export var mouse_sensitivity := 0.0025
## Ponto de vista ao sentar no posto de comando (olhando para o painel).
@export var seat_view: Node3D

var mode: Mode = Mode.WALKING

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _current_prompt := ""
var _shake_strength := 0.0
var _seat_tween: Tween
## Sentado e com a câmera já no posto (fim da animação de sentar).
var _seated := false
## Olhar atual relativo ao seat_view, em -1..1 por eixo (fração do alcance).
var _seat_look := Vector2.ZERO
## Valor suavizado aplicado à câmera.
var _seat_look_smoothed := Vector2.ZERO
## Controle do painel sob o cursor / onde o botão do mouse foi pressionado
## (PanelScreen ou PanelButton3D — interface forward_mouse/release_hover).
var _hovered_control: Node3D
var _pressed_control: Node3D

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _interact_ray: RayCast3D = $Head/Camera3D/InteractRay


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.request_enter_navigation.connect(_on_request_enter_navigation)
	EventBus.request_show_note.connect(_on_request_show_note)
	EventBus.note_closed.connect(_on_note_closed)
	EventBus.capsule_collided.connect(_on_capsule_collided)
	EventBus.game_over.connect(_on_game_over)


func _unhandled_input(event: InputEvent) -> void:
	if mode != Mode.WALKING:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_head.rotation.x = clampf(_head.rotation.x - event.relative.y * mouse_sensitivity, -PITCH_LIMIT, PITCH_LIMIT)
	elif event.is_action_pressed("interact"):
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_interact()
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Clique direito precisa ser lido em _input: no modo de navegação o painel (Controls)
## consome os cliques do mouse antes de chegarem a _unhandled_input.
func _input(event: InputEvent) -> void:
	if mode != Mode.NAVIGATING:
		return
	if event.is_action_pressed("exit_navigation"):
		get_viewport().set_input_as_handled()
		_exit_navigation()
	elif _seated and (event is InputEventMouseMotion or event is InputEventMouseButton):
		_forward_to_panel(event as InputEventMouse)


func _process(delta: float) -> void:
	if mode == Mode.NAVIGATING and _seated and seat_view:
		_update_seat_look(delta)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input := Vector2.ZERO
	if mode == Mode.WALKING:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := transform.basis * Vector3(input.x, 0.0, input.y)
	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed
	move_and_slide()

	_update_prompt()
	_update_shake(delta)


func _interact() -> void:
	var target := _interact_ray.get_collider() as Interactable
	if target:
		target.interact()


func _update_prompt() -> void:
	var prompt := ""
	if mode == Mode.WALKING:
		var target := _interact_ray.get_collider() as Interactable
		if target:
			prompt = target.prompt
	if prompt != _current_prompt:
		_current_prompt = prompt
		EventBus.interaction_prompt_changed.emit(prompt)


func _on_request_enter_navigation() -> void:
	if mode != Mode.WALKING:
		return
	mode = Mode.NAVIGATING
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tween := _new_seat_tween()
	if seat_view:
		tween.tween_property(_camera, "global_transform", seat_view.global_transform, SEAT_TWEEN_TIME)
	tween.tween_callback(_on_seated)


func _on_seated() -> void:
	_seated = true
	_seat_look = Vector2.ZERO
	_seat_look_smoothed = Vector2.ZERO
	EventBus.navigation_mode_changed.emit(true)


func _exit_navigation() -> void:
	_seated = false
	_set_hovered_control(null)
	_pressed_control = null
	mode = Mode.WALKING
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.navigation_mode_changed.emit(false)
	_new_seat_tween().tween_property(_camera, "transform", Transform3D.IDENTITY, SEAT_TWEEN_TIME)


## Olhar sentado (edge-pan): só gira enquanto o cursor está na faixa das bordas,
## mais rápido quanto mais perto da borda, e mantém a orientação quando o cursor
## volta para o meio. Cima tem mais alcance (monitor superior e knob do alarme).
func _update_seat_look(delta: float) -> void:
	var viewport := get_viewport()
	var screen := viewport.get_visible_rect().size
	var cursor := viewport.get_mouse_position() / screen * 2.0 - Vector2.ONE
	var push := Vector2(_edge_response(cursor.x), _edge_response(cursor.y))
	_seat_look = (_seat_look + push * SEAT_EDGE_SPEED * delta).clampf(-1.0, 1.0)
	_seat_look_smoothed = _seat_look_smoothed.lerp(_seat_look, 1.0 - exp(-delta * 10.0))
	var yaw := -_seat_look_smoothed.x * SEAT_YAW_RANGE
	var pitch := -_seat_look_smoothed.y * (SEAT_PITCH_UP if _seat_look_smoothed.y < 0.0 else SEAT_PITCH_DOWN)
	_camera.global_transform = seat_view.global_transform * Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0)), Vector3.ZERO)


func _edge_response(value: float) -> float:
	return signf(value) * smoothstep(SEAT_EDGE_START, 1.0, absf(value))


## Lança o cursor como raio na camada do painel e repassa o evento ao controle
## atingido. Soltar o botão sempre vai para o controle onde ele foi pressionado
## (senão uma tecla ficaria "presa" ao arrastar o cursor para fora).
func _forward_to_panel(event: InputEventMouse) -> void:
	var from := _camera.project_ray_origin(event.position)
	var query := PhysicsRayQueryParameters3D.create(from, from + _camera.project_ray_normal(event.position) * PANEL_RAY_LENGTH, PanelScreen.PANEL_LAYER)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var control: Node3D = null
	if hit:
		control = (hit.collider as Node).get_parent() as Node3D
		if control and not control.has_method(&"forward_mouse"):
			control = null
	_set_hovered_control(control)

	var button := event as InputEventMouseButton
	if button and not button.pressed and _pressed_control:
		var target := _pressed_control
		_pressed_control = null
		var plane := Plane(target.global_basis.z, target.global_position)
		var point: Variant = plane.intersects_ray(from, _camera.project_ray_normal(event.position))
		target.forward_mouse(event, point if point != null else target.global_position)
		get_viewport().set_input_as_handled()
		return
	if control:
		if button and button.pressed:
			_pressed_control = control
		control.forward_mouse(event, hit.position)
		get_viewport().set_input_as_handled()


func _set_hovered_control(control: Node3D) -> void:
	if control == _hovered_control:
		return
	if _hovered_control:
		_hovered_control.release_hover()
	_hovered_control = control


## Sentar/levantar nunca rodam juntos: levantar no meio da animação cancela a de sentar.
func _new_seat_tween() -> Tween:
	if _seat_tween:
		_seat_tween.kill()
	_seat_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return _seat_tween


func _on_request_show_note(_title: String, _body: String) -> void:
	if mode == Mode.WALKING:
		mode = Mode.READING


func _on_note_closed() -> void:
	if mode == Mode.READING:
		mode = Mode.WALKING


## O impacto da cápsula numa parede chacoalha a câmera, em qualquer modo.
func _on_capsule_collided(_blocked_cell: Vector2i, _direction: Vector2i) -> void:
	_shake_strength = 0.06


func _update_shake(delta: float) -> void:
	_shake_strength = move_toward(_shake_strength, 0.0, delta * 0.15)
	_camera.h_offset = randf_range(-1.0, 1.0) * _shake_strength
	_camera.v_offset = randf_range(-1.0, 1.0) * _shake_strength


func _on_game_over(_won: bool) -> void:
	mode = Mode.DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
