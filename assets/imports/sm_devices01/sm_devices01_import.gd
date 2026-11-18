@tool
extends EditorScenePostImport
## Pós-importação do SM_Devices01 (painel exportado da Unreal).
##
## A malha usa texturas UDIM (blocos 1001–1006 lado a lado em U), que a Godot
## não suporta. Este script separa cada triângulo pelo bloco UDIM em que está,
## gera uma superfície por bloco com o UV trazido de volta para 0–1 e aplica um
## ORMMaterial3D por bloco, usando as texturas originais de 4096².
##
## Os materiais são salvos em materials/ na primeira importação e reaproveitados
## depois: ajuste os .tres no editor e eles sobrevivem à reimportação.

const BASE_DIR := "res://assets/imports/sm_devices01/"
const TEX_DIR := BASE_DIR + "textures/"
const MAT_DIR := BASE_DIR + "materials/"
const TEX_PREFIX := "T_Devices01_"
## MI_Devices01: Emiss_Multy = 0,2 e Emissiv_Color = branco (ver SM_Devices01_material.json).
const EMISSION_ENERGY := 0.2


func _post_import(scene: Node) -> Object:
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh:
			mi.mesh = _split_udim(mi.mesh)
	return scene


func _split_udim(src: Mesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	# tile -> { "old_to_new": Dictionary, "src": Array, "indices": PackedInt32Array, "verts": PackedInt32Array }
	var buckets := {}
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			indices = PackedInt32Array(range(uvs.size()))
		for t in range(0, indices.size(), 3):
			var a := indices[t]
			var b := indices[t + 1]
			var c := indices[t + 2]
			var tile := int(floor((uvs[a].x + uvs[b].x + uvs[c].x) / 3.0))
			var key := "%d_%d" % [s, tile]
			if not buckets.has(key):
				buckets[key] = {"tile": tile, "src": arrays, "map": {}, "verts": PackedInt32Array(), "indices": PackedInt32Array()}
			var bucket: Dictionary = buckets[key]
			for v in [a, b, c]:
				var m: Dictionary = bucket.map
				if not m.has(v):
					m[v] = bucket.verts.size()
					bucket.verts.append(v)
				bucket.indices.append(m[v])

	var keys := buckets.keys()
	keys.sort_custom(func(x, y): return buckets[x].tile < buckets[y].tile)
	for key in keys:
		var bucket: Dictionary = buckets[key]
		var arrays := _subset_arrays(bucket.src, bucket.verts, bucket.indices, bucket.tile)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var surf := out.get_surface_count() - 1
		out.surface_set_name(surf, "UDIM_%d" % (1001 + bucket.tile))
		out.surface_set_material(surf, _material_for_tile(1001 + bucket.tile))
	return out


func _subset_arrays(src: Array, verts: PackedInt32Array, indices: PackedInt32Array, tile: int) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var pos: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var p := PackedVector3Array()
	for v in verts:
		p.append(pos[v])
	arrays[Mesh.ARRAY_VERTEX] = p

	if src[Mesh.ARRAY_NORMAL] != null:
		var n_src: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
		var n := PackedVector3Array()
		for v in verts:
			n.append(n_src[v])
		arrays[Mesh.ARRAY_NORMAL] = n

	if src[Mesh.ARRAY_TANGENT] != null:
		var t_src: PackedFloat32Array = src[Mesh.ARRAY_TANGENT]
		var t := PackedFloat32Array()
		for v in verts:
			for k in 4:
				t.append(t_src[v * 4 + k])
		arrays[Mesh.ARRAY_TANGENT] = t

	if src[Mesh.ARRAY_COLOR] != null:
		var c_src: PackedColorArray = src[Mesh.ARRAY_COLOR]
		var c := PackedColorArray()
		for v in verts:
			c.append(c_src[v])
		arrays[Mesh.ARRAY_COLOR] = c

	var uv_src: PackedVector2Array = src[Mesh.ARRAY_TEX_UV]
	var uv := PackedVector2Array()
	var offset := Vector2(tile, 0)
	for v in verts:
		uv.append(uv_src[v] - offset)
	arrays[Mesh.ARRAY_TEX_UV] = uv

	if src[Mesh.ARRAY_TEX_UV2] != null:
		var uv2_src: PackedVector2Array = src[Mesh.ARRAY_TEX_UV2]
		var uv2 := PackedVector2Array()
		for v in verts:
			uv2.append(uv2_src[v])
		arrays[Mesh.ARRAY_TEX_UV2] = uv2

	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


func _material_for_tile(udim: int) -> Material:
	var path := MAT_DIR + "M_Devices01_%d.tres" % udim
	if ResourceLoader.exists(path):
		return load(path)

	var mat := ORMMaterial3D.new()
	mat.resource_name = "M_Devices01_%d" % udim
	mat.albedo_texture = _tex("BC", udim)
	mat.orm_texture = _tex("ORM", udim)
	mat.normal_enabled = true
	mat.normal_texture = _tex("N", udim)
	var emissive := _tex("E", udim)
	if emissive:
		# Unreal: Emissive = textura × Emissiv_Color × Emiss_Multy.
		mat.emission_enabled = true
		mat.emission = Color.WHITE
		mat.emission_texture = emissive
		mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		mat.emission_energy_multiplier = EMISSION_ENERGY
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	DirAccess.make_dir_recursive_absolute(MAT_DIR)
	ResourceSaver.save(mat, path)
	mat.take_over_path(path)
	return mat


func _tex(kind: String, udim: int) -> Texture2D:
	var path := TEX_DIR + "%s%s_%d.png" % [TEX_PREFIX, kind, udim]
	if ResourceLoader.exists(path):
		return load(path)
	return null
