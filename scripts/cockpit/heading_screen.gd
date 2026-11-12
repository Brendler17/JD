extends Control
## Tela de rumo (faixa superior da área central do painel amarelo): rumo atual,
## estado da manobra (PRONTO / AVANÇANDO… etc.), alerta piscando e a dica para levantar. As teclas de comando são físicas
## (PanelButton3D) logo abaixo dela. "Dumb UI": só reflete o EventBus.

const HEADING_NAMES := {
	Vector2i.UP: "N",
	Vector2i.RIGHT: "L",
	Vector2i.DOWN: "S",
	Vector2i.LEFT: "O",
}
const MANEUVER_TEXT := {
	&"forward": "▲ AVANÇANDO…",
	&"backward": "▼ RECUANDO…",
	&"rotate_left": "◀ GIRANDO…",
	&"rotate_right": "GIRANDO… ▶",
	&"sonar": "(( · )) AGUARDANDO ECO…",
}
const ALARM_TEXT := {
	&"enemy": "CONTATO PRÓXIMO",
	&"low_oxygen": "O₂ BAIXO",
}

@onready var _heading_label: Label = %HeadingLabel
@onready var _alert_label: Label = %AlertLabel
@onready var _maneuver_label: Label = %ManeuverLabel

var _alarms := {}
var _time := 0.0


func _ready() -> void:
	_set_heading(Vector2i.UP)
	_alert_label.text = ""
	_maneuver_label.text = "PRONTO"
	EventBus.capsule_rotated.connect(_set_heading)
	EventBus.maneuver_started.connect(func(kind: StringName, _duration: float) -> void:
		_maneuver_label.text = MANEUVER_TEXT.get(kind, "MANOBRANDO…"))
	EventBus.maneuver_finished.connect(func(_kind: StringName) -> void: _maneuver_label.text = "PRONTO")
	EventBus.alarm_started.connect(_on_alarm_changed.bind(true))
	EventBus.alarm_stopped.connect(_on_alarm_changed.bind(false))


func _process(delta: float) -> void:
	_time += delta
	_alert_label.modulate.a = 0.35 + 0.65 * absf(sin(_time * 5.0))
	_maneuver_label.modulate.a = 1.0 if _maneuver_label.text == "PRONTO" else 0.55 + 0.45 * absf(sin(_time * 8.0))


func _set_heading(direction: Vector2i) -> void:
	_heading_label.text = "RUMO  %s" % HEADING_NAMES.get(direction, "?")


func _on_alarm_changed(reason: StringName, active: bool) -> void:
	if active:
		_alarms[reason] = true
	else:
		_alarms.erase(reason)
	var texts: Array[String] = []
	for r: StringName in _alarms:
		texts.append(ALARM_TEXT.get(r, String(r)))
	_alert_label.text = " · ".join(texts)
