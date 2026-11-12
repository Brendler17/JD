extends Node
## Sequência de "CONTATO" (derrota pela criatura): o ataque, depois o apagão.
## Só apresentação; dispara em game_over quando GameState.end_reason == CAUGHT.
##   0,0 s  golpe forte (cabin_impact 1.0): tranco de câmera, impacto, rugido.
##   0–2,4 s luzes da cabine falham, telas e rótulos do painel piscam, luz de alarme estroboscópica.
##   1,1 s  segundo golpe (cabin_impact 0.6).
##   2,4 s  apagão: luzes e telas morrem, a luz ambiente cai quase a zero.
##          Uma luz ainda tenta voltar uma vez, fraca, e apaga.
## Depois disso o rádio fala no escuro (RadioSystem: `lost_caught` com delay) e a
## tela de fim espera o rádio terminar. O reinício recarrega a cena (tudo volta).

const ATTACK_TIME := 2.4
const SECOND_IMPACT_TIME := 1.1
const SECOND_IMPACT_STRENGTH := 0.6
## Intervalo entre "falhas" das luzes/telas durante o ataque.
const FLICKER_INTERVAL := Vector2(0.04, 0.13)
const ALARM_STROBE_ENERGY := 5.0
const DARK_AMBIENT := 0.015
const LAST_FLICKER_DELAY := 0.9

@export var cabin_lights: Node3D
@export var alarm_light: Light3D
@export var command_panel: Node3D
@export var world_environment: WorldEnvironment

var _time := -1.0
var _flicker_timer := 0.0
var _second_impact_done := false
var _lights: Array[Light3D] = []
var _base_energy := {}
var _screens: Array[PanelScreen] = []
## Rótulos 3D das teclas e do knob (sem sombreamento: brilhariam no escuro).
var _labels: Array[Label3D] = []


func _ready() -> void:
	set_process(false)
	EventBus.game_over.connect(_on_game_over)


func _on_game_over(won: bool) -> void:
	if won or GameState.end_reason != GameState.EndReason.CAUGHT:
		return
	for node in cabin_lights.get_children():
		if node is Light3D and node != alarm_light:
			_lights.append(node)
			_base_energy[node] = (node as Light3D).light_energy
	for node in command_panel.find_children("*", "", true, false):
		if node is PanelScreen:
			_screens.append(node)
		elif node is Label3D:
			_labels.append(node)
	if alarm_light:
		alarm_light.set_process(false)
	EventBus.cabin_impact.emit(1.0)
	_time = 0.0
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	if not _second_impact_done and _time >= SECOND_IMPACT_TIME:
		_second_impact_done = true
		EventBus.cabin_impact.emit(SECOND_IMPACT_STRENGTH)
	if _time >= ATTACK_TIME:
		_blackout()
		set_process(false)
		return

	if alarm_light:
		alarm_light.light_energy = ALARM_STROBE_ENERGY if fmod(_time, 0.16) < 0.06 else 0.2
	_flicker_timer -= delta
	if _flicker_timer > 0.0:
		return
	_flicker_timer = randf_range(FLICKER_INTERVAL.x, FLICKER_INTERVAL.y)
	# A falha piora ao longo do ataque: no fim, quase tudo fica apagado.
	var failing := 0.3 + 0.6 * (_time / ATTACK_TIME)
	for light in _lights:
		light.light_energy = 0.0 if randf() < failing else _base_energy[light] * randf_range(0.4, 1.7)
	for screen in _screens:
		screen.power = 0.05 if randf() < failing else randf_range(0.6, 1.5)
	for label in _labels:
		label.visible = randf() >= failing


func _blackout() -> void:
	for light in _lights:
		light.light_energy = 0.0
	for screen in _screens:
		screen.power = 0.0
	for label in _labels:
		label.visible = false
	if alarm_light:
		alarm_light.light_energy = 0.0
	if world_environment and world_environment.environment:
		# Cópia: o Environment é sub-resource da cena em cache e a recarga
		# (reinício) o reaproveitaria já escuro.
		world_environment.environment = world_environment.environment.duplicate()
		create_tween().tween_property(world_environment.environment, "ambient_light_energy", DARK_AMBIENT, 0.5)
	# Um último suspiro: a luz de teto tenta voltar, fraca, e morre.
	if not _lights.is_empty():
		var light := _lights[0]
		var tween := create_tween()
		tween.tween_interval(LAST_FLICKER_DELAY)
		tween.tween_property(light, "light_energy", _base_energy[light] * 0.35, 0.05)
		tween.tween_interval(0.08)
		tween.tween_property(light, "light_energy", 0.0, 0.04)
		tween.tween_interval(0.12)
		tween.tween_property(light, "light_energy", _base_energy[light] * 0.2, 0.04)
		tween.tween_property(light, "light_energy", 0.0, 0.3)
