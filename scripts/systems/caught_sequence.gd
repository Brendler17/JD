extends Node
## Sequência de "CONTATO" (derrota pela criatura): o ataque, depois o apagão.
## (Vitória e falta de oxigênio têm as próprias cenas, em EndingSequence.)
## Só apresentação; dispara em game_over quando GameState.end_reason == CAUGHT.
##   0,0 s  golpe forte (cabin_impact 1.0): tranco de câmera, impacto, rugido.
##   0–2,4 s luzes da cabine falham, telas e rótulos do painel piscam, luz de alarme estroboscópica.
##   1,1 s  segundo golpe (cabin_impact 0.6).
##   2,4 s  apagão: luzes e telas morrem, a luz ambiente cai quase a zero.
##          Uma luz ainda tenta voltar uma vez, fraca, e apaga.
## Depois disso o rádio fala no escuro (RadioSystem: `lost_caught` com delay) e a
## tela de fim espera o rádio terminar. O reinício recarrega a cena (tudo volta).
## Golpe NÃO letal (capsule_attacked, casco ainda de pé): versão curta —
## cabin_impact(HIT_IMPACT_STRENGTH) e ~HIT_TIME s de falha leve, depois tudo
## volta ao normal (a luz de alarme não é tocada).

const ATTACK_TIME := 2.4
const SECOND_IMPACT_TIME := 1.1
const SECOND_IMPACT_STRENGTH := 0.6
## Intervalo entre "falhas" das luzes/telas durante o ataque.
const FLICKER_INTERVAL := Vector2(0.04, 0.13)
const ALARM_STROBE_ENERGY := 5.0
const DARK_AMBIENT := 0.015
const LAST_FLICKER_DELAY := 0.9
const HIT_TIME := 1.0
const HIT_IMPACT_STRENGTH := 0.7
## Fração de luzes/telas apagadas em cada falha do golpe não letal.
const HIT_FAILING := 0.45

@export var cabin_lights: Node3D
@export var alarm_light: Light3D
@export var command_panel: Node3D
@export var world_environment: WorldEnvironment

var _time := -1.0
## Golpe não letal em andamento (senão, é a sequência de contato).
var _hit := false
var _flicker_timer := 0.0
var _second_impact_done := false
## Luzes, telas e rótulos da cabine (coletados no primeiro uso).
var _fx: CabinFx


func _ready() -> void:
	set_process(false)
	EventBus.game_over.connect(_on_game_over)
	EventBus.capsule_attacked.connect(_on_capsule_attacked)


func _on_capsule_attacked(_hull_left: int) -> void:
	_collect()
	EventBus.cabin_impact.emit(HIT_IMPACT_STRENGTH)
	_hit = true
	_time = 0.0
	_flicker_timer = 0.0
	set_process(true)


func _on_game_over(won: bool) -> void:
	if won or GameState.end_reason != GameState.EndReason.CAUGHT:
		return
	_collect()
	_hit = false
	if alarm_light:
		alarm_light.set_process(false)
	EventBus.cabin_impact.emit(1.0)
	_time = 0.0
	_flicker_timer = 0.0
	set_process(true)


func _collect() -> void:
	if _fx == null:
		_fx = CabinFx.collect(cabin_lights, alarm_light, command_panel)


func _process(delta: float) -> void:
	_time += delta
	if _hit:
		_process_hit(delta)
		return
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
	_fx.flicker(failing, Vector2(0.4, 1.7), Vector2(0.6, 1.5))


func _process_hit(delta: float) -> void:
	if _time >= HIT_TIME:
		_fx.restore()
		set_process(false)
		return
	_flicker_timer -= delta
	if _flicker_timer > 0.0:
		return
	_flicker_timer = randf_range(FLICKER_INTERVAL.x, FLICKER_INTERVAL.y)
	# A falha diminui conforme os sistemas se recuperam.
	var failing := HIT_FAILING * (1.0 - _time / HIT_TIME)
	_fx.flicker(failing, Vector2(0.6, 1.4), Vector2(0.7, 1.3), 0.1)


func _blackout() -> void:
	_fx.blackout()
	if alarm_light:
		alarm_light.light_energy = 0.0
	if world_environment and world_environment.environment:
		# Cópia: o Environment é sub-resource da cena em cache e a recarga
		# (reinício) o reaproveitaria já escuro.
		world_environment.environment = world_environment.environment.duplicate()
		create_tween().tween_property(world_environment.environment, "ambient_light_energy", DARK_AMBIENT, 0.5)
	# Um último suspiro: a luz de teto tenta voltar, fraca, e morre.
	if not _fx.lights.is_empty():
		var light := _fx.lights[0]
		var base: float = _fx.base_energy[light]
		var tween := create_tween()
		tween.tween_interval(LAST_FLICKER_DELAY)
		tween.tween_property(light, "light_energy", base * 0.35, 0.05)
		tween.tween_interval(0.08)
		tween.tween_property(light, "light_energy", 0.0, 0.04)
		tween.tween_interval(0.12)
		tween.tween_property(light, "light_energy", base * 0.2, 0.04)
		tween.tween_property(light, "light_energy", 0.0, 0.3)
