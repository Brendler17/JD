extends Node
## Telemetria de playtest: registra cada partida em CSV para avaliar o
## balanceamento com números em vez de memória (GDD §4.6.1).
##
## Gera dois arquivos (separador ";" e vírgula decimal, para abrir direto no
## LibreOffice/Excel em pt-BR):
##   runs.csv                    → uma linha por partida (resumo).
##   run_<data>_<hora>.csv       → passo a passo da partida: cada ação, o que a
##                                 criatura fez em resposta, O₂, casco, distâncias.
## Pasta: `telemetry/` na raiz do projeto quando roda pelo editor (tem .gdignore,
## então o Godot não tenta importar os CSVs, e está no .gitignore); `user://telemetry/`
## num build exportado. O caminho completo sai no console ao iniciar.
## Resumo e análise: `python3 tools/telemetry_report.py`.
##
## Só observa: escuta o EventBus e LÊ o estado da criatura (nó `enemy`), nunca
## escreve em nada. Recebe a MazeGrid do LevelSetup, como os outros consumidores.
## Partida encerrada sem fim de jogo (fechar a janela) entra como ABANDONO.
## Desligada em --headless (testes automáticos).

const EDITOR_DIR := "res://telemetry"
const BUILD_DIR := "user://telemetry"
const SUMMARY_FILE := "runs.csv"
const SEP := ";"

const SUMMARY_HEADER: Array[String] = [
	"data", "seed", "resultado", "duracao_s", "acoes", "frente", "re", "giros",
	"colisoes", "sonares", "o2_final", "casco_final", "golpes", "deteccoes",
	"sonar_ouvido", "cargas", "hesitacoes", "menor_dist_criatura",
	"acoes_com_criatura_a_4", "caminho_otimo", "dist_saida_final",
	"casas_visitadas", "acao_fim_calma", "falas_radio",
]
const EVENT_HEADER: Array[String] = [
	"tempo_s", "acao", "evento", "detalhe", "cap_x", "cap_y", "dist_saida",
	"o2", "casco", "dist_criatura", "estado_criatura",
]

## Lido só para registrar o estado (WANDERING, STALKING...) e a calma.
@export var enemy: Node

## Injetado pelo LevelSetup.
var maze: MazeGrid

var _dir := ""
var _event_file: FileAccess
var _written := false
var _start_msec := 0
var _exit_distances := {}
var _capsule_cell := Vector2i.ZERO
var _enemy_steps := -1
var _last_enemy_state := ""
var _last_kind := &""
var _visited := {}
var _radio_lines: Array[String] = []
var _stats := {
	"acoes": 0, "frente": 0, "re": 0, "giros": 0, "colisoes": 0, "sonares": 0,
	"golpes": 0, "deteccoes": 0, "sonar_ouvido": 0, "cargas": 0, "hesitacoes": 0,
	"menor_dist_criatura": -1, "acoes_com_criatura_a_4": 0, "acao_fim_calma": -1,
}


func _ready() -> void:
	# Testes automáticos (--headless) mexem no estado à força: não entram na estatística.
	if maze == null or DisplayServer.get_name() == "headless":
		maze = null
		return
	_start_msec = Time.get_ticks_msec()
	_capsule_cell = maze.start_cell
	_visited[_capsule_cell] = true
	_exit_distances = maze.get_distances_from(maze.exit_cell)
	_dir = EDITOR_DIR if OS.has_feature("editor") else BUILD_DIR
	_open_event_file()

	EventBus.maneuver_started.connect(func(kind: StringName, _d: float) -> void: _last_kind = kind)
	EventBus.capsule_moved.connect(_on_capsule_moved)
	EventBus.capsule_rotated.connect(_on_capsule_rotated)
	EventBus.capsule_collided.connect(_on_capsule_collided)
	EventBus.sonar_pinged.connect(_on_sonar_pinged)
	EventBus.enemy_proximity_changed.connect(_on_enemy_proximity_changed)
	EventBus.enemy_detected.connect(func(c: Vector2i) -> void: _count("deteccoes"); _log("eco_criatura", _cell_text(c)))
	EventBus.enemy_heard_sonar.connect(func(s: int) -> void: _count("sonar_ouvido"); _log("criatura_ouviu_sonar", "a %d passos" % s))
	EventBus.enemy_charging.connect(func(_c: Vector2i) -> void: _count("cargas"); _log("criatura_em_carga"))
	EventBus.enemy_hesitated.connect(func(_c: Vector2i) -> void: _count("hesitacoes"); _log("criatura_hesitou"))
	EventBus.enemy_attacked.connect(func(_c: Vector2i) -> void: _count("golpes"); _log("golpe"))
	EventBus.alarm_started.connect(func(reason: StringName) -> void: _log("alarme", reason))
	EventBus.radio_line_started.connect(func(id: StringName, _t: String, _d: float) -> void:
		_radio_lines.append(id)
		_log("radio", id))
	EventBus.game_over.connect(_on_game_over)
	_log("inicio", "seed %d, caminho ótimo %d" % [_seed(), _optimal_path()])
	print("[Telemetria] gravando em ", ProjectSettings.globalize_path(_dir))


## Fechar o jogo (ou recarregar a cena) no meio da partida.
func _exit_tree() -> void:
	if maze != null and not _written:
		_log("abandono")
		_write_summary("ABANDONO")
	if _event_file:
		_event_file.close()
		_event_file = null


# --- Eventos ---------------------------------------------------------------------

func _on_capsule_moved(new_position: Vector2i, _direction: Vector2i) -> void:
	_capsule_cell = new_position
	_visited[new_position] = true
	_count_action("re" if _last_kind == &"backward" else "frente")
	_log("re" if _last_kind == &"backward" else "frente")


func _on_capsule_rotated(_new_direction: Vector2i) -> void:
	_count_action("giros")
	_log("giro", "esquerda" if _last_kind == &"rotate_left" else "direita")


func _on_capsule_collided(_blocked_cell: Vector2i, _direction: Vector2i) -> void:
	_count_action("colisoes")
	_log("colisao", "de ré" if _last_kind == &"backward" else "de frente")


func _on_sonar_pinged(_origin: Vector2i, _hits: Array[Vector2i]) -> void:
	_count_action("sonares")
	_log("sonar")


## Emitido depois de cada turno da criatura: mede a pressão dela sobre o jogador.
func _on_enemy_proximity_changed(steps: int) -> void:
	_enemy_steps = steps
	if steps >= 0:
		var closest: int = _stats.menor_dist_criatura
		if closest < 0 or steps < closest:
			_stats.menor_dist_criatura = steps
	if enemy and int(_stats.acao_fim_calma) < 0 and not enemy.is_calm():
		_stats.acao_fim_calma = _stats.acoes
		_log("fim_da_calma")
	var state := _enemy_state()
	if state != _last_enemy_state:
		if _last_enemy_state != "":
			_log("criatura_mudou", "%s -> %s" % [_last_enemy_state, state])
		_last_enemy_state = state


func _on_game_over(won: bool) -> void:
	var result := "VITORIA"
	if not won:
		result = "CRIATURA" if GameState.end_reason == GameState.EndReason.CAUGHT else "OXIGENIO"
	_log("fim", result)
	_write_summary(result)


# --- Contagem --------------------------------------------------------------------

## Ação do jogador concluída (andar, ré, girar, colidir, sonar).
func _count_action(key: String) -> void:
	_stats.acoes += 1
	_count(key)
	if _enemy_steps >= 0 and _enemy_steps <= 4:
		_stats.acoes_com_criatura_a_4 += 1


func _count(key: String) -> void:
	_stats[key] += 1


# --- Arquivos --------------------------------------------------------------------

func _open_event_file() -> void:
	if not _ensure_dir():
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	_event_file = FileAccess.open("%s/run_%s.csv" % [_dir, stamp], FileAccess.WRITE)
	if _event_file:
		_event_file.store_line(SEP.join(EVENT_HEADER))


func _log(event: String, detail := "") -> void:
	if _event_file == null:
		return
	var row: Array[String] = [
		_num(_elapsed()), str(_stats.acoes), event, detail,
		str(_capsule_cell.x), str(_capsule_cell.y), str(_exit_distances.get(_capsule_cell, -1)),
		str(ceili(GameState.oxygen)), str(GameState.hull), str(_enemy_steps), _enemy_state(),
	]
	_event_file.store_line(SEP.join(row))
	_event_file.flush()


func _write_summary(result: String) -> void:
	_written = true
	if not _ensure_dir():
		return
	var path := "%s/%s" % [_dir, SUMMARY_FILE]
	var is_new := not FileAccess.file_exists(path)
	var file := FileAccess.open(path, FileAccess.READ_WRITE if not is_new else FileAccess.WRITE)
	if file == null:
		push_warning("Telemetria: não foi possível abrir %s" % path)
		return
	if is_new:
		file.store_line(SEP.join(SUMMARY_HEADER))
	file.seek_end()
	var s := _stats
	var row: Array[String] = [
		Time.get_datetime_string_from_system(false, true), str(_seed()), result, _num(_elapsed()),
		str(s.acoes), str(s.frente), str(s.re), str(s.giros), str(s.colisoes), str(s.sonares),
		str(ceili(GameState.oxygen)), str(GameState.hull), str(s.golpes), str(s.deteccoes),
		str(s.sonar_ouvido), str(s.cargas), str(s.hesitacoes), str(s.menor_dist_criatura),
		str(s.acoes_com_criatura_a_4), str(_optimal_path()), str(_exit_distances.get(_capsule_cell, -1)),
		str(_visited.size()), str(s.acao_fim_calma), " ".join(_radio_lines),
	]
	file.store_line(SEP.join(row))
	file.close()


func _ensure_dir() -> bool:
	if _dir == "":
		return false
	if DirAccess.make_dir_recursive_absolute(_dir) != OK:
		push_warning("Telemetria: não foi possível criar %s" % _dir)
		return false
	# Sem isto, o editor tentaria importar os CSVs como traduções.
	var ignore := _dir.path_join(".gdignore")
	if _dir.begins_with("res://") and not FileAccess.file_exists(ignore):
		var f := FileAccess.open(ignore, FileAccess.WRITE)
		if f:
			f.close()
	return true


# --- Utilitários -----------------------------------------------------------------

func _enemy_state() -> String:
	if enemy == null:
		return ""
	if enemy.is_calm():
		return "CALMA"
	return enemy.State.keys()[enemy.state]


func _seed() -> int:
	var setup := get_parent() as Node
	return setup.seed_used if setup and "seed_used" in setup else 0


func _optimal_path() -> int:
	return _exit_distances.get(maze.start_cell, -1) if maze else -1


func _elapsed() -> float:
	return (Time.get_ticks_msec() - _start_msec) / 1000.0


func _cell_text(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


## Vírgula decimal (planilha em pt-BR).
func _num(value: float) -> String:
	return ("%.1f" % value).replace(".", ",")
