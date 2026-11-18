extends Node3D
## Monta a partida: obtém a MazeGrid (procedural ou fixa) e a entrega a todos os
## nós que precisam dela (propriedade `maze`), antes que eles rodem o _ready().
## Roda em _enter_tree(): o pai entra na árvore antes dos filhos, então os
## consumidores já recebem o labirinto quando inicializam.
## Cada reinício (GameState recarrega a cena) gera um labirinto novo.

## Tamanho do labirinto procedural em células (arredondado para ímpar).
@export var maze_size := Vector2i(15, 15)
## Probabilidade de abrir paredes extras, criando caminhos alternativos.
@export_range(0.0, 1.0) var loop_chance := 0.08
## Menor caminho do início até a saída, em passos (mínimo, máximo). Tira a sorte do
## tamanho do percurso: sem ela, o caminho ia de 25 a 74 passos (cauda longa que
## matava por O₂). 28–32 fica em volta da mediana antiga (30). (0, 0) = critério antigo.
@export var exit_path_range := Vector2i(28, 32)
## 0 = semente aleatória a cada partida; outro valor reproduz sempre o mesmo labirinto.
@export var fixed_seed := 0
## Se definido, usa este labirinto escrito à mão em vez de gerar um.
@export var fixed_maze: MazeGrid
## Nós que recebem o labirinto (precisam ter uma propriedade `maze`).
@export var maze_consumers: Array[NodePath] = []

var maze: MazeGrid
## Semente usada nesta partida (0 = labirinto fixo). Lida pela telemetria, para
## dar para repetir um labirinto problemático colocando-a em `fixed_seed`.
var seed_used := 0


func _enter_tree() -> void:
	if fixed_maze:
		maze = fixed_maze
	else:
		var rng_seed := fixed_seed if fixed_seed != 0 else randi()
		seed_used = rng_seed
		maze = MazeGenerator.generate(maze_size, rng_seed, loop_chance, exit_path_range)
	for path in maze_consumers:
		get_node(path).maze = maze
