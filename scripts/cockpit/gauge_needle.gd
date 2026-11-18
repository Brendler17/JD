class_name GaugeNeedle
extends Node3D
## Relógio do painel com o ponteiro original da malha (SM_Devices01).
## No _ready, o ponteiro modelado é retirado da malha do painel (PanelMeshParts) e
## passa a girar em volta do eixo do relógio. O nó fica no centro do mostrador,
## com +Z saindo do vidro em direção ao jogador e +Y apontando para cima no
## mostrador (posição de repouso do ponteiro modelado).
## O eixo exato é recalculado a partir da peça: o centro do disco na base do
## ponteiro (largura da peça = diâmetro do disco). O nó se desloca para esse eixo,
## levando junto os filhos (ex.: a impressão da faixa vermelha).
## O ponteiro varre `sweep_degrees` em sentido horário: posição 0 embaixo à
## esquerda, 1 embaixo à direita. Padrão dos dois relógios: **perigo sempre à
## direita** (faixa vermelha impressa em 0,75–1,0, ver gauge_dial.gd).
##   OXYGEN       → nível de O₂ (oxygen_changed), com a escala invertida: tanque
##                  cheio à esquerda, o ponteiro sobe para o vermelho conforme o ar acaba.
##   INTERFERENCE → proximidade do inimigo (enemy_proximity_changed); o ponteiro
##                  treme mais quanto mais perto, como um sensor sob interferência.
## "Dumb UI": só reflete sinais do EventBus.

enum Kind { OXYGEN, INTERFERENCE }

## A partir desta distância (em passos) a interferência é zero.
const INTERFERENCE_RANGE := 8.0

@export var kind := Kind.OXYGEN
## Arco total varrido pelo ponteiro, em graus (centrado no topo do mostrador).
@export var sweep_degrees := 270.0
## Raio de busca do ponteiro modelado em volta do centro (m).
@export var search_radius := 0.17
## Maior dimensão aceita para a peça do ponteiro (m): descarta o miolo e o mostrador.
@export var needle_extent := Vector2(0.12, 0.2)

## Valor alvo (0..1) e valor exibido, suavizado para o ponteiro "andar".
var _target := 1.0
var _shown := 1.0
var _time := 0.0
## Gira em volta do eixo (origem do nó); o ponteiro fica nele, deslocado pelo pivô.
var _pivot: Node3D
var _needle: MeshInstance3D


func _ready() -> void:
	_build_needle()
	if kind == Kind.OXYGEN:
		EventBus.oxygen_changed.connect(_on_oxygen_changed)
		_on_oxygen_changed(GameState.oxygen, GameState.MAX_OXYGEN)
	else:
		_target = 0.0
		EventBus.enemy_proximity_changed.connect(_on_enemy_proximity_changed)
	_shown = _target
	_apply()


func _build_needle() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_needle = MeshInstance3D.new()
	_needle.name = "Needle"
	_needle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(_needle)
	var panel := PanelMeshParts.find_panel_mesh(get_tree())
	if panel == null:
		push_warning("GaugeNeedle: malha do painel (grupo panel_mesh) não encontrada.")
		return
	_needle.mesh = PanelMeshParts.extract_component(panel, global_position, search_radius,
			needle_extent.x, needle_extent.y, 400, global_transform)
	if _needle.mesh.get_surface_count() == 0:
		push_warning("GaugeNeedle: ponteiro não encontrado perto de %s." % global_position)
		return
	# Ponteiro em repouso aponta para +Y: o disco da base fica no fundo da peça.
	var box := _needle.mesh.get_aabb()
	var pivot := Vector3(box.get_center().x, box.position.y + box.size.x * 0.5, 0.0)
	position += basis * pivot
	_needle.position = -pivot


func _process(delta: float) -> void:
	_time += delta
	_shown = lerpf(_shown, _target, 1.0 - exp(-delta * 5.0))
	_apply()


func _on_oxygen_changed(current: float, maximum: float) -> void:
	_target = clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0


func _on_enemy_proximity_changed(steps: int) -> void:
	_target = 0.0 if steps < 0 else clampf(1.0 - float(steps - 1) / INTERFERENCE_RANGE, 0.0, 1.0)


## Posição do ponteiro no arco (0 = início à esquerda, 1 = fim do vermelho à direita).
func needle_position() -> float:
	# O₂ invertido: cheio (1) fica à esquerda (posição 0).
	var value := 1.0 - _shown if kind == Kind.OXYGEN else _shown
	if kind == Kind.INTERFERENCE and _shown > 0.02:
		value += sin(_time * 37.0) * 0.04 * _shown + sin(_time * 13.0) * 0.02 * _shown
	return clampf(value, 0.0, 1.02)


func _apply() -> void:
	# Rotação positiva em Z é anti-horária para quem olha o mostrador: posição 0,5 = topo.
	_pivot.rotation.z = deg_to_rad((0.5 - needle_position()) * sweep_degrees)
