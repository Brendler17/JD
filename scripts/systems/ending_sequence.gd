extends Node
## Cenas de fim de partida para VITÓRIA e FALTA DE OXIGÊNIO (a derrota pela criatura
## é a CaughtSequence). Só apresentação: dispara em game_over e conversa com o
## resto por sinais (cabin_impact, camera_drift, cabin_rumble, ascent_*); mexe
## diretamente só na luz/telas da cabine (CabinFx), no ambiente e no próprio overlay.
## O tempo de cada cena acompanha a fala final do rádio (vitória: delay 1,2 s +
## 9,6 s; oxigênio: delay 2,0 s + 12,2 s). A tela de fim espera o rádio terminar.
##
## VITÓRIA — "Contato confirmado! Cabo travado... estamos trazendo vocês para cima."
##   0,0 s  o cabo engata: tranco leve, luzes oscilam com a energia nova.
##   2,4 s  "cabo travado": segundo tranco, a cabine inclina (puxada para cima),
##          começa a vibração da subida (ascent_started: ronco no AudioManager).
##   2,4 s→ luzes e telas esquentam devagar; o monitor registra a profundidade.
##   10,5 s clarão quente que cresce até a tela de fim.
##
## OXIGÊNIO — "Cápsula Dez? ... responda. ... sinal perdido. Preparem a Onze."
##   0–3 s  suporte de vida desliga: queda de energia, luzes e telas falhando fraco.
##   0→    a visão escurece pelas bordas e perde a cor, pulsando como batimento
##          (cada vez mais lento); a cabeça vai pendendo (camera_drift).
##   5–9 s  as telas morrem uma a uma; as luzes vão a zero até ~10 s.
##   12,5 s tudo preto; o fim da fala acontece no escuro.

const VISION_SHADER := preload("res://assets/shaders/vision_fade.gdshader")

# --- Vitória ---
const WIN_LATCH_STRENGTH := 0.45
const WIN_SURGE_TIME := 0.8
const WIN_PULL_TIME := 2.4
const WIN_PULL_STRENGTH := 0.55
## Inclinação da cabine sendo puxada (cabeça um pouco para trás, leve rolagem).
const WIN_PULL_TILT := Vector3(0.07, 0.0, 0.025)
const WIN_RUMBLE := 0.02
const WIN_LIGHT_GAIN := 1.8
const WIN_AMBIENT := 0.55
const WIN_WARM_TIME := 8.0
const WIN_START_DEPTH := 4000
## Registro da profundidade a cada tantos segundos, com subida acelerando.
const WIN_DEPTH_INTERVAL := 1.4
const WIN_FLASH_TIME := 10.5
const WIN_FLASH_COLOR := Color(1.0, 0.92, 0.78, 0.75)

# --- Oxigênio ---
const O2_BROWNOUT_TIME := 3.0
const O2_SCREEN_DEATH := Vector2(5.0, 9.0)
const O2_LIGHTS_OUT := 10.0
const O2_BLACK_TIME := 12.5
## Cabeça pendendo: primeiro um pouco, depois desabando para a frente e de lado.
const O2_FIRST_SLUMP := Vector3(-0.06, 0.0, 0.0)
const O2_FINAL_SLUMP := Vector3(-0.24, 0.05, 0.15)
const O2_HEARTBEAT := Vector2(0.9, 1.9)

@export var cabin_lights: Node3D
@export var alarm_light: Light3D
@export var command_panel: Node3D
@export var world_environment: WorldEnvironment

var _fx: CabinFx
var _won := false
var _time := 0.0
var _flicker_timer := 0.0
var _pull_done := false
var _depth := WIN_START_DEPTH
var _depth_timer := 0.0
var _depth_step := 10
var _flash_started := false
var _warmth := 1.0
## Oxigênio: momento em que cada tela morre (mesma ordem de _fx.screens).
var _screen_deaths: Array[float] = []
var _next_beat := 0.6
var _slumped := false

var _overlay_layer: CanvasLayer
var _vision: ColorRect
var _vision_material: ShaderMaterial
var _flash: ColorRect


func _ready() -> void:
	set_process(false)
	EventBus.game_over.connect(_on_game_over)


func _on_game_over(won: bool) -> void:
	if not won and GameState.end_reason != GameState.EndReason.OUT_OF_OXYGEN:
		return
	_won = won
	_fx = CabinFx.collect(cabin_lights, alarm_light, command_panel)
	_build_overlay()
	if alarm_light:
		alarm_light.set_process(false)
		alarm_light.light_energy = 0.0
	_time = 0.0
	if won:
		EventBus.cabin_impact.emit(WIN_LATCH_STRENGTH)
	else:
		for i in _fx.screens.size():
			_screen_deaths.append(randf_range(O2_SCREEN_DEATH.x, O2_SCREEN_DEATH.y))
		EventBus.camera_drift.emit(O2_FIRST_SLUMP, O2_BROWNOUT_TIME)
		_tween_vision(0.95, 0.45, O2_BROWNOUT_TIME)
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	if _won:
		_process_win(delta)
	else:
		_process_oxygen(delta)


# --- Vitória ---------------------------------------------------------------------

func _process_win(delta: float) -> void:
	if _time < WIN_SURGE_TIME:
		_flicker(delta, 0.35 * (1.0 - _time / WIN_SURGE_TIME), Vector2(0.7, 1.5), Vector2(0.8, 1.4))
		return
	if not _pull_done:
		_fx.restore()
		if _time >= WIN_PULL_TIME:
			_pull_done = true
			_start_ascent()
		return

	_fx.set_level(_warmth, lerpf(1.0, 1.3, (_warmth - 1.0) / (WIN_LIGHT_GAIN - 1.0)))
	_depth_timer -= delta
	if _depth_timer <= 0.0:
		_depth_timer = WIN_DEPTH_INTERVAL
		_depth -= _depth_step
		_depth_step = int(_depth_step * 1.6)
		EventBus.ascent_depth_changed.emit(_depth)
	if not _flash_started and _time >= WIN_FLASH_TIME:
		_flash_started = true
		_flash.show()
		create_tween().tween_property(_flash, "color", WIN_FLASH_COLOR, 2.5).set_ease(Tween.EASE_IN)


func _start_ascent() -> void:
	EventBus.cabin_impact.emit(WIN_PULL_STRENGTH)
	EventBus.camera_drift.emit(WIN_PULL_TILT, 2.5)
	EventBus.cabin_rumble.emit(WIN_RUMBLE, 2.0)
	EventBus.ascent_started.emit()
	_depth_timer = 1.0
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "_warmth", WIN_LIGHT_GAIN, WIN_WARM_TIME)
	var env := _own_environment()
	if env:
		tween.tween_property(env, "ambient_light_energy", WIN_AMBIENT, WIN_WARM_TIME)


# --- Oxigênio --------------------------------------------------------------------

func _process_oxygen(delta: float) -> void:
	# Batimento: o raio da visão encolhe por um instante; cada vez mais espaçado.
	if _time >= _next_beat and _time < O2_BLACK_TIME:
		var progress := clampf(_time / O2_BLACK_TIME, 0.0, 1.0)
		_next_beat = _time + lerpf(O2_HEARTBEAT.x, O2_HEARTBEAT.y, progress)
		var beat := create_tween()
		beat.tween_method(_set_pulse, 0.0, 0.12, 0.08)
		beat.tween_method(_set_pulse, 0.12, 0.0, 0.35)

	if _time < O2_BROWNOUT_TIME:
		# Queda de energia: falhas fracas e tudo um pouco mais escuro.
		var dim := lerpf(1.0, 0.6, _time / O2_BROWNOUT_TIME)
		_flicker(delta, 0.15, Vector2(0.7, 1.0), Vector2(0.6, 1.0), dim)
		return
	if not _slumped:
		_slumped = true
		EventBus.camera_drift.emit(O2_FINAL_SLUMP, O2_BLACK_TIME - O2_BROWNOUT_TIME)
		_tween_vision(0.0, 1.0, O2_BLACK_TIME - O2_BROWNOUT_TIME)

	# Luzes caem até zero; cada tela tem seu momento de morrer (com um último piscar).
	var light_level := clampf(1.0 - (_time - O2_BROWNOUT_TIME) / (O2_LIGHTS_OUT - O2_BROWNOUT_TIME), 0.0, 1.0) * 0.6
	for light in _fx.lights:
		light.light_energy = _fx.base_energy[light] * light_level * (0.85 if randf() < 0.04 else 1.0)
	_fx.set_glow(light_level)
	for i in _fx.screens.size():
		var left := _screen_deaths[i] - _time
		var screen := _fx.screens[i]
		if left <= 0.0:
			screen.power = 0.0
		elif left < 0.5:
			screen.power = 0.0 if randf() < 0.5 else 0.5
		else:
			screen.power = 0.6
	for label in _fx.labels:
		label.visible = _time < O2_SCREEN_DEATH.x
	if _time >= O2_BLACK_TIME:
		_fx.blackout()
		set_process(false)


# --- Utilitários -----------------------------------------------------------------

func _flicker(delta: float, failing: float, light_range: Vector2, screen_range: Vector2, scale := 1.0) -> void:
	_flicker_timer -= delta
	if _flicker_timer > 0.0:
		return
	_flicker_timer = randf_range(0.05, 0.14)
	_fx.flicker(failing, light_range, screen_range, 0.1, scale)


## Overlay de tela cheia abaixo da UI (layer 0 < UI): visão (shader) e clarão.
func _build_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 0
	add_child(_overlay_layer)
	_vision = ColorRect.new()
	_vision.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vision.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vision_material = ShaderMaterial.new()
	_vision_material.shader = VISION_SHADER
	# Valores iniciais explícitos (sem eles, get_shader_parameter devolve null).
	_vision_material.set_shader_parameter(&"radius", 1.5)
	_vision_material.set_shader_parameter(&"desaturation", 0.0)
	_vision_material.set_shader_parameter(&"pulse", 0.0)
	_vision.material = _vision_material
	_vision.visible = not _won
	_overlay_layer.add_child(_vision)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(WIN_FLASH_COLOR, 0.0)
	_flash.hide()
	_overlay_layer.add_child(_flash)


func _tween_vision(radius: float, desaturation: float, time: float) -> void:
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tween.tween_method(_set_vision.bind(&"radius"), _vision_param(&"radius"), radius, time)
	tween.tween_method(_set_vision.bind(&"desaturation"), _vision_param(&"desaturation"), desaturation, time)


func _set_vision(value: float, param: StringName) -> void:
	_vision_material.set_shader_parameter(param, value)


func _vision_param(param: StringName) -> float:
	return _vision_material.get_shader_parameter(param)


func _set_pulse(value: float) -> void:
	_vision_material.set_shader_parameter(&"pulse", value)


## Cópia do Environment antes de mexer (é sub-resource em cache: a recarga da
## cena o reaproveitaria alterado).
func _own_environment() -> Environment:
	if world_environment == null or world_environment.environment == null:
		return null
	world_environment.environment = world_environment.environment.duplicate()
	return world_environment.environment
