extends Node
## Autoload de áudio: escuta fatos do EventBus e toca o som correspondente.
## Nenhum sistema de gameplay toca som diretamente (exceção: o clique dos botões
## físicos do painel, que é feedback do próprio objeto 3D e fica nele).
## Buses (default_bus_layout.tres): Ambience, SFX, Alarm, Radio e Distant. O mudo
## do alarme (knob do painel → AlarmSystem → alarm_muted_changed) muta só o bus Alarm.
## O rádio (voz/estática) é tocado pelo RadioSystem; aqui só a mixagem reage a ele
## (o ambiente abaixa durante as falas).
## Persiste entre reinícios (é autoload): o ambiente não corta ao recarregar a cena.

## Cama de ambiente: as faixas se revezam com crossfade, começando a próxima em
## `loop_at` segundos. `ambience.mp3` tem fade-out próprio nos últimos ~10 s, então
## a troca começa antes dele (em laço simples, ficaria um buraco de silêncio).
const AMBIENCE_BED := [
	{"stream": preload("res://assets/audio/sfx/ambience.mp3"), "volume_db": -10.0, "loop_at": 36.0},
	{"stream": preload("res://assets/audio/sfx/ambience2.mp3"), "volume_db": -1.0, "loop_at": 46.0},
]
## Camada de tensão (ronco grave) que cresce com a proximidade do inimigo.
const TENSION_BED := [
	{"stream": preload("res://assets/audio/sfx/ambience3.mp3"), "volume_db": 3.0, "loop_at": 40.0},
]
## Mesma escala do mostrador INTERF.: cheio a 1 passo, zerado a partir de 9.
const TENSION_RANGE := 8.0
## Chamado distante da criatura quando ela ouve o sonar (bus Distant: abafado e com eco).
const DISTANT_CALL := preload("res://assets/audio/sfx/monster3.mp3")
const DISTANT_CALL_RANGE := 10
const DISTANT_CALL_COOLDOWN := 20.0
## Quanto o ambiente abaixa enquanto o comandante fala.
const RADIO_DUCK_DB := -6.0
## Derrota por contato: o ambiente morre junto com a cápsula (e volta no reinício).
const CAUGHT_SILENCE_DELAY := 2.0
const CAUGHT_SILENCE_FADE := 2.0
const CRASH := preload("res://assets/audio/sfx/crash.mp3")
const SONAR := preload("res://assets/audio/sfx/sonar.mp3")
const METAL := preload("res://assets/audio/sfx/metal.mp3")
const SIREN := preload("res://assets/audio/sfx/siren.mp3")
const O2_BEEP := preload("res://assets/audio/sfx/o2_beep.wav")
const ENEMY_ECHO := preload("res://assets/audio/sfx/monster.mp3")
const CAUGHT := preload("res://assets/audio/sfx/monster2.mp3")
const MOVE := preload("res://assets/audio/sfx/capsule_move.mp3")
const ROTATE: Array[AudioStream] = [
	preload("res://assets/audio/sfx/capsule_rotate_a.wav"),
	preload("res://assets/audio/sfx/capsule_rotate_b.wav"),
]
const MOVE_VOLUME_DB := -4.0

## A partir desta distância (em passos) o casco começa a ranger.
const CREAK_RANGE := 4

var _ambience_bed: CrossfadeLoop
var _tension_bed: CrossfadeLoop
var _tension_level := 0.0
var _tension_target := 0.0
var _distant_call: AudioStreamPlayer
var _last_distant_call := -INF
var _duck_tween: Tween
var _bed_tween: Tween
var _crush: AudioStreamPlayer
var _crash: AudioStreamPlayer
var _sonar: AudioStreamPlayer
var _creak: AudioStreamPlayer
var _echo: AudioStreamPlayer
var _caught: AudioStreamPlayer
var _move: AudioStreamPlayer
var _rotate: AudioStreamPlayer
var _move_fade: Tween
## Laços do alarme por causa: &"enemy" → sirene, &"low_oxygen" → bipe.
var _alarm_loops := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ambience_bed = CrossfadeLoop.new(AMBIENCE_BED, &"Ambience")
	add_child(_ambience_bed)
	_tension_bed = CrossfadeLoop.new(TENSION_BED, &"Ambience")
	_tension_bed.gain_db = -80.0
	add_child(_tension_bed)
	_distant_call = _make_player(DISTANT_CALL, &"Distant", -6.0)
	_crash = _make_player(CRASH, &"SFX", -2.0)
	_crush = _make_player(METAL, &"SFX", 0.0)
	_sonar = _make_player(SONAR, &"SFX", -4.0)
	_creak = _make_player(METAL, &"SFX", -14.0)
	_echo = _make_player(ENEMY_ECHO, &"SFX", -6.0)
	_caught = _make_player(CAUGHT, &"SFX", 0.0)
	_move = _make_player(MOVE, &"SFX", MOVE_VOLUME_DB)
	_rotate = _make_player(ROTATE[0], &"SFX", -3.0)
	_alarm_loops[&"enemy"] = _make_player(SIREN, &"Alarm", -12.0, true)
	_alarm_loops[&"low_oxygen"] = _make_player(O2_BEEP, &"Alarm", -10.0, true)

	EventBus.capsule_collided.connect(_on_capsule_collided)
	EventBus.maneuver_started.connect(_on_maneuver_started)
	EventBus.maneuver_finished.connect(_on_maneuver_finished)
	EventBus.enemy_detected.connect(func(_cell: Vector2i) -> void: _echo.play())
	EventBus.capsule_caught.connect(func(_cell: Vector2i) -> void: _caught.play())
	EventBus.enemy_proximity_changed.connect(_on_enemy_proximity_changed)
	EventBus.alarm_started.connect(_on_alarm_started)
	EventBus.alarm_stopped.connect(_on_alarm_stopped)
	EventBus.alarm_muted_changed.connect(_on_alarm_muted_changed)
	EventBus.enemy_heard_sonar.connect(_on_enemy_heard_sonar)
	EventBus.game_over.connect(_on_game_over)
	EventBus.request_restart.connect(_on_request_restart)
	EventBus.cabin_impact.connect(_on_cabin_impact)
	EventBus.radio_line_started.connect(func(_id: StringName, _text: String, _duration: float) -> void:
		_duck_ambience(RADIO_DUCK_DB, 0.3))
	EventBus.radio_line_finished.connect(func(_id: StringName) -> void: _duck_ambience(0.0, 1.0))


func _process(delta: float) -> void:
	_tension_level = lerpf(_tension_level, _tension_target, 1.0 - exp(-delta * 0.8))
	_tension_bed.gain_db = linear_to_db(maxf(_tension_level, 0.0001))


## Manobras: o som começa junto com a manobra (o resultado só vem no fim dela).
## Sonar: o ping sai agora; o mapa revela quando o "eco volta" (fim da manobra).
func _on_maneuver_started(kind: StringName, _duration: float) -> void:
	match kind:
		&"forward", &"backward":
			if _move_fade:
				_move_fade.kill()
			_move.volume_db = MOVE_VOLUME_DB
			_move.pitch_scale = 1.0 if kind == &"forward" else 0.9
			_move.play()
		&"rotate_left", &"rotate_right":
			_rotate.stream = ROTATE.pick_random()
			_rotate.pitch_scale = randf_range(0.9, 1.1)
			_rotate.play()
		&"sonar":
			_sonar.play()


## Deslocamento concluído: o motor some em fade (na colisão ele já foi cortado).
func _on_maneuver_finished(kind: StringName) -> void:
	if (kind == &"forward" or kind == &"backward") and _move.playing:
		_move_fade = create_tween()
		_move_fade.tween_property(_move, "volume_db", -40.0, 0.35)
		_move_fade.tween_callback(_move.stop)


## Impacto: corta o motor seco e toca a batida.
func _on_capsule_collided(_cell: Vector2i, _direction: Vector2i) -> void:
	if _move_fade:
		_move_fade.kill()
	_move.stop()
	_crash.play()


## Metal rangendo: mais alto quanto mais perto; não reinicia se ainda está tocando.
func _on_enemy_proximity_changed(steps: int) -> void:
	_tension_target = 0.0 if steps < 0 else clampf(1.0 - float(steps - 1) / TENSION_RANGE, 0.0, 1.0)
	if steps < 0 or steps > CREAK_RANGE or _creak.playing:
		return
	_creak.volume_db = -18.0 + float(CREAK_RANGE - steps) * 4.0
	_creak.play()


## A criatura ouviu o pulso: se estiver perto o bastante, um chamado distante
## responde depois de um instante (o som "viaja"). Feedback do risco do sonar.
func _on_enemy_heard_sonar(steps: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if steps < 0 or steps > DISTANT_CALL_RANGE or now - _last_distant_call < DISTANT_CALL_COOLDOWN:
		return
	_last_distant_call = now
	_distant_call.volume_db = -2.0 - float(steps) * 1.2
	_distant_call.pitch_scale = randf_range(0.8, 0.92)
	get_tree().create_timer(randf_range(1.2, 2.0)).timeout.connect(_distant_call.play)


func _on_game_over(_won: bool) -> void:
	_tension_target = 0.0
	if GameState.end_reason == GameState.EndReason.CAUGHT:
		_fade_bed(-60.0, CAUGHT_SILENCE_FADE, CAUGHT_SILENCE_DELAY)


func _on_request_restart() -> void:
	_fade_bed(0.0, 3.0)


## Golpe no casco: impacto seco + metal sendo esmagado, mais grave quanto mais forte.
func _on_cabin_impact(strength: float) -> void:
	_crash.volume_db = -2.0 + (strength - 1.0) * 8.0
	_crash.pitch_scale = randf_range(0.7, 0.85)
	_crash.play()
	_crush.volume_db = -1.0 + (strength - 1.0) * 6.0
	_crush.pitch_scale = randf_range(0.6, 0.75)
	_crush.play()


func _fade_bed(gain_db: float, time: float, delay := 0.0) -> void:
	if _bed_tween:
		_bed_tween.kill()
	_bed_tween = create_tween()
	_bed_tween.tween_interval(delay)
	_bed_tween.tween_property(_ambience_bed, "gain_db", gain_db, time)


func _duck_ambience(volume_db: float, time: float) -> void:
	if _duck_tween:
		_duck_tween.kill()
	var bus := AudioServer.get_bus_index(&"Ambience")
	_duck_tween = create_tween()
	_duck_tween.tween_method(func(db: float) -> void: AudioServer.set_bus_volume_db(bus, db),
		AudioServer.get_bus_volume_db(bus), volume_db, time)


func _on_alarm_started(reason: StringName) -> void:
	var player: AudioStreamPlayer = _alarm_loops.get(reason)
	if player and not player.playing:
		player.play()


func _on_alarm_stopped(reason: StringName) -> void:
	var player: AudioStreamPlayer = _alarm_loops.get(reason)
	if player:
		player.stop()


func _on_alarm_muted_changed(muted: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Alarm"), muted)


## Laços são feitos reiniciando no `finished` (funciona igual para MP3 e WAV,
## sem depender das opções de loop de importação de cada arquivo). `stop()` não
## emite `finished`, então um laço parado continua parado.
func _make_player(stream: AudioStream, bus: StringName, volume_db: float, loop := false) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	add_child(player)
	if loop:
		player.finished.connect(player.play)
	return player


## Laço com crossfade entre faixas (ou da faixa com ela mesma): a próxima começa
## em `loop_at` com fade-in de XFADE s enquanto a anterior some no mesmo tempo.
## Evita o clique da emenda e o silêncio de faixas com fade-out próprio.
## `gain_db` é somado a tudo (usado para a camada de tensão).
class CrossfadeLoop extends Node:
	const XFADE := 6.0

	var gain_db := 0.0

	var _tracks: Array
	var _players: Array[AudioStreamPlayer] = []
	var _track := 0
	var _active := 0
	var _elapsed := 0.0
	var _previous_elapsed := 0.0
	var _previous_db := 0.0

	func _init(tracks: Array, bus: StringName) -> void:
		_tracks = tracks
		for i in 2:
			var player := AudioStreamPlayer.new()
			player.bus = bus
			player.volume_db = -80.0
			_players.append(player)
			add_child(player)

	func _ready() -> void:
		_play_current()

	func _process(delta: float) -> void:
		_elapsed += delta
		var current := _players[_active]
		var fade_in := clampf(_elapsed / XFADE, 0.0, 1.0)
		current.volume_db = float(_tracks[_track].volume_db) + gain_db + linear_to_db(maxf(fade_in, 0.001))
		var previous := _players[1 - _active]
		if previous.playing:
			_previous_elapsed += delta
			var fade_out := 1.0 - _previous_elapsed / XFADE
			if fade_out <= 0.0:
				previous.stop()
			else:
				previous.volume_db = _previous_db + gain_db + linear_to_db(fade_out)
		if _elapsed >= float(_tracks[_track].loop_at):
			_previous_db = float(_tracks[_track].volume_db)
			_previous_elapsed = 0.0
			_active = 1 - _active
			_track = (_track + 1) % _tracks.size()
			_play_current()

	func _play_current() -> void:
		_elapsed = 0.0
		var player := _players[_active]
		player.stream = _tracks[_track].stream
		player.volume_db = -80.0
		player.play()
