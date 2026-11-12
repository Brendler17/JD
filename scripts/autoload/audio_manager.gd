extends Node
## Autoload de áudio: escuta fatos do EventBus e toca o som correspondente.
## Nenhum sistema de gameplay toca som diretamente (exceção: o clique dos botões
## físicos do painel, que é feedback do próprio objeto 3D e fica nele).
## Buses (default_bus_layout.tres): Ambience, SFX e Alarm. O mudo do alarme
## (knob do painel → AlarmSystem → alarm_muted_changed) muta só o bus Alarm.
## Persiste entre reinícios (é autoload): o ambiente não corta ao recarregar a cena.

const AMBIENCE := preload("res://assets/audio/sfx/ambience.mp3")
const CRASH := preload("res://assets/audio/sfx/crash.mp3")
const SONAR := preload("res://assets/audio/sfx/sonar.mp3")
const METAL := preload("res://assets/audio/sfx/metal.mp3")
const SIREN := preload("res://assets/audio/sfx/siren.mp3")
const O2_BEEP := preload("res://assets/audio/sfx/o2_beep.wav")
const ENEMY_ECHO := preload("res://assets/audio/sfx/monster.mp3")
const CAUGHT := preload("res://assets/audio/sfx/monster2.mp3")

## A partir desta distância (em passos) o casco começa a ranger.
const CREAK_RANGE := 4

var _ambience: AudioStreamPlayer
var _crash: AudioStreamPlayer
var _sonar: AudioStreamPlayer
var _creak: AudioStreamPlayer
var _echo: AudioStreamPlayer
var _caught: AudioStreamPlayer
## Laços do alarme por causa: &"enemy" → sirene, &"low_oxygen" → bipe.
var _alarm_loops := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ambience = _make_player(AMBIENCE, &"Ambience", -10.0, true)
	_crash = _make_player(CRASH, &"SFX", -2.0)
	_sonar = _make_player(SONAR, &"SFX", -4.0)
	_creak = _make_player(METAL, &"SFX", -14.0)
	_echo = _make_player(ENEMY_ECHO, &"SFX", -6.0)
	_caught = _make_player(CAUGHT, &"SFX", 0.0)
	_alarm_loops[&"enemy"] = _make_player(SIREN, &"Alarm", -12.0, true)
	_alarm_loops[&"low_oxygen"] = _make_player(O2_BEEP, &"Alarm", -10.0, true)
	_ambience.play()

	EventBus.capsule_collided.connect(func(_cell: Vector2i, _dir: Vector2i) -> void: _crash.play())
	EventBus.sonar_pinged.connect(func(_origin: Vector2i, _hits: Array[Vector2i]) -> void: _sonar.play())
	EventBus.enemy_detected.connect(func(_cell: Vector2i) -> void: _echo.play())
	EventBus.capsule_caught.connect(func(_cell: Vector2i) -> void: _caught.play())
	EventBus.enemy_proximity_changed.connect(_on_enemy_proximity_changed)
	EventBus.alarm_started.connect(_on_alarm_started)
	EventBus.alarm_stopped.connect(_on_alarm_stopped)
	EventBus.alarm_muted_changed.connect(_on_alarm_muted_changed)


## Metal rangendo: mais alto quanto mais perto; não reinicia se ainda está tocando.
func _on_enemy_proximity_changed(steps: int) -> void:
	if steps < 0 or steps > CREAK_RANGE or _creak.playing:
		return
	_creak.volume_db = -18.0 + float(CREAK_RANGE - steps) * 4.0
	_creak.play()


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
