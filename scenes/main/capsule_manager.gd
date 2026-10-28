extends CharacterBody3D
var travel_distance: float = 1.0
var rotation_angle: float = deg_to_rad(90.0)
var capsule_rotation: Vector3 = Vector3(0.0, 0.0, 0.0)

@export var speed = 4.0
@export var turn_speed = 1.0

# Called when the node enters the scene tree for the first time.
func _ready():
	print(position.x)
	print(rotation.y)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("move_forward"):
		#position.x = position.x + travel_distance
		print(position.x)
		
	if Input.is_action_just_pressed("move_backward"):
		position.x = position.x - travel_distance
		print(position.x)
		
	if Input.is_action_just_pressed("rotate_left"):
		#TODO ver como truncar o valor da rotação, tem uma leve variação no float que pode acumular e causar erro quando acumulados
		rotate_y(-rotation_angle)
		print(rotation.y)
		
	if Input.is_action_just_pressed("rotate_right"):
		#TODO ver como truncar o valor da rotação, tem uma leve variação no float que pode acumular e causar erro quando acumulados
		rotate_y(rotation_angle)
		print(rotation.y)
		
	pass


#func _physics_process(delta):
	#get_input(delta)
	#move_and_slide()
	#
	#
#func get_input(delta):
	#var vy = velocity.y
	#velocity = Vector3.ZERO
	#var move = Input.get_axis("move_backward", "move_forward")
	#var turn = Input.get_axis("rotate_right", "rotate_left")
	#velocity += transform.basis.z * move * speed
	#rotate_y(turn_speed * turn * delta)
	#velocity.y = vy
