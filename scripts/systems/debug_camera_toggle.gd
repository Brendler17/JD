extends Camera3D
## Câmera top-down de debug do labirinto (o mundo lógico fica longe da cabine).
## F3 alterna entre ela e a câmera que estava ativa (a do jogador).

var _previous: Camera3D


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3):
		return
	if current and _previous:
		_previous.make_current()
	else:
		_previous = get_viewport().get_camera_3d()
		make_current()
