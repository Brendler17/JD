extends Control
## Menu principal (cena inicial do jogo). Novo jogo, Opções, Controles, Créditos, Sair.
## Botões só emitem intenções do EventBus (o SceneFlow troca a cena).
## Fundo: tela de sonar desenhada em _draw() no nó `Backdrop` — grade escura e um
## pulso que se expande a cada PING_INTERVAL segundos, com o som do sonar baixinho
## (coerente com um jogo guiado por som). A cama de ambiente vem do AudioManager.
## Esc fecha o painel aberto (opções/controles/créditos).

const OPTIONS_PANEL := preload("res://scenes/ui/options_panel.tscn")
const INFO_PANEL := preload("res://scenes/ui/info_panel.tscn")
const PING_SOUND := preload("res://assets/audio/sfx/sonar.mp3")
const CLICK_SOUND := preload("res://assets/audio/sfx/panel_click.wav")

const PING_INTERVAL := 5.5
## Duração da expansão do pulso, em segundos.
const PING_TRAVEL := 3.2
const RING_COLOR := Color(0.25, 0.85, 0.75)
const GRID_COLOR := Color(0.1, 0.3, 0.28, 0.25)
## Ecos fixos (posição relativa ao centro do sonar, em fração do raio): "algo" lá fora.
const ECHOES := [Vector2(0.42, -0.18), Vector2(-0.3, 0.36), Vector2(0.12, 0.55)]

@onready var _backdrop: Control = %Backdrop
@onready var _buttons: VBoxContainer = %Buttons
@onready var _version_label: Label = %VersionLabel
@onready var _panel_holder: CenterContainer = %PanelHolder

var _options: OptionsPanel
var _info: InfoPanel
var _ping_time := 1.5
var _ping_player: AudioStreamPlayer
var _click_player: AudioStreamPlayer


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_ping_player = _make_player(PING_SOUND, -20.0)
	_click_player = _make_player(CLICK_SOUND, -6.0)
	_backdrop.draw.connect(_draw_backdrop)

	_add_button("Novo jogo", EventBus.request_new_game.emit)
	_add_button("Opções", func() -> void: _show_panel(_options))
	_add_button("Controles", func() -> void:
		_info.show_info(InfoPanel.CONTROLS_TITLE, InfoPanel.CONTROLS_BODY)
		_show_panel(_info))
	_add_button("Créditos", func() -> void:
		_info.show_info(InfoPanel.CREDITS_TITLE, InfoPanel.CREDITS_BODY)
		_show_panel(_info))
	# Sair não existe no navegador (export web).
	if not OS.has_feature("web"):
		_add_button("Sair", EventBus.request_quit.emit)

	_options = OPTIONS_PANEL.instantiate()
	_options.closed.connect(_close_panels)
	_panel_holder.add_child(_options)
	_info = INFO_PANEL.instantiate()
	_info.closed.connect(_close_panels)
	_panel_holder.add_child(_info)
	_close_panels()

	var version: String = ProjectSettings.get_setting("application/config/version", "")
	_version_label.text = "protótipo%s  ·  use fones de ouvido" % ("" if version == "" else " v" + version)


func _process(delta: float) -> void:
	_ping_time += delta
	if _ping_time >= PING_INTERVAL:
		_ping_time = 0.0
		_ping_player.pitch_scale = randf_range(0.95, 1.05)
		_ping_player.play()
	_backdrop.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and _panel_holder.visible:
		get_viewport().set_input_as_handled()
		_close_panels()


func _show_panel(panel: Control) -> void:
	_options.hide()
	_info.hide()
	if panel == _options:
		_options.refresh()
	panel.show()
	_panel_holder.show()
	_buttons.hide()


func _close_panels() -> void:
	_panel_holder.hide()
	_options.hide()
	_info.hide()
	_buttons.show()


func _add_button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(func() -> void:
		_click_player.play()
		action.call())
	_buttons.add_child(button)


func _make_player(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	player.volume_db = volume_db
	add_child(player)
	return player


## Sonar ocupando a metade direita da tela: grade, anéis fixos, pulso e ecos que
## acendem quando o pulso passa por eles e somem devagar.
func _draw_backdrop() -> void:
	var size := _backdrop.size
	_backdrop.draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.025, 0.03))
	var center := Vector2(size.x * 0.68, size.y * 0.52)
	var radius := size.y * 0.62
	var step := radius / 8.0
	for i in range(-12, 13):
		_backdrop.draw_line(center + Vector2(i * step, -size.y), center + Vector2(i * step, size.y), GRID_COLOR, 1.0)
		_backdrop.draw_line(center + Vector2(-size.x, i * step), center + Vector2(size.x, i * step), GRID_COLOR, 1.0)
	for i in range(1, 5):
		_backdrop.draw_arc(center, radius * i / 4.0, 0.0, TAU, 96, Color(RING_COLOR, 0.08), 1.5)

	var t := _ping_time / PING_TRAVEL
	if t < 1.0:
		var ring := Color(RING_COLOR, 0.55 * (1.0 - t))
		_backdrop.draw_arc(center, radius * t, 0.0, TAU, 128, ring, 3.0)
	for echo: Vector2 in ECHOES:
		var hit_t := echo.length()
		var since := _ping_time - hit_t * PING_TRAVEL
		if since >= 0.0:
			var glow := clampf(1.0 - since / 2.5, 0.0, 1.0)
			_backdrop.draw_circle(center + echo * radius, 5.0, Color(1.0, 0.25, 0.2, 0.8 * glow))
	_backdrop.draw_circle(center, 4.0, Color(RING_COLOR, 0.6))
