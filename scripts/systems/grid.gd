class_name Grid
## Conversões entre o espaço lógico da grade (matriz do labirinto, Vector2i)
## e o espaço 3D do mundo (Vector3, em metros).
## A grade lógica é a fonte de verdade da posição; o 3D apenas a representa.
## Mapeamento: coluna (x) -> eixo X do mundo; linha (y) -> eixo Z do mundo.
## Assim, "cima" na matriz (y - 1) coincide com o "frente" padrão do Godot (-Z).

## Tamanho de uma célula do labirinto, em metros.
const CELL_SIZE := 4.0


## Centro da célula no mundo 3D (no plano do chão, y = 0).
static func grid_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)
