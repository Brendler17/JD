extends CharacterBody3D
## Jogador em 1ª pessoa dentro da cabine da cápsula (sem malha própria).
## Dono dos modos de controle (State Pattern via enum):
##   WALKING    → WASD + mouse-look; clique esquerdo aciona o Interactable sob a mira.
##   NAVIGATING → sentado no posto: câmera vai para `seat_view`. O mouse continua
##                capturado e move o olhar (mouse-look), limitado a SEAT_YAW_RANGE /
##                SEAT_PITCH_UP / SEAT_PITCH_DOWN em torno do seat_view. A mira central
##                é lançada como raio na camada do painel (PanelScreen.PANEL_LAYER) a
##                cada frame (hover) e no clique; o evento vai ao controle atingido —
##                tela (PanelScreen) ou tecla física (PanelButton3D), ambos com
##                forward_mouse()/release_hover(). A ação da tecla sob a mira aparece
##                no prompt da HUD. Clique direito levanta e volta a WALKING.
##   READING    → um texto está aberto; o jogador fica parado até note_closed.
##   DISABLED   → fim de partida; mouse livre para a tela de fim.
## Fala com a UI só pelo EventBus (navigation_mode_changed, interaction_prompt_changed).

enum Mode { WALKING, NAVIGATING, READING, DISABLED }

const PITCH_LIMIT := deg_to_rad(85.0)
const SEAT_TWEEN_TIME := 0.6
## Limites do olhar sentado no posto, em torno do seat_view. Medidos a partir dele:
## knob do alarme a 29,5° de lado e 26° acima; mostradores de O₂/interferência a ~30°
## de lado; centro do monitor superior a 42° acima. Os limites dão folga sobre isso.
const SEAT_YAW_RANGE := deg_to_rad(40.0)
const SEAT_PITCH_UP := deg_to_rad(50.0)
const SEAT_PITCH_DOWN := deg_to_rad(20.0)
const PANEL_RAY_LENGTH := 4.0
## Inclinação máxima da câmera (pitch, yaw, roll) no meio de cada manobra da cápsula:
## andar "empurra" o corpo para trás/frente, girar inclina para o lado da curva.
const MANEUVER_TILT := {
	&"forward": Vector3(0.022, 0.0, 0.0),
	&"backward": Vector3(-0.022, 0.0, 0.0),
	&"rotate_left": Vector3(0.0, 0.012, 0.045),
	&"rotate_right": Vector3(0.0, -0.012, -0.045),
	&"sonar": Vector3.ZERO,
}
## Vibração contínua do casco durante deslocamentos (somada ao tremor de colisão).
const MANEUVER_RUMBLE := 0.0035
## Tranco máximo (pitch, yaw, roll em rad) de um golpe no casco com força 1 (cabin_impact).
const IMPACT_KICK := Vector3(0.14, 0.05, 0.1)
const IMPACT_SHAKE := 0.14

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
## Olhar atual relativo ao seat_view, em radianos (x = yaw, y = pitch; + = cima).
var _seat_look := Vector2.ZERO
## Controle do painel sob o cursor / onde o botão do mouse foi pressionado
## (PanelScreen ou PanelButton3D — interface forward_mouse/release_hover).
## Manobra atual da cápsula, para o balanço da câmera (tempo < 0 = nenhuma).
var _maneuver_kind := &""
var _maneuver_time := -1.0
var _maneuver_duration := 1.0
var _maneuver_tilt := Vector3.ZERO
var _hovered_control: Node3D
## Tranco atual da câmera (golpe no casco), decai sozinho.
var _kick := Vector3.ZERO
## Pose local da câmera sobre a qual o tranco é aplicado fora do posto
## (identidade andando; a pose do posto congelada no fim da partida).
var _camera_rest := Transform3D.IDENTITY
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
	EventBus.maneuver_started.connect(_on_maneuver_started)
	EventBus.game_over.connect(_on_game_over)
	EventBus.cabin_impact.connect(_on_cabin_impact)


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


## Sentado, o mouse é lido em _input (antes de qualquer Control): movimento gira o
## olhar, clique esquerdo vai para o controle sob a mira, clique direito levanta.
func _input(event: InputEvent) -> void:
	if mode != Mode.NAVIGATING:
		return
	if event.is_action_pressed("exit_navigation"):
		get_viewport().set_input_as_handled()
		_exit_navigation()
		return
	if not _seated:
		return
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Cursor liberado (Esc): o primeiro clique só recaptura.
		if event is InputEventMouseButton and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_seat_look.x = clampf(_seat_look.x - event.relative.x * mouse_sensitivity, -SEAT_YAW_RANGE, SEAT_YAW_RANGE)
		_seat_look.y = clampf(_seat_look.y - event.relative.y * mouse_sensitivity, -SEAT_PITCH_DOWN, SEAT_PITCH_UP)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var click := event.duplicate() as InputEventMouseButton
		click.position = _screen_center()
		click.global_position = click.position
		_forward_to_panel(click)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_update_maneuver_motion(delta)
	_kick = _kick.lerp(Vector3.ZERO, 1.0 - exp(-delta * 3.5))
	if mode == Mode.NAVIGATING and _seated and seat_view:
		_update_seat_look()
		_update_panel_hover()
	elif not (_seat_tween and _seat_tween.is_running()):
		_camera.transform = _camera_rest * Transform3D(Basis.from_euler(_kick), Vector3.ZERO)


func _on_maneuver_started(kind: StringName, duration: float) -> void:
	_maneuver_kind = kind
	_maneuver_duration = maxf(duration, 0.01)
	_maneuver_time = 0.0


## Envelope seno (0 → 1 → 0) ao longo da manobra: a cabine inclina e volta.
## Deslocamentos também vibram (rumble), alimentando o mesmo tremor da colisão.
func _update_maneuver_motion(delta: float) -> void:
	if _maneuver_time < 0.0:
		_maneuver_tilt = _maneuver_tilt.lerp(Vector3.ZERO, 1.0 - exp(-delta * 8.0))
		return
	_maneuver_time += delta
	var t := clampf(_maneuver_time / _maneuver_duration, 0.0, 1.0)
	var envelope := sin(t * PI)
	_maneuver_tilt = MANEUVER_TILT.get(_maneuver_kind, Vector3.ZERO) * envelope
	if _maneuver_kind == &"forward" or _maneuver_kind == &"backward":
		_shake_strength = maxf(_shake_strength, MANEUVER_RUMBLE * envelope)
	if t >= 1.0:
		_maneuver_time = -1.0


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

	if mode != Mode.NAVIGATING:
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
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var tween := _new_seat_tween()
	if seat_view:
		tween.tween_property(_camera, "global_transform", seat_view.global_transform, SEAT_TWEEN_TIME)
	tween.tween_callback(_on_seated)


func _on_seated() -> void:
	_seated = true
	_seat_look = Vector2.ZERO
	EventBus.navigation_mode_changed.emit(true)


func _exit_navigation() -> void:
	_seated = false
	_set_hovered_control(null)
	_pressed_control = null
	EventBus.interaction_prompt_changed.emit("")
	_current_prompt = ""
	mode = Mode.WALKING
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.navigation_mode_changed.emit(false)
	_new_seat_tween().tween_property(_camera, "transform", Transform3D.IDENTITY, SEAT_TWEEN_TIME)


## Olhar sentado: ângulos do mouse-look + balanço da manobra + tranco de golpe.
func _update_seat_look() -> void:
	var look := Vector3(_seat_look.y, _seat_look.x, 0.0) + _maneuver_tilt + _kick
	_camera.global_transform = seat_view.global_transform * Transform3D(Basis.from_euler(look), Vector3.ZERO)


## A câmera se move sem eventos de mouse (olhar, balanço): a cada frame a mira é
## relançada como movimento no centro da tela, mantendo o hover em dia. O prompt
## da HUD mostra a ação da tecla sob a mira.
func _update_panel_hover() -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _screen_center()
	motion.global_position = motion.position
	_forward_to_panel(motion)
	var prompt := ""
	if _hovered_control and _hovered_control.has_method(&"get_prompt"):
		prompt = _hovered_control.get_prompt()
	if prompt != _current_prompt:
		_current_prompt = prompt
		EventBus.interaction_prompt_changed.emit(prompt)


func _screen_center() -> Vector2:
	return get_viewport().get_visible_rect().size * 0.5


## Lança a mira como raio na camada do painel e repassa o evento ao controle
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


## Golpe forte no casco: tranco para trás com torção aleatória + tremor.
func _on_cabin_impact(strength: float) -> void:
	_shake_strength = maxf(_shake_strength, IMPACT_SHAKE * strength)
	_kick = Vector3(
		IMPACT_KICK.x * randf_range(0.7, 1.0),
		IMPACT_KICK.y * randf_range(-1.0, 1.0),
		IMPACT_KICK.z * randf_range(-1.0, 1.0)) * strength


func _update_shake(delta: float) -> void:
	_shake_strength = move_toward(_shake_strength, 0.0, delta * 0.15)
	_camera.h_offset = randf_range(-1.0, 1.0) * _shake_strength
	_camera.v_offset = randf_range(-1.0, 1.0) * _shake_strength


func _on_game_over(_won: bool) -> void:
	if _pressed_control:
		_pressed_control = null
	_set_hovered_control(null)
	mode = Mode.DISABLED
	_camera_rest = _camera.transform
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
