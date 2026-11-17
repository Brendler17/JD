extends Node
## Autoload que troca de cena: menu principal ↔ partida, reinício e sair.
## Reage às intenções do EventBus (request_new_game, request_restart,
## request_main_menu, request_quit) com um fade para preto:
##   pausa a árvore → escurece → avisa session_ended → troca a cena →
##   despausa → clareia.
## O GameState zera o estado da partida nas mesmas intenções (ele não troca cena).
## O session_ended permite que autoloads (AudioManager) desliguem sons de jogo
## que ficariam órfãos (sirene, rangido) quando a cena some no meio da partida.

const MENU_SCENE := "res://scenes/menu/main_menu.tscn"
const GAME_SCENE := "res://scenes/main/main.tscn"
const FADE_OUT := 0.45
const FADE_IN := 0.9

var _layer: CanvasLayer
var _curtain: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_curtain = ColorRect.new()
	_curtain.color = Color.BLACK
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.modulate.a = 0.0
	_layer.add_child(_curtain)

	EventBus.request_new_game.connect(_go.bind(GAME_SCENE))
	EventBus.request_restart.connect(_go.bind(GAME_SCENE))
	EventBus.request_main_menu.connect(_go.bind(MENU_SCENE))
	EventBus.request_quit.connect(_quit)


func _go(scene_path: String) -> void:
	if _busy:
		return
	_busy = true
	get_tree().paused = true
	# O clique que pediu a troca não deve chegar a nada embaixo da cortina.
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0, FADE_OUT)
	EventBus.session_ended.emit()
	get_tree().change_scene_to_file(scene_path)
	# Espera a cena nova entrar (o primeiro frame dela já sob a cortina).
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().paused = false
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	await _fade_to(0.0, FADE_IN)


func _quit() -> void:
	if _busy:
		return
	_busy = true
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0, FADE_OUT)
	get_tree().quit()


func _fade_to(alpha: float, time: float) -> void:
	var tween := create_tween()
	tween.tween_property(_curtain, "modulate:a", alpha, time)
	await tween.finished
