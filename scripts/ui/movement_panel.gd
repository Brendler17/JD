extends GridContainer
## Teclado de comando da cápsula, em cruz: Frente (cima), Ré (baixo),
## Girar 90º Esquerda/Direita (lados) e Sonar (centro).
## "Dumb UI": não conhece a Capsule nem o oxigênio. Cada botão apenas emite
## a intenção correspondente no EventBus; quem executa (e quem cobra o custo)
## são os sistemas que escutam esses sinais.
## Ao fim da partida (EventBus.game_over), os botões são desabilitados.

@onready var _move_forward_button: Button = %MoveForwardButton
@onready var _move_backward_button: Button = %MoveBackwardButton
@onready var _rotate_left_button: Button = %RotateLeftButton
@onready var _rotate_right_button: Button = %RotateRightButton
@onready var _sonar_button: Button = %SonarButton


func _ready() -> void:
	_move_forward_button.pressed.connect(EventBus.request_move_forward.emit)
	_move_backward_button.pressed.connect(EventBus.request_move_backward.emit)
	_rotate_left_button.pressed.connect(EventBus.request_rotate_left.emit)
	_rotate_right_button.pressed.connect(EventBus.request_rotate_right.emit)
	_sonar_button.pressed.connect(EventBus.request_sonar_ping.emit)
	EventBus.game_over.connect(_on_game_over)


func _on_game_over(_won: bool) -> void:
	for button: Button in [_move_forward_button, _move_backward_button, _rotate_left_button, _rotate_right_button, _sonar_button]:
		button.disabled = true
