class_name CabinGlow
extends Node
## Superfícies emissivas da cabine (faixas e luminárias do teto, telas e LEDs dos
## aparelhos) que dependem da energia. Fica dentro de CabinLights: o CabinFx a recolhe e
## controla `level` como faz com a energia das Light3D (falhas, apagão, restauração).
##
## Com `follow_alarm`, acompanha a luz de perigo: enquanto houver alarme ativo
## (EventBus.alarm_started/alarm_stopped) a emissão e as `tinted_lights` passam para
## vermelho e pulsam junto com a `alarm_light`; ao fim do alarme voltam às cores originais.
##
## No _ready troca, nas malhas sob `roots`, cada material de `materials` por uma cópia
## desta cena: mexer na emissão não altera o recurso em cache (que voltaria alterado
## num reinício).

const ALARM_COLOR := Color(1.0, 0.07, 0.03)
## Velocidade da transição de cor (fração por segundo).
const TINT_SPEED := 2.5
## Brilho mínimo da emissão no vale do pulso do alarme.
const PULSE_FLOOR := 0.3

@export var roots: Array[Node3D] = []
@export var materials: Array[BaseMaterial3D] = []
@export var follow_alarm := false
@export var alarm_light: Light3D
## Luzes reais que mudam de cor com o alarme (a energia continua com o CabinFx).
@export var tinted_lights: Array[Light3D] = []
## Névoa do ambiente: acompanha `level` (sem luz, a névoa também escurece) e, com o
## alarme, puxa para vermelho escuro. Lido a cada aplicação porque as sequências trocam
## o Environment por uma cópia.
@export var world_environment: WorldEnvironment

## Multiplicador da emissão original (1 = normal, 0 = apagada).
var level := 1.0:
	set(value):
		level = value
		_apply()

var _copies := {}  # material original -> cópia
var _base := {}  # cópia -> [energia, cor]
var _light_colors := {}  # Light3D -> cor original
var _reasons := {}
var _tint := 0.0
var _fog_energy := 0.0
var _fog_color := Color.BLACK


func _ready() -> void:
	for m in materials:
		if m == null:
			continue
		var copy := m.duplicate() as BaseMaterial3D
		_copies[m] = copy
		_base[copy] = [m.emission_energy_multiplier, m.emission]
	for root in roots:
		if root == null:
			continue
		for node in root.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			for s in mi.get_surface_override_material_count():
				var current := mi.get_surface_override_material(s)
				if current == null and mi.mesh:
					current = mi.mesh.surface_get_material(s)
				if _copies.has(current):
					mi.set_surface_override_material(s, _copies[current])
	for light in tinted_lights:
		if light:
			_light_colors[light] = light.light_color
	if world_environment and world_environment.environment:
		_fog_energy = world_environment.environment.fog_light_energy
		_fog_color = world_environment.environment.fog_light_color
	if follow_alarm:
		EventBus.alarm_started.connect(func(reason: StringName) -> void: _reasons[reason] = true)
		EventBus.alarm_stopped.connect(func(reason: StringName) -> void: _reasons.erase(reason))
	set_process(follow_alarm)


func _process(delta: float) -> void:
	var target := 0.0 if _reasons.is_empty() else 1.0
	if is_equal_approx(_tint, target) and target == 0.0:
		return
	_tint = move_toward(_tint, target, delta * TINT_SPEED)
	_apply()


func _apply() -> void:
	var pulse := 1.0
	if _tint > 0.0 and alarm_light:
		var max_energy: float = alarm_light.get("max_energy") if alarm_light.get("max_energy") != null else 1.0
		var strobe := clampf(alarm_light.light_energy / maxf(max_energy, 0.01), 0.0, 1.0)
		pulse = lerpf(1.0, lerpf(PULSE_FLOOR, 1.0, strobe), _tint)
	for copy: BaseMaterial3D in _base:
		var base: Array = _base[copy]
		copy.emission_energy_multiplier = base[0] * level * pulse
		copy.emission = (base[1] as Color).lerp(ALARM_COLOR, _tint)
	for light: Light3D in _light_colors:
		light.light_color = (_light_colors[light] as Color).lerp(ALARM_COLOR, _tint)
	if world_environment and world_environment.environment and _fog_energy > 0.0:
		var env := world_environment.environment
		env.fog_light_energy = _fog_energy * level
		var alarm_fog := Color(ALARM_COLOR.r * 0.45, ALARM_COLOR.g * 0.45, ALARM_COLOR.b * 0.45)
		env.fog_light_color = _fog_color.lerp(alarm_fog, _tint * 0.7)
