extends Control
## Tela de fim de partida (vitória/derrota). Fica oculta até EventBus.game_over;
## o botão "Tentar novamente" apenas emite a intenção request_restart,
## e quem reinicia de fato é o GameState.

@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _retry_button: Button = %RetryButton


func _ready() -> void:
	hide()
	EventBus.game_over.connect(_on_game_over)
	_retry_button.pressed.connect(EventBus.request_restart.emit)


func _on_game_over(won: bool) -> void:
	if won:
		_title_label.text = "SAÍDA ALCANÇADA"
		_subtitle_label.text = "A cápsula encontrou o caminho para fora."
	else:
		_title_label.text = "OXIGÊNIO ESGOTADO"
		_subtitle_label.text = "O silêncio tomou conta da cápsula."
	show()
