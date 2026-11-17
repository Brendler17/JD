class_name InfoPanel
extends PanelContainer
## Painel de texto com título e "Voltar" (Controles, Créditos). Montado em código;
## quem usa chama show_info(título, corpo). Emite `closed` no "Voltar".

signal closed

const CONTROLS_TITLE := "CONTROLES"
const CONTROLS_BODY := """ANDANDO PELA CABINE
Mouse — olhar
W A S D ou setas — andar
Clique esquerdo — interagir (sentar no posto, ler anotações)

NO POSTO DE COMANDO
Mouse — mirar no painel
Clique esquerdo — acionar a tecla ou o knob sob a mira
Clique direito — levantar

Esc — pausar

O resto, a Superfície explica pelo rádio. Use fones de ouvido."""

const CREDITS_TITLE := "CRÉDITOS"
const CREDITS_BODY := """PROFUNDIDADE ZERO
Desenvolvido por Gustavo Brendler e Rafael Nunes Siqueira

Feito com Godot Engine 4

Voz do comandante: gerada por IA num sintetizador próprio,
desenvolvido por Gustavo Brendler com o Google AI Studio
Ambiente, criatura, impactos, sirene e sonar: Pixabay
Motor da cápsula: Andreas.Mustola (Freesound, CC0)
Rangido do casco: kyles (Freesound, CC0)
Clique, bipe e estática do rádio: sintetizados pela equipe"""

var _title: Label
var _body: Label


func _ready() -> void:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 18)
	add_child(rows)
	_title = Label.new()
	_title.add_theme_font_size_override(&"font_size", 34)
	_title.add_theme_color_override(&"font_color", Color(1, 0.62, 0.28))
	rows.add_child(_title)
	_body = Label.new()
	_body.custom_minimum_size = Vector2(640, 0)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override(&"font_size", 22)
	rows.add_child(_body)
	var back := Button.new()
	back.text = "Voltar"
	back.focus_mode = Control.FOCUS_NONE
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.add_theme_font_size_override(&"font_size", 22)
	back.pressed.connect(closed.emit)
	rows.add_child(back)


func show_info(title: String, body: String) -> void:
	_title.text = title
	_body.text = body
	show()
