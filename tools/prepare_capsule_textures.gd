extends SceneTree
## Reduz as texturas exportadas da Unreal para no máximo MAX_SIZE e copia para o projeto.
## Renomeia blocos UDIM (NOME.1001.png -> NOME_1001.png) e descarta blocos emissivos
## totalmente pretos.
##
## Uso:
##   Godot --headless --path . --script res://tools/prepare_capsule_textures.gd -- <pasta_export>
## <pasta_export> é a saída de tools/unreal_export_capsule.py (com textures/ e manifest.json).

const MAX_SIZE := 1024
const DEST := "res://assets/imports/capsule/"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("informe a pasta do export")
		quit(1)
		return
	var src: String = args[0].replace("\\", "/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST + "textures"))
	DirAccess.copy_absolute(src + "/manifest.json", ProjectSettings.globalize_path(DEST + "manifest.json"))

	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(src + "/manifest.json"))
	var emissive_names := {}
	for m in manifest.materials.values():
		for key in ["Emissive", "EmColor", "emmisive"]:
			if m.textures.has(key):
				emissive_names[m.textures[key]] = true

	var count := 0
	var skipped := 0
	for file in DirAccess.get_files_at(src + "/textures"):
		if not file.ends_with(".png"):
			continue
		var out_name := file
		var re := RegEx.create_from_string("^(.*)\\.(\\d{4})\\.png$")
		var m := re.search(file)
		var base := file.get_basename()
		if m:
			base = m.get_string(1)
			out_name = "%s_%s.png" % [m.get_string(1), m.get_string(2)]
		var img := Image.load_from_file(src + "/textures/" + file)
		if img == null:
			push_error("falha ao ler " + file)
			continue
		if emissive_names.has(base) and _is_black(img):
			skipped += 1
			continue
		var w := img.get_width()
		var h := img.get_height()
		if maxi(w, h) > MAX_SIZE:
			var f := float(MAX_SIZE) / maxi(w, h)
			img.resize(maxi(1, int(w * f)), maxi(1, int(h * f)), Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path(DEST + "textures/" + out_name))
		count += 1
	print("texturas: %d gravadas, %d emissivas pretas descartadas" % [count, skipped])
	quit()


func _is_black(img: Image) -> bool:
	var small := img.duplicate() as Image
	small.resize(16, 16, Image.INTERPOLATE_BILINEAR)
	for y in 16:
		for x in 16:
			var c := small.get_pixel(x, y)
			if c.r + c.g + c.b > 0.01:
				return false
	return true
