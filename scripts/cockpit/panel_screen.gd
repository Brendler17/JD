class_name PanelScreen
extends Node3D
## Tela diegética do cockpit: renderiza uma cena 2D (Control) num SubViewport e a
## exibe num quad 3D posicionado sobre a malha da cabine (que, por ser um atlas
## mesclado, tem as telas originais em baixa resolução).
## O quad fica no plano XY local, virado para +Z local; `size` é em metros.
## Se `interactive`, ganha uma Area3D na camada de painel (PANEL_LAYER): o jogador
## faz o raycast do cursor e chama forward_mouse() com o ponto atingido, e a tela
## converte esse ponto em pixel e injeta o evento no SubViewport — os Controls de
## dentro (botões etc.) funcionam como numa UI 2D comum.

## Camada de colisão das telas clicáveis (layer 4). Lida pelo Player no posto.
const PANEL_LAYER := 1 << 3

## Cena 2D exibida na tela (raiz Control, ocupando todo o viewport).
@export var content: PackedScene
## Tamanho do quad em metros.
@export var size := Vector2(0.4, 0.3)
## Resolução do SubViewport em pixels (manter a proporção de `size`).
@export var resolution := Vector2i(512, 384)
## Recebe cliques/hover do cursor quando o jogador está no posto.
@export var interactive := false
## Fundo transparente (ex.: mostradores redondos, onde só o desenho aparece).
@export var transparent := false
## Multiplica o brilho da tela (valores > 1 "estouram" levemente, efeito de tela acesa).
@export_range(0.0, 4.0) var brightness := 1.0

var viewport: SubViewport
## Raiz instanciada de `content` (para quem precisa injetar dados, ex.: o labirinto).
var content_node: Node

var _last_pixel := Vector2(-1.0, -1.0)


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = resolution
	viewport.transparent_bg = transparent
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input = not interactive
	viewport.handle_input_locally = true
	add_child(viewport)
	if content:
		content_node = content.instantiate()
		viewport.add_child(content_node)

	var quad := QuadMesh.new()
	quad.size = size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = viewport.get_texture()
	material.albedo_color = Color(brightness, brightness, brightness)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)

	if interactive:
		var area := Area3D.new()
		area.collision_layer = PANEL_LAYER
		area.collision_mask = 0
		area.monitoring = false
		area.monitorable = false
		area.input_ray_pickable = false
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(size.x, size.y, 0.01)
		shape.shape = box
		area.add_child(shape)
		add_child(area)


## Converte um ponto 3D (sobre o quad) no pixel correspondente do SubViewport.
func world_to_pixel(world_position: Vector3) -> Vector2:
	var local := to_local(world_position)
	var uv := Vector2(local.x / size.x + 0.5, 0.5 - local.y / size.y)
	return uv * Vector2(resolution)


## Injeta um evento de mouse da tela do jogo no SubViewport, no ponto atingido.
func forward_mouse(event: InputEventMouse, world_position: Vector3) -> void:
	var pixel := world_to_pixel(world_position)
	var local_event := event.duplicate() as InputEventMouse
	local_event.position = pixel
	local_event.global_position = pixel
	if local_event is InputEventMouseMotion:
		(local_event as InputEventMouseMotion).relative = pixel - _last_pixel if _last_pixel.x >= 0.0 else Vector2.ZERO
	_last_pixel = pixel
	viewport.push_input(local_event)


## O cursor saiu da tela: tira o hover dos Controls (evento de movimento fora da área).
func release_hover() -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(-100.0, -100.0)
	motion.global_position = motion.position
	_last_pixel = Vector2(-1.0, -1.0)
	viewport.push_input(motion)
