extends Node3D
## Posto de comando diegético: agrupa as PanelScreens montadas sobre o painel
## amarelo e o monitor superior da malha da cabine (sonar no CRT, teclado na
## área cinza, mostradores de O₂/interferência nos relógios, log no monitor).
## Substitui o antigo NavigationConsole 2D: tudo acontece na própria cabine.
## Único papel do script: receber a MazeGrid do LevelSetup (propriedade `maze`,
## como os demais consumidores) e entregá-la ao mapa do sonar.

var maze: MazeGrid:
	set(value):
		maze = value
		if is_node_ready():
			_apply_maze()

@onready var _sonar_screen: PanelScreen = $SonarScreen


func _ready() -> void:
	_apply_maze()


func _apply_maze() -> void:
	if _sonar_screen.content_node:
		_sonar_screen.content_node.maze = maze
