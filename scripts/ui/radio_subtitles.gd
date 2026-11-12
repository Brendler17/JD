extends Control
## Legendas do rádio do comandante, na base da tela (acessibilidade e sala com
## som ruim, GDD §6.1). Fica fora da HUD de 1ª pessoa para aparecer em qualquer
## modo: andando, sentado no posto e sobre a tela de fim. "Dumb UI": só escuta
## radio_line_started/finished. O texto é revelado aos poucos, no ritmo da fala.

const SPEAKER := "SUPERFÍCIE"
## Fração da duração da fala usada para revelar o texto (o resto fica completo).
const REVEAL_FRACTION := 0.8
const HOLD_AFTER_END := 0.6
const FADE_TIME := 0.35

@onready var _box: Control = %Box
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _text_label: Label = %TextLabel

var _tween: Tween


func _ready() -> void:
	_box.modulate.a = 0.0
	_speaker_label.text = "◂ %s" % SPEAKER
	EventBus.radio_line_started.connect(_on_radio_line_started)
	EventBus.radio_line_finished.connect(_on_radio_line_finished)


func _on_radio_line_started(_id: StringName, subtitle: String, duration: float) -> void:
	_text_label.text = subtitle
	_text_label.visible_ratio = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_box, "modulate:a", 1.0, 0.15)
	_tween.parallel().tween_property(_text_label, "visible_ratio", 1.0, duration * REVEAL_FRACTION)


func _on_radio_line_finished(_id: StringName) -> void:
	if not is_inside_tree():
		return
	if _tween:
		_tween.kill()
	_text_label.visible_ratio = 1.0
	_tween = create_tween()
	_tween.tween_interval(HOLD_AFTER_END)
	_tween.tween_property(_box, "modulate:a", 0.0, FADE_TIME)
