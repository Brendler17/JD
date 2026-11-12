extends Node
## Rádio do comandante ("Superfície"): decide QUANDO cada fala toca e é o próprio
## aparelho de rádio (voz, estática e chiado de transmissão no bus Radio).
## Roteiro, gatilhos e tons em docs/roteiro-radio.md; GDD §6.1–6.2; TDD §10.
##
## Regras:
## - Cada fala toca no máximo uma vez por partida. O nó vive na cena principal,
##   então o reinício (recarga da cena) zera tudo.
## - Uma fala por vez. Novas falas vão para uma fila curta. URGENT corta uma fala
##   NORMAL no meio (o comandante se interrompe) e toca em seguida; a fala cortada
##   volta a valer como não tocada. Falas que esperam mais que `max_wait` (tempo de
##   jogo) são descartadas sem contar como tocadas.
## - Falas FINAL (vitória/derrota) cortam a atual, limpam a fila e tocam após `delay`.
## - Interferência: estática, quedas de sinal e distorção sobem com a proximidade
##   do inimigo (mesma escala do mostrador INTERF.). Com o inimigo perto, a estática
##   soa mesmo sem fala: o rádio vira um sensor de proximidade (GDD §6.2).
##   Durante a fala `first_enemy` a interferência sobe até engolir o fim da frase.
## Publica radio_line_started/finished (legendas, ducking do ambiente) e
## radio_busy_changed (a tela de fim espera o rádio terminar).

const STREAM_PATH := "res://assets/audio/radio/radio_%s.%s"
const STREAM_EXTENSIONS: Array[String] = ["wav", "ogg", "mp3"]
const STATIC := preload("res://assets/audio/sfx/radio_static.wav")
const SQUELCH_OPEN := preload("res://assets/audio/sfx/radio_squelch_open.wav")
const SQUELCH_CLOSE := preload("res://assets/audio/sfx/radio_squelch_close.wav")
const BUS := &"Radio"

const INTRO_DELAY := 3.0
## Segundos depois da introdução sem sentar no posto até a cobrança.
const IDLE_SEAT_DELAY := 30.0
const STATION_MANEUVERS := 20
const NEAR_EXIT_STEPS := 3
const MAX_QUEUE := 3
## Pausa entre uma fala e a próxima da fila.
const GAP_BETWEEN_LINES := 0.8
## Pausa depois de um corte por fala URGENT (só o chiado de fechar).
const GAP_AFTER_INTERRUPT := 0.35
## Duração estimada (sem áudio): por caractere da legenda, com um mínimo.
const SECONDS_PER_CHAR := 0.065
const MIN_SUBTITLE_TIME := 2.5
## Distância (passos) em que a interferência zera; igual ao mostrador INTERF.
const INTERFERENCE_RANGE := 8.0

const VOICE_DB := 0.0
const SQUELCH_DB := -10.0
## Estática (amplitude linear): fundo durante a fala + parcela da interferência.
const STATIC_SPEECH_LEVEL := 0.1
const STATIC_INTERFERENCE_LEVEL := 0.6
const STATIC_DB_OFFSET := -8.0
const DISTORTION_BASE := 0.25
const DISTORTION_MAX_EXTRA := 0.45

@export var lines: Array[RadioLine] = []

## Injetado pelo LevelSetup (distância até a saída para a fala `near_exit`).
var maze: MazeGrid

var _lines_by_id := {}
var _played := {}
## Entradas { "line": RadioLine, "time": float } (time = quando foi pedida).
var _queue: Array[Dictionary] = []
var _current: RadioLine
var _line_left := 0.0
var _gap := 0.0
var _final_pending := false
var _busy := false
## Tempo de jogo acumulado (validade da fila).
var _clock := 0.0

var _seated_once := false
var _maneuvers := 0
var _exit_distances := {}

## Interferência 0..1: proximidade do inimigo e "override" roteirizado (first_enemy).
var _proximity := 0.0
var _override := 0.0
var _override_tween: Tween
var _interference := 0.0
var _dropout := 1.0
var _dropout_target := 1.0
var _dropout_timer := 0.0

var _voice: AudioStreamPlayer
var _static: AudioStreamPlayer
var _squelch: AudioStreamPlayer
var _distortion: AudioEffectDistortion


func _ready() -> void:
	for line in lines:
		_lines_by_id[line.id] = line
	if maze:
		_exit_distances = maze.get_distances_from(maze.exit_cell)

	_voice = _make_player(VOICE_DB)
	_squelch = _make_player(SQUELCH_DB)
	_static = _make_player(-80.0)
	_static.stream = STATIC
	_static.finished.connect(_static.play)
	_static.play()
	var bus := AudioServer.get_bus_index(BUS)
	for i in AudioServer.get_bus_effect_count(bus):
		var effect := AudioServer.get_bus_effect(bus, i)
		if effect is AudioEffectDistortion:
			_distortion = effect

	EventBus.navigation_mode_changed.connect(_on_navigation_mode_changed)
	EventBus.capsule_collided.connect(func(_c: Vector2i, _d: Vector2i) -> void: trigger(&"first_collision"))
	EventBus.sonar_pinged.connect(func(_o: Vector2i, _h: Array[Vector2i]) -> void: trigger(&"first_sonar"))
	EventBus.enemy_detected.connect(func(_c: Vector2i) -> void: trigger(&"first_enemy"))
	EventBus.alarm_started.connect(_on_alarm_started)
	EventBus.maneuver_finished.connect(_on_maneuver_finished)
	EventBus.capsule_moved.connect(_on_capsule_moved)
	EventBus.enemy_proximity_changed.connect(_on_enemy_proximity_changed)
	EventBus.game_over.connect(_on_game_over)

	get_tree().create_timer(INTRO_DELAY).timeout.connect(trigger.bind(&"intro"))


## Recarga da cena com fala no ar: avisa o fim para quem escuta (ducking, legenda).
func _exit_tree() -> void:
	if _current:
		EventBus.radio_line_finished.emit(_current.id)
		_current = null
	if _busy:
		_busy = false
		EventBus.radio_busy_changed.emit(false)


# --- Gatilhos ---------------------------------------------------------------

## Pede uma fala. Ignorada se já tocou nesta partida, se já está na fila ou
## (exceto FINAL) se a partida acabou.
func trigger(id: StringName) -> void:
	var line: RadioLine = _lines_by_id.get(id)
	if line == null or _played.has(id) or _is_queued(id) or _current == line:
		return
	if line.priority == RadioLine.Priority.FINAL:
		_play_final(line)
		return
	if GameState.state != GameState.State.PLAYING:
		return
	var entry := {"line": line, "time": _now()}
	if line.priority == RadioLine.Priority.URGENT:
		_queue.push_front(entry)
		if _current and _current.priority == RadioLine.Priority.NORMAL:
			_interrupt_current()
	else:
		_queue.push_back(entry)
	while _queue.size() > MAX_QUEUE:
		_queue.pop_back()
	_update_busy()
	_try_next()


func _on_navigation_mode_changed(active: bool) -> void:
	if active:
		_seated_once = true
		trigger(&"first_seat")


func _on_idle_seat_timeout() -> void:
	if not _seated_once:
		trigger(&"idle_seat")


## Primeiro alarme: a causa tem a fala dela antes da dica de silenciar.
func _on_alarm_started(reason: StringName) -> void:
	match reason:
		&"enemy":
			trigger(&"first_enemy")
		&"low_oxygen":
			trigger(&"low_oxygen")
	trigger(&"first_alarm")


func _on_maneuver_finished(_kind: StringName) -> void:
	_maneuvers += 1
	if _maneuvers == STATION_MANEUVERS:
		trigger(&"station")


func _on_capsule_moved(new_position: Vector2i, _direction: Vector2i) -> void:
	var steps: int = _exit_distances.get(new_position, -1)
	if steps > 0 and steps <= NEAR_EXIT_STEPS:
		trigger(&"near_exit")


func _on_enemy_proximity_changed(steps: int) -> void:
	_proximity = 0.0 if steps < 0 else clampf(1.0 - float(steps - 1) / INTERFERENCE_RANGE, 0.0, 1.0)


## O inimigo para de emitir proximidade no fim; a fala final define o nível.
func _on_game_over(won: bool) -> void:
	if won:
		_proximity = 0.0
		trigger(&"win")
	elif GameState.end_reason == GameState.EndReason.CAUGHT:
		_proximity = 0.35
		trigger(&"lost_caught")
	else:
		_proximity = 0.0
		trigger(&"lost_oxygen")


# --- Fila e reprodução --------------------------------------------------------

func _try_next() -> void:
	if _current or _final_pending or _gap > 0.0:
		return
	while not _queue.is_empty():
		var entry: Dictionary = _queue.pop_front()
		var line: RadioLine = entry.line
		if _now() - float(entry.time) > line.max_wait:
			continue
		if line.id == &"idle_seat" and _seated_once:
			continue
		_start(line)
		return
	_update_busy()


func _play_final(line: RadioLine) -> void:
	_queue.clear()
	if _current:
		_voice.stop()
		_end_current()
	_final_pending = true
	_update_busy()
	get_tree().create_timer(line.delay).timeout.connect(func() -> void:
		_final_pending = false
		_start(line))


## Corta a fala atual (o comandante se interrompe); ela pode tocar de novo depois.
func _interrupt_current() -> void:
	_voice.stop()
	_played.erase(_current.id)
	_squelch.stream = SQUELCH_CLOSE
	_squelch.play()
	_end_current()
	_gap = GAP_AFTER_INTERRUPT


func _start(line: RadioLine) -> void:
	_current = line
	_played[line.id] = true
	var stream := _load_stream(line.id)
	var duration := stream.get_length() if stream else maxf(MIN_SUBTITLE_TIME, line.subtitle.length() * SECONDS_PER_CHAR)
	_line_left = duration
	_squelch.stream = SQUELCH_OPEN
	_squelch.play()
	_voice.stream = stream
	if stream:
		_voice.play()
	if line.id == &"first_enemy":
		_ramp_override(1.0, duration * 0.9, Tween.EASE_IN)
	_update_busy()
	EventBus.radio_line_started.emit(line.id, line.subtitle, duration)


func _finish_current() -> void:
	_squelch.stream = SQUELCH_CLOSE
	_squelch.play()
	var finished_id := _current.id
	_end_current()
	if finished_id == &"intro":
		get_tree().create_timer(IDLE_SEAT_DELAY).timeout.connect(_on_idle_seat_timeout)
	_gap = GAP_BETWEEN_LINES
	_update_busy()


func _end_current() -> void:
	var id := _current.id
	_current = null
	if id == &"first_enemy":
		_ramp_override(0.0, 2.5, Tween.EASE_OUT)
	EventBus.radio_line_finished.emit(id)


func _process(delta: float) -> void:
	_clock += delta
	if _current:
		_line_left -= delta
		if _line_left <= 0.0:
			_finish_current()
	elif _gap > 0.0:
		_gap -= delta
		if _gap <= 0.0:
			_try_next()
	_update_interference(delta)


## Estática, quedas de sinal na voz e distorção do bus, todas pela interferência.
func _update_interference(delta: float) -> void:
	var target := maxf(_proximity, _override)
	_interference = lerpf(_interference, target, 1.0 - exp(-delta * 3.0))

	var static_level := _interference * STATIC_INTERFERENCE_LEVEL
	if _current:
		static_level += STATIC_SPEECH_LEVEL
	_static.volume_db = linear_to_db(maxf(static_level, 0.0001)) + STATIC_DB_OFFSET

	_dropout_timer -= delta
	if _dropout_timer <= 0.0:
		_dropout_timer = randf_range(0.04, 0.25)
		var drops := randf() < _interference * 0.6
		_dropout_target = 1.0 - (randf_range(0.5, 1.0) * _interference if drops else 0.0)
	_dropout = lerpf(_dropout, _dropout_target, 1.0 - exp(-delta * 30.0))
	_voice.volume_db = VOICE_DB + linear_to_db(maxf(_dropout, 0.02))

	if _distortion:
		_distortion.drive = DISTORTION_BASE + _interference * DISTORTION_MAX_EXTRA


func _ramp_override(to: float, duration: float, easing: Tween.EaseType) -> void:
	if _override_tween:
		_override_tween.kill()
	_override_tween = create_tween()
	_override_tween.tween_property(self, "_override", to, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(easing)


# --- Utilitários ----------------------------------------------------------------

func _update_busy() -> void:
	var busy := _current != null or _final_pending or not _queue.is_empty()
	if busy != _busy:
		_busy = busy
		EventBus.radio_busy_changed.emit(busy)


func _is_queued(id: StringName) -> bool:
	for entry in _queue:
		if (entry.line as RadioLine).id == id:
			return true
	return false


func _load_stream(id: StringName) -> AudioStream:
	for extension in STREAM_EXTENSIONS:
		var path := STREAM_PATH % [id, extension]
		if ResourceLoader.exists(path):
			return load(path)
	return null


func _now() -> float:
	return _clock


func _make_player(volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = BUS
	player.volume_db = volume_db
	add_child(player)
	return player
