class_name CabinFx
extends RefCounted
## Efeitos de energia da cabine compartilhados pelas sequências de apresentação
## (CaughtSequence, EndingSequence): luzes de teto, telas do painel (PanelScreen)
## e rótulos 3D das teclas. Guarda a energia original de cada luz para restaurar.
## A luz de alarme fica fora da lista (cada sequência decide o que fazer com ela).

var lights: Array[Light3D] = []
var base_energy := {}
var screens: Array[PanelScreen] = []
## Rótulos 3D das teclas e do knob (sem sombreamento: brilhariam no escuro).
var labels: Array[Label3D] = []


static func collect(cabin_lights: Node3D, alarm_light: Light3D, command_panel: Node3D) -> CabinFx:
	var fx := CabinFx.new()
	for node in cabin_lights.get_children():
		if node is Light3D and node != alarm_light:
			fx.lights.append(node)
			fx.base_energy[node] = (node as Light3D).light_energy
	for node in command_panel.find_children("*", "", true, false):
		if node is PanelScreen:
			fx.screens.append(node)
		elif node is Label3D:
			fx.labels.append(node)
	return fx


## Uma "falha" aleatória: cada luz/tela/rótulo apaga com chance `failing`; as que
## ficam acesas oscilam dentro das faixas (multiplicador da energia / power da tela).
## `scale` multiplica tudo (queda de energia geral).
func flicker(failing: float, light_range: Vector2, screen_range: Vector2, off_power := 0.05, scale := 1.0) -> void:
	for light in lights:
		light.light_energy = 0.0 if randf() < failing \
				else base_energy[light] * randf_range(light_range.x, light_range.y) * scale
	for screen in screens:
		screen.power = off_power if randf() < failing else randf_range(screen_range.x, screen_range.y) * scale
	for label in labels:
		label.visible = randf() >= failing


## Todas as luzes em `light_scale` × energia original e todas as telas em `screen_power`.
func set_level(light_scale: float, screen_power: float) -> void:
	for light in lights:
		light.light_energy = base_energy[light] * light_scale
	for screen in screens:
		screen.power = screen_power
	for label in labels:
		label.visible = screen_power > 0.05


func restore() -> void:
	set_level(1.0, 1.0)


func blackout() -> void:
	set_level(0.0, 0.0)
