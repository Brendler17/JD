extends Node
## Autoload com as opções do jogador, salvas em user://settings.cfg (ConfigFile).
## Só guarda valores e avisa a mudança (EventBus.settings_changed). Quem aplica:
##   - volumes → AudioManager (único dono do AudioServer);
##   - sensibilidade → Player (lê `mouse_sensitivity` a cada movimento);
##   - legendas → RadioSubtitles;
##   - tela cheia → aqui mesmo (janela não é de nenhum sistema de jogo).
## Volumes em 0..1 (linear), convertidos para dB por quem aplica.

const PATH := "user://settings.cfg"
const SECTION := "opcoes"

const DEFAULTS := {
	"master_volume": 0.9,
	"voice_volume": 1.0,
	"effects_volume": 1.0,
	"ambience_volume": 1.0,
	## Multiplicador da sensibilidade base do Player (0,25 a 2,5).
	"mouse_sensitivity": 1.0,
	"subtitles": true,
	"fullscreen": false,
}

var master_volume: float = DEFAULTS.master_volume
var voice_volume: float = DEFAULTS.voice_volume
var effects_volume: float = DEFAULTS.effects_volume
var ambience_volume: float = DEFAULTS.ambience_volume
var mouse_sensitivity: float = DEFAULTS.mouse_sensitivity
var subtitles: bool = DEFAULTS.subtitles
var fullscreen: bool = DEFAULTS.fullscreen


func _ready() -> void:
	_load()
	_apply_window()


## Muda uma opção (nome da propriedade), aplica, salva e avisa.
func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key) or get(key) == value:
		return
	set(key, value)
	if key == "fullscreen":
		_apply_window()
	save()
	EventBus.settings_changed.emit()


func reset_to_defaults() -> void:
	for key: String in DEFAULTS:
		set(key, DEFAULTS[key])
	_apply_window()
	save()
	EventBus.settings_changed.emit()


func save() -> void:
	var config := ConfigFile.new()
	for key: String in DEFAULTS:
		config.set_value(SECTION, key, get(key))
	config.save(PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	for key: String in DEFAULTS:
		var value: Variant = config.get_value(SECTION, key, DEFAULTS[key])
		# Arquivo editado à mão ou de versão antiga: ignora tipo errado.
		if typeof(value) == typeof(DEFAULTS[key]) or (DEFAULTS[key] is float and value is int):
			set(key, value)


func _apply_window() -> void:
	# Em --headless não há janela.
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
