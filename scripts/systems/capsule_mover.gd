extends CharacterBody3D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	

@export var grid_size: float = 2.0        # Distância exata de cada "bloco" no mapa
@export var step_time: float = 0.4        # Tempo (em segundos) que leva para andar ou girar

var is_moving: bool = false               # Impede novos comandos durante a animação

func _unhandled_input(event: InputEvent) -> void:
	# Se já estiver se movendo ou girando, ignora novos comandos
	if is_moving:
		return
		
	if event.is_action_pressed("move_forward"):
		move_in_direction(-transform.basis.z) # No Godot, -Z é para frente
		
	elif event.is_action_pressed("move_backward"):
		move_in_direction(transform.basis.z)  # +Z é para trás
		
	elif event.is_action_pressed("turn_left"):
		rotate_player(90.0) # Gira 90 graus para a esquerda
		
	elif event.is_action_pressed("turn_right"):
		rotate_player(-90.0) # Gira 90 graus para a direita


# Função que calcula a nova posição e move suavemente
func move_in_direction(direction: Vector3) -> void:
	is_moving = true
	
	# Calcula o ponto exato de destino baseado no tamanho da grade
	var target_position: Vector3 = global_position + (direction.normalized() * grid_size)
	
	# Cria um Tween para suavizar o movimento
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD) # Tipo de transição (suave no início/fim)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Altera a propriedade 'global_position' até o destino
	tween.tween_property(self, "global_position", target_position, step_time)
	
	# Libera os controles quando o movimento terminar
	tween.tween_callback(func(): is_moving = false)


# Função que calcula a nova rotação e gira suavemente
func rotate_player(deg_angle: float) -> void:
	is_moving = true
	
	# Converte graus para radianos e calcula a nova rotação Y
	var target_rotation_y: float = rotation.y + deg_to_rad(deg_angle)
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Altera a propriedade 'rotation:y' para girar a cápsula
	tween.tween_property(self, "rotation:y", target_rotation_y, step_time)
	
	tween.tween_callback(func(): is_moving = false)
