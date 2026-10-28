class_name MazeGenerator
## Gerador procedural de labirintos (recursive backtracker + laços opcionais).
## Produz as mesmas linhas de texto de um MazeGrid escrito à mão ('#', '.', 'S', 'E'),
## então o resto do jogo continua lendo apenas a MazeGrid.
##
## Garantias:
## - Existe pelo menos um caminho entre 'S' e 'E' (o backtracker conecta todas as células livres).
## - O menor caminho de 'S' até 'E', em passos de uma célula, é de pelo menos 1/4 do total
##   de células livres do mapa. Se uma tentativa não permitir isso, outra é gerada.
## - A borda do mapa é sempre parede.

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const MAX_ATTEMPTS := 32
## Fração mínima do total de células livres que o menor caminho até a saída deve ter.
const MIN_PATH_RATIO := 0.25


## `size` é arredondado para ímpar (células "sala" ficam nas coordenadas ímpares).
## `loop_chance` é a probabilidade de abrir cada parede interna extra, criando
## caminhos alternativos (0 = labirinto perfeito, só um caminho entre dois pontos).
static func generate(size: Vector2i, rng_seed: int, loop_chance := 0.0) -> MazeGrid:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var width := maxi(size.x, 5) | 1
	var height := maxi(size.y, 5) | 1

	for attempt in MAX_ATTEMPTS:
		var open := _carve(width, height, rng, loop_chance)
		var floor_cells := _open_cells(open, width, height)
		var start: Vector2i = floor_cells[rng.randi_range(0, floor_cells.size() - 1)]
		var distances := _distances_from(start, open, width, height)
		var min_distance := ceili(floor_cells.size() * MIN_PATH_RATIO)
		var candidates: Array[Vector2i] = []
		for cell: Vector2i in distances:
			if distances[cell] >= min_distance:
				candidates.append(cell)
		if candidates.is_empty():
			continue
		var exit: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]

		var maze := MazeGrid.new()
		maze.rows = _to_rows(open, width, height, start, exit)
		return maze

	push_error("MazeGenerator: não foi possível gerar um labirinto válido em %d tentativas." % MAX_ATTEMPTS)
	return null


## Recursive backtracker (iterativo) sobre as células ímpares. Retorna 1 = livre, 0 = parede.
static func _carve(width: int, height: int, rng: RandomNumberGenerator, loop_chance: float) -> PackedByteArray:
	var open := PackedByteArray()
	open.resize(width * height)

	var first := Vector2i(rng.randi_range(0, (width - 3) / 2) * 2 + 1, rng.randi_range(0, (height - 3) / 2) * 2 + 1)
	open[first.y * width + first.x] = 1
	var stack: Array[Vector2i] = [first]
	while not stack.is_empty():
		var cell: Vector2i = stack.back()
		var unvisited: Array[Vector2i] = []
		for dir in DIRECTIONS:
			var next := cell + dir * 2
			if next.x > 0 and next.y > 0 and next.x < width - 1 and next.y < height - 1 \
					and open[next.y * width + next.x] == 0:
				unvisited.append(next)
		if unvisited.is_empty():
			stack.pop_back()
			continue
		var next: Vector2i = unvisited[rng.randi_range(0, unvisited.size() - 1)]
		var between := (cell + next) / 2
		open[between.y * width + between.x] = 1
		open[next.y * width + next.x] = 1
		stack.append(next)

	# Laços: abre paredes internas que separam duas salas (uma coordenada par, outra ímpar).
	if loop_chance > 0.0:
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				if (x + y) % 2 == 1 and open[y * width + x] == 0 and rng.randf() < loop_chance:
					open[y * width + x] = 1
	return open


static func _open_cells(open: PackedByteArray, width: int, height: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in height:
		for x in width:
			if open[y * width + x] == 1:
				cells.append(Vector2i(x, y))
	return cells


## BFS: menor número de passos de `origin` até cada célula livre alcançável.
static func _distances_from(origin: Vector2i, open: PackedByteArray, width: int, height: int) -> Dictionary:
	var distances := {origin: 0}
	var queue: Array[Vector2i] = [origin]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for dir in DIRECTIONS:
			var next := cell + dir
			if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
				continue
			if open[next.y * width + next.x] == 1 and not distances.has(next):
				distances[next] = distances[cell] + 1
				queue.append(next)
	return distances


static func _to_rows(open: PackedByteArray, width: int, height: int, start: Vector2i, exit: Vector2i) -> PackedStringArray:
	var rows := PackedStringArray()
	for y in height:
		var row := ""
		for x in width:
			var cell := Vector2i(x, y)
			if cell == start:
				row += "S"
			elif cell == exit:
				row += "E"
			else:
				row += "." if open[y * width + x] == 1 else "#"
		rows.append(row)
	return rows
