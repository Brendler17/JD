extends SceneTree
## Monta scenes/cockpit/capsule_interior.tscn a partir do export da Unreal
## (assets/imports/capsule: manifest.json, meshes/*.fbx já importados, textures/*.png).
##
## - Cada malha vira um .res em assets/imports/capsule/built/meshes/. Superfícies com
##   texturas UDIM (NOME_1001.png...) são divididas por bloco, com UV trazido para 0–1.
## - Cada material vira um .tres em assets/imports/capsule/built/materials/ (só é criado se
##   não existir: ajustes feitos no editor sobrevivem a uma nova montagem).
## - Os atores ficam no mesmo espaço da antiga malha mesclada (pivô = SM_BedBase01), então a
##   colisão, os interativos e o painel da Main continuam alinhados.
##
## Uso: Godot --headless --path . --script res://tools/build_capsule_scene.gd

const BASE := "res://assets/imports/capsule/"
const OUT_SCENE := "res://scenes/cockpit/capsule_interior.tscn"
## Pivô usado pelo Merge Actors da malha antiga. No mapa Capsule é o SM_BedBase01 (no mapa
## CapsuleExport o mesmo ator se chama SM_BedBase3 e todo o layout está deslocado 295,5/453,1/240 cm).
const PIVOT_ACTOR := "SM_BedBase01"
## Atores que a Main já tem em versão própria (painel em 4K).
const EXCLUDE_MESHES := ["SM_Devices01"]

const ALBEDO_KEYS := ["BC", "BaseColor", "Albedo", "Diffuse"]
const ORM_KEYS := ["ORM", "AORM"]
const NORMAL_KEYS := ["N", "Normal", "Normals"]
const EMISSIVE_KEYS := ["Emissive", "EmColor", "emmisive"]
const EMISSION_COLOR_KEYS := ["Emissiv_Color", "EM_Color", "Color", "Emissive Color Multi", "EmissiveTint"]
const EMISSION_MULT_KEYS := ["Emiss_Multy", "E_Multi", "EmMult", "Em_multy", "EmissiveIntensity", "Emissive Power"]
## Materiais mestres cuja "emissiva" é máscara/efeito (não usar como emissão).
const NO_EMISSION_BASES := ["M_base"]

var manifest: Dictionary
var pivot: Vector3
var tex_files := {}
var material_cache := {}


func _init() -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string(BASE + "manifest.json"))
	for f in DirAccess.get_files_at(BASE + "textures"):
		if f.ends_with(".png"):
			tex_files[f.get_basename()] = true
	for p in manifest.placements:
		if p.actor == PIVOT_ACTOR:
			pivot = _v(p.loc)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE + "built/meshes"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE + "built/materials"))

	var built := {}  # nome da malha -> {mesh, xf, slot_of_surface}
	for name in manifest.meshes:
		if name in EXCLUDE_MESHES:
			continue
		built[name] = _build_mesh(name)

	var root := Node3D.new()
	root.name = "CapsuleInterior"
	var tris := 0
	for p in manifest.placements:
		if not built.has(p.mesh):
			continue
		var b: Dictionary = built[p.mesh]
		var mi := MeshInstance3D.new()
		mi.name = String(p.actor).validate_node_name()
		mi.mesh = b.mesh
		mi.transform = _placement_xform(p) * b.xf
		for s in b.mesh.get_surface_count():
			var info: Dictionary = b.surfaces[s]
			var mat_name = p.materials[info.slot] if info.slot < p.materials.size() else info.material
			if mat_name == null:
				mat_name = info.material
			mi.set_surface_override_material(s, _material(mat_name, info.tile))
			tris += b.mesh.surface_get_array_index_len(s) / 3
		root.add_child(mi)
		mi.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	var err := ResourceSaver.save(scene, OUT_SCENE)
	print("cena salva (%s): %d atores, %d triângulos" % [error_string(err), root.get_child_count(), tris])
	quit()


func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


## Unreal (cm, Z para cima, relativo ao pivô) -> Godot (m, Y para cima), igual à malha mesclada.
func _to_godot(u: Vector3) -> Vector3:
	var d := u - pivot
	return Vector3(d.x, d.z, d.y) / 100.0


## Transform do ator, aplicado sobre o espaço da raiz do FBX importado.
func _placement_xform(p: Dictionary) -> Transform3D:
	var q := Quaternion(p.quat[0], p.quat[1], p.quat[2], p.quat[3])
	var s := _v(p.scale)
	var loc := _v(p.loc)
	var f := func(v: Vector3) -> Vector3:
		var local := Vector3(v.x, v.z, v.y) * 100.0
		return _to_godot(q * (local * s) + loc)
	var o: Vector3 = f.call(Vector3.ZERO)
	return Transform3D(Basis(f.call(Vector3.RIGHT) - o, f.call(Vector3.UP) - o, f.call(Vector3.BACK) - o), o)


func _build_mesh(name: String) -> Dictionary:
	var path := BASE + "meshes/%s.fbx" % name
	var scene: Node = (load(path) as PackedScene).instantiate()
	var mis := scene.find_children("*", "MeshInstance3D", true, false)
	if mis.size() != 1:
		push_warning("%s: %d MeshInstance3D (usando a primeira)" % [name, mis.size()])
	var mi: MeshInstance3D = mis[0]
	var xf := Transform3D.IDENTITY
	var n: Node = mi
	while n != scene:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	var slots: Array = manifest.meshes[name].slots
	var src: Mesh = mi.mesh
	var out := ArrayMesh.new()
	var surfaces := []
	for s in src.get_surface_count():
		var mat := src.surface_get_material(s)
		var mat_name := mat.resource_name if mat else ""
		var slot := slots.find(mat_name)
		if slot < 0:
			slot = mini(s, slots.size() - 1)
			push_warning("%s: superfície %d com material '%s' fora dos slots %s" % [name, s, mat_name, slots])
		var mat_key: String = slots[slot] if slot >= 0 else mat_name
		var arrays := src.surface_get_arrays(s)
		if _is_udim(mat_key):
			for tile_arrays in _split_udim(arrays):
				out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tile_arrays.arrays)
				surfaces.append({"slot": slot, "material": mat_key, "tile": tile_arrays.tile})
		else:
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			surfaces.append({"slot": slot, "material": mat_key, "tile": -1})
	for i in out.get_surface_count():
		out.surface_set_name(i, "%s_%d" % [surfaces[i].material, surfaces[i].tile])
	var res_path := BASE + "built/meshes/%s.res" % name
	ResourceSaver.save(out, res_path, ResourceSaver.FLAG_COMPRESS)
	scene.free()
	return {"mesh": load(res_path), "xf": xf, "surfaces": surfaces}


func _is_udim(mat_name: String) -> bool:
	var m: Dictionary = manifest.materials.get(mat_name, {})
	for t in m.get("textures", {}).values():
		if tex_files.has(t + "_1001"):
			return true
	return false


func _split_udim(arrays: Array) -> Array:
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices = PackedInt32Array(range(uvs.size()))
	var buckets := {}
	for t in range(0, indices.size(), 3):
		var a := indices[t]
		var b := indices[t + 1]
		var c := indices[t + 2]
		var tile := int(floor((uvs[a].x + uvs[b].x + uvs[c].x) / 3.0))
		if not buckets.has(tile):
			buckets[tile] = {"map": {}, "verts": PackedInt32Array(), "indices": PackedInt32Array()}
		var bucket: Dictionary = buckets[tile]
		for v in [a, b, c]:
			if not bucket.map.has(v):
				bucket.map[v] = bucket.verts.size()
				bucket.verts.append(v)
			bucket.indices.append(bucket.map[v])
	var tiles := buckets.keys()
	tiles.sort()
	var result := []
	for tile in tiles:
		var bucket: Dictionary = buckets[tile]
		result.append({"tile": 1001 + tile, "arrays": _subset(arrays, bucket.verts, bucket.indices, tile)})
	return result


func _subset(src: Array, verts: PackedInt32Array, indices: PackedInt32Array, tile: int) -> Array:
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	var pos: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var p := PackedVector3Array()
	for v in verts:
		p.append(pos[v])
	out[Mesh.ARRAY_VERTEX] = p
	if src[Mesh.ARRAY_NORMAL] != null:
		var a: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
		var r := PackedVector3Array()
		for v in verts:
			r.append(a[v])
		out[Mesh.ARRAY_NORMAL] = r
	if src[Mesh.ARRAY_TANGENT] != null:
		var a: PackedFloat32Array = src[Mesh.ARRAY_TANGENT]
		var r := PackedFloat32Array()
		for v in verts:
			for k in 4:
				r.append(a[v * 4 + k])
		out[Mesh.ARRAY_TANGENT] = r
	if src[Mesh.ARRAY_COLOR] != null:
		var a: PackedColorArray = src[Mesh.ARRAY_COLOR]
		var r := PackedColorArray()
		for v in verts:
			r.append(a[v])
		out[Mesh.ARRAY_COLOR] = r
	var uv_src: PackedVector2Array = src[Mesh.ARRAY_TEX_UV]
	var uv := PackedVector2Array()
	for v in verts:
		uv.append(uv_src[v] - Vector2(tile, 0))
	out[Mesh.ARRAY_TEX_UV] = uv
	if src[Mesh.ARRAY_TEX_UV2] != null:
		var a: PackedVector2Array = src[Mesh.ARRAY_TEX_UV2]
		var r := PackedVector2Array()
		for v in verts:
			r.append(a[v])
		out[Mesh.ARRAY_TEX_UV2] = r
	out[Mesh.ARRAY_INDEX] = indices
	return out


# ---------------------------------------------------------------- materiais

func _material(mat_name: String, tile: int) -> Material:
	var key := mat_name if tile < 0 else "%s_%d" % [mat_name, tile]
	if material_cache.has(key):
		return material_cache[key]
	var path := BASE + "built/materials/%s.tres" % key
	var mat: Material
	if ResourceLoader.exists(path):
		mat = load(path)
	else:
		mat = _make_material(mat_name, tile)
		mat.resource_name = key
		ResourceSaver.save(mat, path)
		mat = load(path)
	material_cache[key] = mat
	return mat


func _tex(m: Dictionary, keys: Array, tile: int) -> Texture2D:
	for k in keys:
		if m.textures.has(k):
			var name: String = m.textures[k]
			var file := name if tile < 0 else "%s_%d" % [name, tile]
			if tex_files.has(file):
				return load(BASE + "textures/%s.png" % file)
	return null


func _first(d: Dictionary, keys: Array, default: Variant) -> Variant:
	for k in keys:
		if d.has(k):
			return d[k]
	return default


func _make_material(mat_name: String, tile: int) -> BaseMaterial3D:
	var m: Dictionary = manifest.materials.get(mat_name, {"base": "", "blend": "", "two_sided": false, "scalars": {}, "vectors": {}, "textures": {}})
	var blend: String = m.blend

	if blend.contains("TRANSLUCENT"):
		var glass := StandardMaterial3D.new()
		var c: Array = _first(m.vectors, ["ColorGlass"], [0.6, 0.65, 0.7, 1.0])
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.albedo_color = Color(c[0], c[1], c[2], float(_first(m.scalars, ["Opacity"], 0.25)))
		glass.metallic = 0.0
		glass.roughness = 0.05
		glass.metallic_specular = 0.8
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		return glass

	var mat: BaseMaterial3D
	var orm := _tex(m, ORM_KEYS, tile)
	if orm:
		mat = ORMMaterial3D.new()
		mat.orm_texture = orm
	else:
		mat = StandardMaterial3D.new()
		var rma := _tex(m, ["RMA"], tile)
		var srmh := _tex(m, ["SRMH"], tile)
		if rma:
			mat.roughness_texture = rma
			mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			mat.metallic = 1.0
			mat.metallic_texture = rma
			mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
			mat.ao_enabled = true
			mat.ao_texture = rma
			mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		elif srmh:
			mat.roughness_texture = srmh
			mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
			mat.metallic = 1.0
			mat.metallic_texture = srmh
			mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	mat.albedo_texture = _tex(m, ALBEDO_KEYS, tile)
	var normal := _tex(m, NORMAL_KEYS, tile)
	if normal:
		mat.normal_enabled = true
		mat.normal_texture = normal

	if not (m.base in NO_EMISSION_BASES):
		var c: Array = _first(m.vectors, EMISSION_COLOR_KEYS, [1.0, 1.0, 1.0, 1.0])
		var mult := float(_first(m.scalars, EMISSION_MULT_KEYS, 1.0))
		var emissive := _tex(m, EMISSIVE_KEYS, tile)
		# M_Master_Standard (YI_Props) liga uma "emissiva" genérica (logo T_Albedo) e a esconde
		# com EmissiveMask; só vale a emissiva própria do aparelho (*_Emissive).
		if emissive and m.base == "M_Master_Standard" and not String(m.textures.get("Emissive", "")).ends_with("_Emissive"):
			emissive = null
		if emissive:
			mat.emission_enabled = true
			mat.emission = Color(c[0], c[1], c[2])
			mat.emission_texture = emissive
			mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			mat.emission_energy_multiplier = mult
		elif m.base == "M_BaseLight":
			mat.emission_enabled = true
			mat.emission = Color(c[0], c[1], c[2])
			mat.emission_energy_multiplier = mult * 0.1
	if m.two_sided:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if blend.contains("MASKED"):
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat
