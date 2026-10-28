extends Control
## Visualizador de texto dos objetos da cabine (Interactable com SHOW_TEXT).
## Abre em EventBus.request_show_note; qualquer clique, Esc ou E fecha e
## emite note_closed para o jogador voltar a andar.

@onready var _title_label: Label = %NoteTitleLabel
@onready var _body_label: Label = %NoteBodyLabel


func _ready() -> void:
	hide()
	EventBus.request_show_note.connect(_on_request_show_note)


func _on_request_show_note(title: String, body: String) -> void:
	_title_label.text = title
	_body_label.text = body
	show()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var close: bool = (event is InputEventMouseButton and event.pressed) \
			or event.is_action_pressed("ui_cancel") \
			or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_E)
	if close:
		get_viewport().set_input_as_handled()
		hide()
		EventBus.note_closed.emit()
