extends SceneTree
## Gera assets/textures/fx/smoke_puff.png: tufo de fumaça branco com alfa suave
## (ruído fractal recortado por uma queda radial), usado pelas partículas de névoa.
##
## Uso: Godot --headless --path . --script res://tools/gen_smoke_texture.gd

const SIZE := 256
const OUT := "res://assets/textures/fx/smoke_puff.png"


func _init() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	noise.frequency = 0.012
	noise.seed = 7
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(SIZE, SIZE) * 0.5
	for y in SIZE:
		for x in SIZE:
			var d := Vector2(x, y).distance_to(center) / (SIZE * 0.5)
			var radial := clampf(1.0 - d, 0.0, 1.0)
			radial = radial * radial * (3.0 - 2.0 * radial)  # smoothstep
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5  # 0..1
			var a := clampf(radial * (0.6 + n * 0.8) - 0.05, 0.0, 1.0)
			var v := 0.85 + n * 0.15
			img.set_pixel(x, y, Color(v, v, v, a))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("textura salva em ", OUT)
	quit()
