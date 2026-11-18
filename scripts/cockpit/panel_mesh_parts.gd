class_name PanelMeshParts
## Separa peças da malha do painel (SM_Devices01, nó `PanelMesh` no grupo
## "panel_mesh") para que ganhem movimento próprio: o ponteiro dos relógios gira e
## o knob do alarme afunda ao ser pressionado.
## A malha veio da Unreal como uma peça única, então os triângulos escolhidos são
## retirados dela e devolvidos como uma ArrayMesh nova, no espaço local de quem
## pediu (`frame`), com os mesmos materiais (inclusive as cópias do CabinGlow, para
## a peça apagar junto com o painel nas falhas de luz).
## Tudo roda uma vez, no _ready de quem pede.

const GROUP := &"panel_mesh"
## Precisão (m) para considerar dois vértices o mesmo ponto ao montar as peças conexas.
const WELD := 0.0005


## MeshInstance3D do painel, ou null se a cena não tiver um nó no grupo "panel_mesh".
static func find_panel_mesh(tree: SceneTree) -> MeshInstance3D:
	var root := tree.get_first_node_in_group(GROUP)
	if root == null:
		return null
	if root is MeshInstance3D:
		return root
	var found := root.find_children("*", "MeshInstance3D", true, false)
	return found[0] if not found.is_empty() else null


## Retira a peça solta (conjunto de triângulos ligados entre si) perto de `center`
## cuja maior dimensão fica entre `min_extent` e `max_extent` (m) e que tem no
## máximo `max_tris` triângulos. Usado para achar o ponteiro de cada relógio sem
## depender da ordem dos triângulos no arquivo.
static func extract_component(mi: MeshInstance3D, center: Vector3, radius: float,
		min_extent: float, max_extent: float, max_tris: int, frame: Transform3D) -> ArrayMesh:
	var picks := {}  # surface -> PackedInt32Array de índices de triângulo
	var xf := mi.global_transform
	for s in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var parent := {}
		var tri_root_key := {}  # triângulo -> chave de um vértice
		for t in range(0, indices.size(), 3):
			var a := xf * verts[indices[t]]
			var b := xf * verts[indices[t + 1]]
			var c := xf * verts[indices[t + 2]]
			if ((a + b + c) / 3.0).distance_to(center) > radius:
				continue
			var ka := Vector3i((a / WELD).round())
			var kb := Vector3i((b / WELD).round())
			var kc := Vector3i((c / WELD).round())
			for k in [ka, kb, kc]:
				if not parent.has(k):
					parent[k] = k
			_union(parent, ka, kb)
			_union(parent, ka, kc)
			tri_root_key[t / 3] = [ka, a, b, c]
		var comps := {}
		for tri in tri_root_key:
			var info: Array = tri_root_key[tri]
			var r = _find(parent, info[0])
			if not comps.has(r):
				comps[r] = {"tris": PackedInt32Array(), "min": Vector3.INF, "max": -Vector3.INF}
			var comp: Dictionary = comps[r]
			comp.tris.append(tri)
			for p in [info[1], info[2], info[3]]:
				comp.min = (comp.min as Vector3).min(p)
				comp.max = (comp.max as Vector3).max(p)
		for r in comps:
			var comp: Dictionary = comps[r]
			var size: Vector3 = comp.max - comp.min
			var extent := maxf(size.x, maxf(size.y, size.z))
			if extent >= min_extent and extent <= max_extent and comp.tris.size() <= max_tris:
				if not picks.has(s):
					picks[s] = PackedInt32Array()
				picks[s].append_array(comp.tris)
	return _take(mi, picks, frame)


## Retira os triângulos que ficam inteiros dentro de um cilindro: eixo passando por
## `base` na direção `axis` (apontando para fora do painel), raio `max_radius`, a
## partir de `min_height` acima da base. Usado para separar a tampa de um knob do
## anel em volta.
static func extract_disc(mi: MeshInstance3D, base: Vector3, axis: Vector3, max_radius: float,
		min_height: float, frame: Transform3D) -> ArrayMesh:
	var picks := {}
	var xf := mi.global_transform
	var n := axis.normalized()
	for s in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for t in range(0, indices.size(), 3):
			var inside := true
			for i in 3:
				var d := xf * verts[indices[t + i]] - base
				var h := d.dot(n)
				if h < min_height or (d - n * h).length() > max_radius:
					inside = false
					break
			if inside:
				if not picks.has(s):
					picks[s] = PackedInt32Array()
				picks[s].append(t / 3)
	return _take(mi, picks, frame)


## Monta a malha da peça (no espaço de `frame`) e reconstrói a malha do painel sem
## esses triângulos, preservando os materiais de cada superfície.
static func _take(mi: MeshInstance3D, picks: Dictionary, frame: Transform3D) -> ArrayMesh:
	var part := ArrayMesh.new()
	if picks.is_empty():
		return part
	var src := mi.mesh
	var to_frame := frame.affine_inverse() * mi.global_transform
	var normal_basis := to_frame.basis.inverse().transposed()
	var rebuilt := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		if not picks.has(s):
			rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			rebuilt.surface_set_material(s, src.surface_get_material(s))
			continue
		var taken := {}
		for tri in picks[s]:
			taken[tri] = true
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var kept := PackedInt32Array()
		var part_indices := PackedInt32Array()
		var remap := {}
		var used := PackedInt32Array()
		for t in range(0, indices.size(), 3):
			if taken.has(t / 3):
				for i in 3:
					var v := indices[t + i]
					if not remap.has(v):
						remap[v] = used.size()
						used.append(v)
					part_indices.append(remap[v])
			else:
				kept.append(indices[t])
				kept.append(indices[t + 1])
				kept.append(indices[t + 2])
		var rest := arrays.duplicate()
		rest[Mesh.ARRAY_INDEX] = kept
		rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rest)
		rebuilt.surface_set_material(s, src.surface_get_material(s))

		var piece := []
		piece.resize(Mesh.ARRAY_MAX)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var out_verts := PackedVector3Array()
		for v in used:
			out_verts.append(to_frame * verts[v])
		piece[Mesh.ARRAY_VERTEX] = out_verts
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var out_normals := PackedVector3Array()
			for v in used:
				out_normals.append((normal_basis * normals[v]).normalized())
			piece[Mesh.ARRAY_NORMAL] = out_normals
		if arrays[Mesh.ARRAY_TANGENT] != null:
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			var out_tangents := PackedFloat32Array()
			for v in used:
				var t3 := (to_frame.basis * Vector3(tangents[v * 4], tangents[v * 4 + 1], tangents[v * 4 + 2])).normalized()
				out_tangents.append_array([t3.x, t3.y, t3.z, tangents[v * 4 + 3]])
			piece[Mesh.ARRAY_TANGENT] = out_tangents
		for channel in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR]:
			if arrays[channel] != null:
				var data = arrays[channel]
				var out = data.duplicate()
				out.resize(used.size())
				for i in used.size():
					out[i] = data[used[i]]
				piece[channel] = out
		piece[Mesh.ARRAY_INDEX] = part_indices
		part.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, piece)
		# Material efetivo (override do CabinGlow, se houver): a peça apaga com o painel.
		part.surface_set_material(part.get_surface_count() - 1, mi.get_active_material(s))

	var overrides := []
	for s in mi.get_surface_override_material_count():
		overrides.append(mi.get_surface_override_material(s))
	mi.mesh = rebuilt
	for s in overrides.size():
		mi.set_surface_override_material(s, overrides[s])
	return part


static func _find(parent: Dictionary, key):
	while parent[key] != key:
		parent[key] = parent[parent[key]]
		key = parent[key]
	return key


static func _union(parent: Dictionary, a, b) -> void:
	var ra = _find(parent, a)
	var rb = _find(parent, b)
	if ra != rb:
		parent[ra] = rb
