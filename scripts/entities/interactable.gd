class_name Interactable
extends Area3D
## Objeto da cabine que o jogador pode acionar mirando e clicando.
## Não conhece o jogador nem a UI: ao ser acionado, só emite a intenção
## correspondente no EventBus (abrir texto ou sentar no posto de comando).
## Fica na camada de colisão de interação (layer 2), lida pelo raio da câmera.

enum Action { SHOW_TEXT, ENTER_NAVIGATION }

@export var action: Action = Action.SHOW_TEXT
## Texto exibido abaixo da mira quando o objeto está sob ela.
@export var prompt := "Examinar"
@export var title := ""
@export_multiline var text := ""


func interact() -> void:
	match action:
		Action.SHOW_TEXT:
			EventBus.request_show_note.emit(title, text)
		Action.ENTER_NAVIGATION:
			EventBus.request_enter_navigation.emit()
