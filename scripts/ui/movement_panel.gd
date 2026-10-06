extends HBoxContainer
## Painel de movimentação da cápsula (Andar / Girar 90º Esquerda / Girar 90º Direita).
## "Dumb UI": não conhece a Capsule nem o oxigênio. Cada botão apenas emite
## a intenção correspondente no EventBus; quem executa (e quem cobra o custo)
## são os sistemas que escutam esses sinais.
## Ao fim da partida (EventBus.game_over), os botões são desabilitados.

@onready var _rotate_left_button: Button = %RotateLeftButton
@onready var _move_forward_button: Button = %MoveForwardButton
@onready var _rotate_right_button: Button = %RotateRightButton


func _ready() -> void:
	_rotate_left_button.pressed.connect(EventBus.request_rotate_left.emit)
	_move_forward_button.pressed.connect(EventBus.request_move_forward.emit)
	_rotate_right_button.pressed.connect(EventBus.request_rotate_right.emit)
	EventBus.game_over.connect(_on_game_over)


func _on_game_over(_won: bool) -> void:
	for button in [_rotate_left_button, _move_forward_button, _rotate_right_button]:
		button.disabled = true
