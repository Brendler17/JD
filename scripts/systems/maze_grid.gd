@tool
class_name MazeGrid
extends Resource
## Dados do labirinto: uma matriz de células, independente de nós de cena.
## É a fonte de verdade para regras de jogo (pode andar? chegou na saída?);
## a representação 3D é construída a partir dela pelo MazeBuilder.
##
## O mapa é escrito como texto, uma string por linha (índice = y), um
## caractere por coluna (índice = x):
##   '#' parede   '.' livre   'S' início (exatamente 1)   'E' saída (exatamente 1)
## Tudo fora dos limites da matriz é tratado como parede.

enum CellType { FLOOR, WALL, START, EXIT }

const CHAR_TO_CELL := {
	".": CellType.FLOOR,
	"#": CellType.WALL,
	"S": CellType.START,
	"E": CellType.EXIT,
}

@export var rows: PackedStringArray:
	set(value):
		rows = value
		_parse()
		emit_changed()

var width: int = 0
var height: int = 0
var start_cell: Vector2i = Vector2i.ZERO
var exit_cell: Vector2i = Vector2i.ZERO

var _cells: Array[CellType] = []


func get_cell(cell: Vector2i) -> CellType:
	if not is_inside(cell):
		return CellType.WALL
	return _cells[cell.y * width + cell.x]


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func is_walkable(cell: Vector2i) -> bool:
	return get_cell(cell) != CellType.WALL


func is_exit(cell: Vector2i) -> bool:
	return cell == exit_cell


## Lista de todas as células de um tipo (usado pelo MazeBuilder para instanciar paredes).
func get_cells_of_type(type: CellType) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in height:
		for x in width:
			if _cells[y * width + x] == type:
				result.append(Vector2i(x, y))
	return result


func _parse() -> void:
	height = rows.size()
	width = rows[0].length() if height > 0 else 0
	_cells.clear()
	_cells.resize(width * height)

	var start_count := 0
	var exit_count := 0
	for y in height:
		var row := rows[y]
		if row.length() != width:
			push_error("MazeGrid: linha %d tem %d colunas, esperado %d." % [y, row.length(), width])
		for x in width:
			var ch := row[x] if x < row.length() else "#"
			var type: CellType = CHAR_TO_CELL.get(ch, CellType.WALL)
			if not CHAR_TO_CELL.has(ch):
				push_warning("MazeGrid: caractere '%s' desconhecido em (%d, %d), tratado como parede." % [ch, x, y])
			if type == CellType.START:
				start_cell = Vector2i(x, y)
				start_count += 1
			elif type == CellType.EXIT:
				exit_cell = Vector2i(x, y)
				exit_count += 1
			_cells[y * width + x] = type

	if height > 0 and (start_count != 1 or exit_count != 1):
		push_error("MazeGrid: o mapa precisa de exatamente 1 'S' e 1 'E' (encontrados %d e %d)." % [start_count, exit_count])
