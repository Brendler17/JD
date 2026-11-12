extends Control
## HUD mínima do modo em 1ª pessoa: o ponto de mira no centro e, abaixo dele,
## a ação do objeto ou da tecla do painel sob a mira ("[Clique] Avançar").
## Continua visível sentado no posto (a mira é como se opera o painel). Sentado,
## o texto some (cobriria as teclas vizinhas, pequenas na tela) e só a cor da mira
## indica que há uma tecla sob ela, que também acende. Some lendo um texto ou no fim.

@onready var _crosshair: Control = %Crosshair
@onready var _prompt_label: Label = %PromptLabel

var _navigating := false


func _ready() -> void:
	_prompt_label.text = ""
	EventBus.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	EventBus.navigation_mode_changed.connect(func(active: bool) -> void: _navigating = active)
	EventBus.request_show_note.connect(func(_title: String, _body: String) -> void: hide())
	EventBus.note_closed.connect(show)
	EventBus.game_over.connect(func(_won: bool) -> void: hide())


func _on_interaction_prompt_changed(prompt: String) -> void:
	_prompt_label.text = "[Clique]  %s" % prompt if prompt and not _navigating else ""
	_crosshair.modulate = Color(0.5, 1.0, 0.9) if prompt else Color(1, 1, 1, 0.7)
