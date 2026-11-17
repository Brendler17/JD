extends Control
## Monitor superior do posto de comando (tela vermelha da demo): só o registro
## de eventos da navegação (log rolando), em fonte grande para ler do assento.
## O₂, casco e custos ficam no monitor lateral (SystemsMonitor).
## Substitui o texto de status do antigo NavigationConsole 2D. "Dumb UI".

## Quantas linhas do registro ficam visíveis.
const MAX_LOG_LINES := 10

@onready var _log_label: Label = %LogLabel

var _lines: Array[String] = []
var _step := 0


func _ready() -> void:
	_log("SISTEMAS PRONTOS.")
	_log("SAÍDA MARCADA EM VERDE NO SONAR.")

	EventBus.capsule_attacked.connect(_on_capsule_attacked)
	EventBus.capsule_moved.connect(_on_capsule_moved)
	EventBus.capsule_rotated.connect(_on_capsule_rotated)
	EventBus.capsule_collided.connect(_on_capsule_collided)
	EventBus.sonar_pinged.connect(_on_sonar_pinged)
	EventBus.enemy_detected.connect(_on_enemy_detected)
	EventBus.alarm_started.connect(_on_alarm_started)
	EventBus.game_over.connect(_on_game_over)
	EventBus.ascent_started.connect(func() -> void: _log("CABO DE RESGATE TRAVADO — SUBIDA INICIADA"))
	EventBus.ascent_depth_changed.connect(func(depth_m: int) -> void:
		_log("SUBINDO — PROFUNDIDADE %s m" % _thousands(depth_m)))
	EventBus.alarm_muted_changed.connect(func(muted: bool) -> void:
		_log("ALARME SILENCIADO (LUZ MANTIDA)." if muted else "ALARME REARMADO."))
	EventBus.radio_line_started.connect(func(_id: StringName, _text: String, _duration: float) -> void:
		_log(">> TRANSMISSÃO RECEBIDA — SUPERFÍCIE"))


func _on_capsule_attacked(hull_left: int) -> void:
	_log("!! GOLPE NO CASCO — INTEGRIDADE %d/%d" % [hull_left, GameState.MAX_HULL])


func _on_capsule_moved(new_position: Vector2i, _direction: Vector2i) -> void:
	if not _is_over():
		_log("DESLOCAMENTO OK — POS %02d,%02d" % [new_position.x, new_position.y])


func _on_capsule_rotated(_new_direction: Vector2i) -> void:
	if not _is_over():
		_log("RUMO AJUSTADO.")


func _on_capsule_collided(_blocked_cell: Vector2i, _direction: Vector2i) -> void:
	if not _is_over():
		_log("!! IMPACTO NO CASCO — OBSTÁCULO REGISTRADO")


func _on_sonar_pinged(_origin: Vector2i, hits: Array[Vector2i]) -> void:
	if not _is_over():
		_log("PULSO DE SONAR — %d ECOS" % hits.size())


func _on_enemy_detected(_cell: Vector2i) -> void:
	_log("!! ECO NÃO IDENTIFICADO NO RAIO DO SONAR")


func _on_alarm_started(reason: StringName) -> void:
	if reason == &"low_oxygen":
		_log("!! RESERVA DE O₂ CRÍTICA")
	elif reason == &"enemy":
		_log("!! INTERFERÊNCIA ELEVADA")


func _on_game_over(won: bool) -> void:
	if won:
		_log("SAÍDA ALCANÇADA.")
	elif GameState.end_reason == GameState.EndReason.CAUGHT:
		_log("!! CASCO ROMPIDO")
	else:
		_log("!! OXIGÊNIO ESGOTADO")
		_log("!! SUPORTE DE VIDA DESLIGADO")


## Depois do fim, a ação que encerrou a partida pode chegar depois de game_over.
func _is_over() -> bool:
	return GameState.state != GameState.State.PLAYING


func _log(text: String) -> void:
	_step += 1
	_lines.append("%03d  %s" % [_step, text])
	while _lines.size() > MAX_LOG_LINES:
		_lines.pop_front()
	_log_label.text = "\n".join(_lines)


## 4000 → "4.000" (separador de milhar em pt-BR).
func _thousands(value: int) -> String:
	var text := str(value)
	return text if text.length() <= 3 else "%s.%s" % [text.substr(0, text.length() - 3), text.substr(text.length() - 3)]
