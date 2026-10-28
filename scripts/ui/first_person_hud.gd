extends Control
## HUD mínima do modo em 1ª pessoa: o ponto de mira no centro e, abaixo dele,
## a ação do objeto sob a mira ("Clique: Examinar ..."). Some enquanto o
## jogador está no painel de navegação, lendo um texto ou no fim da partida.

@onready var _crosshair: Control = %Crosshair
@onready var _prompt_label: Label = %PromptLabel


func _ready() -> void:
	_prompt_label.text = ""
	EventBus.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	EventBus.navigation_mode_changed.connect(func(active: bool) -> void: visible = not active)
	EventBus.request_show_note.connect(func(_title: String, _body: String) -> void: hide())
	EventBus.note_closed.connect(show)
	EventBus.game_over.connect(func(_won: bool) -> void: hide())


func _on_interaction_prompt_changed(prompt: String) -> void:
	_prompt_label.text = "[Clique]  %s" % prompt if prompt else ""
	_crosshair.modulate = Color(0.5, 1.0, 0.9) if prompt else Color(1, 1, 1, 0.7)
