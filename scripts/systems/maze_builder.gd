@tool
extends Node3D
## Constrói a representação 3D de uma MazeGrid: uma parede (bloco) por célula
## '#' e um marcador na saída. Não contém regras de jogo — só visual, o que
## também serve de debug para conferir se a matriz está correta.
## Roda no editor (@tool): o labirinto aparece na viewport e é reconstruído
## sempre que o Resource for alterado no Inspector.
## Os nós gerados não têm owner, então nunca são salvos na cena.

const WALL_HEIGHT := 3.0
const EXIT_MARKER_HEIGHT := 0.2

@export var maze: MazeGrid:
	set(value):
		if maze and maze.changed.is_connected(_rebuild):
			maze.changed.disconnect(_rebuild)
		maze = value
		if maze:
			maze.changed.connect(_rebuild)
		_rebuild()

@export var wall_color: Color = Color(0.32, 0.38, 0.45)
@export var exit_color: Color = Color(0.2, 0.85, 0.4)


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if maze == null or maze.width == 0:
		return

	_build_walls()
	_build_exit_marker()


## Todas as paredes num único MultiMeshInstance3D (1 draw call, independente do tamanho do labirinto).
func _build_walls() -> void:
	var wall_cells := maze.get_cells_of_type(MazeGrid.CellType.WALL)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(Grid.CELL_SIZE, WALL_HEIGHT, Grid.CELL_SIZE)
	mesh.material = _make_material(wall_color)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = wall_cells.size()
	for i in wall_cells.size():
		var pos := Grid.grid_to_world(wall_cells[i]) + Vector3.UP * WALL_HEIGHT * 0.5
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))

	var walls := MultiMeshInstance3D.new()
	walls.name = "Walls"
	walls.multimesh = multimesh
	add_child(walls)


func _build_exit_marker() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(Grid.CELL_SIZE * 0.8, EXIT_MARKER_HEIGHT, Grid.CELL_SIZE * 0.8)
	mesh.material = _make_material(exit_color)

	var marker := MeshInstance3D.new()
	marker.name = "ExitMarker"
	marker.mesh = mesh
	marker.position = Grid.grid_to_world(maze.exit_cell) + Vector3.UP * EXIT_MARKER_HEIGHT * 0.5
	add_child(marker)


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
