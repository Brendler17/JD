class_name OptionsPanel
extends PanelContainer
## Painel de opções, usado no menu principal e no menu de pausa.
## Monta as linhas em código a partir de ROWS: cada controle só chama
## Settings.set_value(); quem aplica cada opção é quem a usa (ver settings.gd).
## Emite `closed` no "Voltar" (ou Esc, tratado por quem abriu o painel).

signal closed

## { key, label, kind: "slider" | "toggle", min, max, step, format }
const ROWS := [
	{"key": "master_volume", "label": "Volume geral", "kind": "slider", "min": 0.0, "max": 1.0, "step": 0.05, "format": "percent"},
	{"key": "voice_volume", "label": "Voz do rádio", "kind": "slider", "min": 0.0, "max": 1.0, "step": 0.05, "format": "percent"},
	{"key": "effects_volume", "label": "Efeitos", "kind": "slider", "min": 0.0, "max": 1.0, "step": 0.05, "format": "percent"},
	{"key": "ambience_volume", "label": "Ambiente", "kind": "slider", "min": 0.0, "max": 1.0, "step": 0.05, "format": "percent"},
	{"key": "mouse_sensitivity", "label": "Sensibilidade do mouse", "kind": "slider", "min": 0.25, "max": 2.5, "step": 0.05, "format": "times"},
	{"key": "subtitles", "label": "Legendas do rádio", "kind": "toggle"},
	{"key": "fullscreen", "label": "Tela cheia", "kind": "toggle"},
]

## Controles por chave, para recarregar os valores (abrir de novo, restaurar padrão).
var _controls := {}
var _value_labels := {}
var _refreshing := false


func _ready() -> void:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 14)
	add_child(rows)

	var title := Label.new()
	title.text = "OPÇÕES"
	title.add_theme_font_size_override(&"font_size", 34)
	title.add_theme_color_override(&"font_color", Color(1, 0.62, 0.28))
	rows.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 24)
	grid.add_theme_constant_override(&"v_separation", 14)
	rows.add_child(grid)
	for row: Dictionary in ROWS:
		_add_row(grid, row)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 16)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	rows.add_child(buttons)
	var defaults := _make_button("Restaurar padrão")
	defaults.pressed.connect(func() -> void:
		Settings.reset_to_defaults()
		refresh())
	buttons.add_child(defaults)
	var back := _make_button("Voltar")
	back.pressed.connect(closed.emit)
	buttons.add_child(back)

	refresh()


## Lê os valores atuais do Settings para os controles.
func refresh() -> void:
	_refreshing = true
	for key: String in _controls:
		var control: Control = _controls[key]
		var value: Variant = Settings.get(key)
		if control is HSlider:
			(control as HSlider).value = value
			_update_value_label(key, value)
		elif control is CheckButton:
			(control as CheckButton).button_pressed = value
	_refreshing = false


func _add_row(grid: GridContainer, row: Dictionary) -> void:
	var key: String = row.key
	var label := Label.new()
	label.text = row.label
	grid.add_child(label)

	if row.kind == "slider":
		var slider := HSlider.new()
		slider.min_value = row.min
		slider.max_value = row.max
		slider.step = row.step
		slider.custom_minimum_size = Vector2(320, 28)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.focus_mode = Control.FOCUS_NONE
		slider.value_changed.connect(func(value: float) -> void:
			_update_value_label(key, value)
			if not _refreshing:
				Settings.set_value(key, value))
		grid.add_child(slider)
		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(80, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.set_meta(&"format", row.format)
		grid.add_child(value_label)
		_controls[key] = slider
		_value_labels[key] = value_label
	else:
		var toggle := CheckButton.new()
		toggle.focus_mode = Control.FOCUS_NONE
		toggle.toggled.connect(func(on: bool) -> void:
			if not _refreshing:
				Settings.set_value(key, on))
		grid.add_child(toggle)
		grid.add_child(Control.new())
		_controls[key] = toggle


func _update_value_label(key: String, value: float) -> void:
	var label: Label = _value_labels.get(key)
	if label == null:
		return
	if label.get_meta(&"format") == "percent":
		label.text = "%d%%" % roundi(value * 100.0)
	else:
		label.text = ("%.2f×" % value).replace(".", ",")


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override(&"font_size", 22)
	return button
