extends Control
## Tela de fim de partida (vitória/derrota). Fica oculta até EventBus.game_over;
## o botão "Tentar novamente" apenas emite a intenção request_restart,
## e quem reinicia de fato é o GameState.
## Se o rádio está ocupado no fim (a fala final do comandante é o desfecho da
## história), a tela espera ele terminar (radio_busy_changed) antes de aparecer,
## com um limite de segurança. Um clique antecipa a tela.

## Limite de espera pelo rádio, caso algo trave.
const MAX_RADIO_WAIT := 20.0
## Silêncio entre o fim da fala e a tela.
const AFTER_RADIO_DELAY := 0.8
const FADE_TIME := 0.6

@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _retry_button: Button = %RetryButton

var _radio_busy := false
## game_over já aconteceu e a tela ainda não apareceu.
var _pending := false


func _ready() -> void:
	hide()
	EventBus.game_over.connect(_on_game_over)
	EventBus.radio_busy_changed.connect(_on_radio_busy_changed)
	_retry_button.pressed.connect(EventBus.request_restart.emit)


func _on_game_over(won: bool) -> void:
	if won:
		_title_label.text = "SAÍDA ALCANÇADA"
		_subtitle_label.text = "A cápsula encontrou o caminho para fora."
	elif GameState.end_reason == GameState.EndReason.CAUGHT:
		_title_label.text = "CONTATO"
		_subtitle_label.text = "Algo no escuro encontrou a cápsula."
	else:
		_title_label.text = "OXIGÊNIO ESGOTADO"
		_subtitle_label.text = "O silêncio tomou conta da cápsula."
	_pending = true
	# Adiado: o RadioSystem agenda a fala final no mesmo game_over.
	_reveal_when_radio_free.call_deferred()


func _reveal_when_radio_free() -> void:
	if not _radio_busy:
		_reveal()
		return
	get_tree().create_timer(MAX_RADIO_WAIT).timeout.connect(_reveal)


func _on_radio_busy_changed(busy: bool) -> void:
	_radio_busy = busy
	if not busy and _pending:
		get_tree().create_timer(AFTER_RADIO_DELAY).timeout.connect(_reveal)


func _unhandled_input(event: InputEvent) -> void:
	if _pending and event is InputEventMouseButton and event.pressed:
		_reveal()


func _reveal() -> void:
	if not _pending:
		return
	_pending = false
	modulate.a = 0.0
	show()
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_TIME)
