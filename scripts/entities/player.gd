extends CharacterBody3D
## Jogador em 1ª pessoa dentro da cabine da cápsula (sem malha própria).
## Dono dos modos de controle (State Pattern via enum):
##   WALKING    → WASD + mouse-look; clique esquerdo aciona o Interactable sob a mira.
##   NAVIGATING → sentado no posto: câmera vai para `seat_view`, mouse livre para o
##                painel de navegação na tela; clique direito levanta e volta a WALKING.
##   READING    → um texto está aberto; o jogador fica parado até note_closed.
##   DISABLED   → fim de partida; mouse livre para a tela de fim.
## Fala com a UI só pelo EventBus (navigation_mode_changed, interaction_prompt_changed).

enum Mode { WALKING, NAVIGATING, READING, DISABLED }

const PITCH_LIMIT := deg_to_rad(85.0)
const SEAT_TWEEN_TIME := 0.6

@export var walk_speed := 2.5
@export var mouse_sensitivity := 0.0025
## Ponto de vista ao sentar no posto de comando (olhando para o painel).
@export var seat_view: Node3D

var mode: Mode = Mode.WALKING

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _current_prompt := ""
var _shake_strength := 0.0
var _seat_tween: Tween

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
	if mode == Mode.NAVIGATING and event.is_action_pressed("exit_navigation"):
		get_viewport().set_input_as_handled()
		_exit_navigation()


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
	tween.tween_callback(EventBus.navigation_mode_changed.emit.bind(true))


func _exit_navigation() -> void:
	mode = Mode.WALKING
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.navigation_mode_changed.emit(false)
	_new_seat_tween().tween_property(_camera, "transform", Transform3D.IDENTITY, SEAT_TWEEN_TIME)


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
