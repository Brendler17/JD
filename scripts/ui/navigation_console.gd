extends Control
## Interface de navegação na tela, inspirada no painel amarelo em frente à cadeira:
## oxigênio à esquerda, mapa (tela de sonar) no centro e teclado de comando à direita.
## Aparece quando o jogador senta no posto (navigation_mode_changed(true)) e some
## ao levantar (clique direito, tratado pelo jogador).
## Recebe a MazeGrid do LevelSetup e a repassa ao mapa.
## O medidor de interferência é o "sensor" diegético do inimigo: sobe conforme
## ele se aproxima (enemy_proximity_changed), sem nunca mostrar onde ele está.

const HEADING_NAMES := {
	Vector2i.UP: "N",
	Vector2i.RIGHT: "L",
	Vector2i.DOWN: "S",
	Vector2i.LEFT: "O",
}
const ALARM_TEXT := {
	&"enemy": "CONTATO PRÓXIMO",
	&"low_oxygen": "O₂ BAIXO",
}
## A partir desta distância (em passos) o medidor de interferência fica zerado.
const INTERFERENCE_RANGE := 8.0

var maze: MazeGrid:
	set(value):
		maze = value
		if is_node_ready():
			_map.maze = maze

@onready var _map: Control = %NavigationMap
@onready var _heading_label: Label = %HeadingLabel
@onready var _status_label: Label = %StatusLabel
@onready var _costs_label: Label = %CostsLabel
@onready var _alert_label: Label = %AlertLabel
@onready var _interference_bar: ProgressBar = %InterferenceBar

var _alarms := {}
var _time := 0.0


func _ready() -> void:
	hide()
	_map.maze = maze
	_costs_label.text = "CUSTO DE O₂\nMover  %d\nGirar  %d\nSonar  %d\nColisão  %d" % [
		GameState.OXYGEN_COST_MOVE, GameState.OXYGEN_COST_ROTATE,
		GameState.OXYGEN_COST_SONAR, GameState.OXYGEN_COST_COLLISION,
	]
	_set_heading(Vector2i.UP)
	_status_label.text = "Sistemas prontos.\nSaída marcada em verde."

	EventBus.navigation_mode_changed.connect(_on_navigation_mode_changed)
	EventBus.capsule_moved.connect(_on_capsule_moved)
	EventBus.capsule_rotated.connect(_on_capsule_rotated)
	EventBus.capsule_collided.connect(_on_capsule_collided)
	EventBus.sonar_pinged.connect(_on_sonar_pinged)
	EventBus.game_over.connect(_on_game_over)
	EventBus.enemy_detected.connect(_on_enemy_detected)
	EventBus.enemy_proximity_changed.connect(_on_enemy_proximity_changed)
	EventBus.alarm_started.connect(_on_alarm_changed.bind(true))
	EventBus.alarm_stopped.connect(_on_alarm_changed.bind(false))
	_alert_label.text = ""


func _process(delta: float) -> void:
	_time += delta
	_alert_label.modulate.a = 0.35 + 0.65 * absf(sin(_time * 5.0))


func _on_navigation_mode_changed(active: bool) -> void:
	visible = active


func _on_capsule_moved(new_position: Vector2i, _direction: Vector2i) -> void:
	if _is_over():
		return
	_status_label.text = "Deslocamento concluído.\nPosição %d, %d." % [new_position.x, new_position.y]


func _on_capsule_rotated(new_direction: Vector2i) -> void:
	if _is_over():
		return
	_set_heading(new_direction)
	_status_label.text = "Rumo ajustado."


func _on_capsule_collided(_blocked_cell: Vector2i, _direction: Vector2i) -> void:
	if _is_over():
		return
	_status_label.text = "IMPACTO NO CASCO!\nObstáculo registrado no mapa."


func _on_sonar_pinged(_origin: Vector2i, hits: Array[Vector2i]) -> void:
	if _is_over():
		return
	_status_label.text = "Pulso de sonar emitido.\n%d ecos registrados." % hits.size()


func _on_enemy_detected(_cell: Vector2i) -> void:
	_status_label.text = "ECO NÃO IDENTIFICADO!\nAlgo se moveu no feixe do sonar."


func _on_enemy_proximity_changed(steps: int) -> void:
	var level := 0.0 if steps < 0 else clampf(1.0 - float(steps - 1) / INTERFERENCE_RANGE, 0.0, 1.0)
	create_tween().tween_property(_interference_bar, "value", level * 100.0, 0.4)


func _on_alarm_changed(reason: StringName, active: bool) -> void:
	if active:
		_alarms[reason] = true
	else:
		_alarms.erase(reason)
	var texts: Array[String] = []
	for r: StringName in _alarms:
		texts.append(ALARM_TEXT.get(r, String(r)))
	_alert_label.text = "ALERTA: " + " · ".join(texts) if not texts.is_empty() else ""


func _on_game_over(won: bool) -> void:
	if won:
		_status_label.text = "Saída alcançada."
	elif GameState.end_reason == GameState.EndReason.CAUGHT:
		_status_label.text = "CONTATO COM O CASCO."
	else:
		_status_label.text = "Oxigênio esgotado."


## Depois do fim, a mensagem de fim fica na tela: a ação que encerrou a partida
## pode chegar aqui depois de game_over (ex.: o inimigo age no turno do giro).
func _is_over() -> bool:
	return GameState.state != GameState.State.PLAYING


func _set_heading(direction: Vector2i) -> void:
	_heading_label.text = "RUMO  %s" % HEADING_NAMES.get(direction, "?")
