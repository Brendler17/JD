extends Control
## Menu de pausa da partida (Esc). Pausa a árvore e libera o cursor; ao continuar,
## recaptura o mouse (se a partida segue) e despausa.
## Botões: Continuar, Opções, Controles, Reiniciar partida, Menu principal, Sair.
## Reiniciar/Menu/Sair só emitem intenções (o SceneFlow troca a cena; a telemetria
## registra a partida como abandono). Roda com a árvore pausada (PROCESS_MODE_ALWAYS).
## Esc dentro de um submenu volta à lista; na lista, continua o jogo.
## Com o visualizador de notas aberto, o Esc é dele (ele consome o evento antes).

const OPTIONS_PANEL := preload("res://scenes/ui/options_panel.tscn")
const INFO_PANEL := preload("res://scenes/ui/info_panel.tscn")

var _list: VBoxContainer
var _options: OptionsPanel
var _info: InfoPanel
var _open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 10)
	_list.custom_minimum_size = Vector2(380, 0)
	center.add_child(_list)
	var title := Label.new()
	title.text = "PAUSA"
	title.add_theme_font_size_override(&"font_size", 44)
	title.add_theme_color_override(&"font_color", Color(1, 0.62, 0.28))
	_list.add_child(title)
	_add_button("Continuar", resume)
	_add_button("Opções", func() -> void: _show_sub(_options))
	_add_button("Controles", func() -> void:
		_info.show_info(InfoPanel.CONTROLS_TITLE, InfoPanel.CONTROLS_BODY)
		_show_sub(_info))
	_add_button("Reiniciar partida", EventBus.request_restart.emit)
	_add_button("Menu principal", EventBus.request_main_menu.emit)
	_add_button("Sair do jogo", EventBus.request_quit.emit)

	_options = OPTIONS_PANEL.instantiate()
	_options.closed.connect(_back_to_list)
	center.add_child(_options)
	_info = INFO_PANEL.instantiate()
	_info.closed.connect(_back_to_list)
	center.add_child(_info)
	_back_to_list()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	get_viewport().set_input_as_handled()
	if not _open:
		_pause()
	elif not _list.visible:
		_back_to_list()
	else:
		resume()


func _pause() -> void:
	# Durante a troca de cena (fade) a árvore já está pausada por outro motivo.
	if get_tree().paused:
		return
	_open = true
	_back_to_list()
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.game_paused.emit(true)


func resume() -> void:
	if not _open:
		return
	_open = false
	hide()
	get_tree().paused = false
	EventBus.game_paused.emit(false)
	# Fim de partida: o cursor fica livre para a tela de fim.
	if GameState.state == GameState.State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_sub(panel: Control) -> void:
	_list.hide()
	_options.hide()
	_info.hide()
	if panel == _options:
		_options.refresh()
	panel.show()


func _back_to_list() -> void:
	_options.hide()
	_info.hide()
	_list.show()


func _add_button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(action)
	_list.add_child(button)
