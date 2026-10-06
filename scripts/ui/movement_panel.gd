extends HBoxContainer
## Painel de movimentação da cápsula (Andar / Girar 90º Esquerda / Girar 90º Direita).
## "Dumb UI": não conhece a Capsule nem o oxigênio. Cada botão apenas emite
## a intenção correspondente no EventBus; quem executa (e quem cobra o custo)
## são os sistemas que escutam esses sinais.

@onready var _rotate_left_button: Button = %RotateLeftButton
@onready var _move_forward_button: Button = %MoveForwardButton
@onready var _rotate_right_button: Button = %RotateRightButton


func _ready() -> void:
	_rotate_left_button.pressed.connect(EventBus.request_rotate_left.emit)
	_move_forward_button.pressed.connect(EventBus.request_move_forward.emit)
	_rotate_right_button.pressed.connect(EventBus.request_rotate_right.emit)
