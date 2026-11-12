class_name PanelButton3D
extends Node3D
## Botão físico do painel: uma tecla 3D (ou knob redondo) com curso real ao ser
## pressionada, clique sonoro posicional e brilho de hover. Ao ser solta sobre
## ela mesma, emite a intenção correspondente no EventBus — como os botões 2D
## antigos, não conhece a Capsule nem o oxigênio.
## Mesma interface de entrada da PanelScreen (forward_mouse / release_hover):
## o Player lança o cursor como raio na PANEL_LAYER e repassa o evento.
## Geometria no espaço local: a face fica em z = 0 e a tecla cresce para +Z
## (em direção ao jogador); pressionar empurra a tecla para -Z.

enum Action { MOVE_FORWARD, MOVE_BACKWARD, ROTATE_LEFT, ROTATE_RIGHT, SONAR, TOGGLE_ALARM_MUTE }

const CLICK := preload("res://assets/audio/sfx/panel_click.wav")
const PRESS_TIME := 0.05
const RELEASE_TIME := 0.12
const HOVER_COLOR := Color(0.45, 0.95, 0.85)
const LIT_COLOR := Color(1.0, 0.55, 0.1)

@export var action := Action.MOVE_FORWARD
## Texto gravado na tecla (símbolo + legenda, pode ter quebra de linha).
@export_multiline var label_text := "▲\nFRENTE"
## Largura × altura × profundidade da tecla, em metros (knob: diâmetro × diâmetro × altura).
@export var cap_size := Vector3(0.1, 0.1, 0.03)
@export var round := false
@export var cap_color := Color(0.2, 0.21, 0.22)
@export var label_color := Color(0.85, 0.9, 0.88)
@export var label_font_size := 54
## Quanto a tecla afunda ao ser pressionada (m).
@export var travel := 0.014

var disabled := false

var _cap: Node3D
var _material: StandardMaterial3D
var _click: AudioStreamPlayer3D
var _hovered := false
var _pressed := false
## Indicador aceso (ex.: knob do alarme quando o som está silenciado).
var _lit := false
var _tween: Tween


func _ready() -> void:
	_build()
	EventBus.game_over.connect(func(_won: bool) -> void: _set_disabled(true))
	if action == Action.TOGGLE_ALARM_MUTE:
		EventBus.alarm_muted_changed.connect(func(muted: bool) -> void:
			_lit = muted
			_refresh_look())


func _build() -> void:
	_cap = Node3D.new()
	add_child(_cap)

	_material = StandardMaterial3D.new()
	_material.albedo_color = cap_color
	_material.roughness = 0.55
	_material.metallic = 0.2
	_material.emission_enabled = true
	_material.emission = Color.BLACK

	var mesh_instance := MeshInstance3D.new()
	if round:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = cap_size.x * 0.5
		cylinder.bottom_radius = cap_size.x * 0.5
		cylinder.height = cap_size.z
		cylinder.radial_segments = 24
		mesh_instance.mesh = cylinder
		mesh_instance.rotation_degrees.x = 90.0
	else:
		var box := BoxMesh.new()
		box.size = cap_size
		mesh_instance.mesh = box
	mesh_instance.position.z = cap_size.z * 0.5
	mesh_instance.material_override = _material
	_cap.add_child(mesh_instance)

	if label_text != "":
		var label := Label3D.new()
		label.text = label_text
		label.font_size = label_font_size
		label.pixel_size = 0.0004
		label.modulate = label_color
		label.outline_size = 0
		label.position.z = cap_size.z + 0.0008
		label.double_sided = false
		_cap.add_child(label)

	var area := Area3D.new()
	area.collision_layer = PanelScreen.PANEL_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = false
	area.input_ray_pickable = false
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = cap_size
	shape.shape = box_shape
	shape.position.z = cap_size.z * 0.5
	area.add_child(shape)
	add_child(area)

	_click = AudioStreamPlayer3D.new()
	_click.stream = CLICK
	_click.bus = &"SFX"
	_click.unit_size = 2.0
	_click.position.z = cap_size.z
	add_child(_click)


func forward_mouse(event: InputEventMouse, _world_position: Vector3) -> void:
	if disabled:
		return
	var button := event as InputEventMouseButton
	var is_left := button != null and button.button_index == MOUSE_BUTTON_LEFT
	# Soltar: o Player sempre entrega à tecla que foi pressionada, mesmo com o cursor
	# fora dela (aí release_hover já foi chamado). Só aciona se soltar em cima dela —
	# dá para "desistir" arrastando para fora. Por isso o hover não é ligado aqui.
	if is_left and not button.pressed:
		if _pressed:
			_pressed = false
			_animate_cap(0.0, RELEASE_TIME)
			if _hovered:
				_trigger()
		return
	if not _hovered:
		_hovered = true
		_refresh_look()
	if is_left and button.pressed and not _pressed:
		_pressed = true
		_animate_cap(-travel, PRESS_TIME)
		_click.pitch_scale = randf_range(0.95, 1.05)
		_click.play()


func release_hover() -> void:
	if _hovered:
		_hovered = false
		_refresh_look()


func _trigger() -> void:
	match action:
		Action.MOVE_FORWARD:
			EventBus.request_move_forward.emit()
		Action.MOVE_BACKWARD:
			EventBus.request_move_backward.emit()
		Action.ROTATE_LEFT:
			EventBus.request_rotate_left.emit()
		Action.ROTATE_RIGHT:
			EventBus.request_rotate_right.emit()
		Action.SONAR:
			EventBus.request_sonar_ping.emit()
		Action.TOGGLE_ALARM_MUTE:
			EventBus.request_toggle_alarm_mute.emit()


func _animate_cap(z: float, duration: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_cap, "position:z", z, duration)


func _set_disabled(value: bool) -> void:
	disabled = value
	_pressed = false
	_hovered = false
	_animate_cap(0.0, RELEASE_TIME)
	_refresh_look()


func _refresh_look() -> void:
	if disabled:
		_material.albedo_color = cap_color.darkened(0.5)
		_material.emission = Color.BLACK
	elif _lit:
		_material.albedo_color = cap_color
		_material.emission = LIT_COLOR
		_material.emission_energy_multiplier = 1.2
	elif _hovered:
		_material.albedo_color = cap_color
		_material.emission = HOVER_COLOR
		_material.emission_energy_multiplier = 0.35
	else:
		_material.albedo_color = cap_color
		_material.emission = Color.BLACK
