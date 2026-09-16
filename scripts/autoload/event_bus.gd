extends Node
## Autoload global de sinais (Observer / Event-Driven Architecture).
## Nenhum nó deve conhecer diretamente quem emite ou escuta estes sinais:
## a UI, a Capsule e os sistemas de estado se comunicam apenas por aqui.

# --- Intenções vindas da UI (painel de movimentação) ---
signal request_move_forward
signal request_rotate_left
signal request_rotate_right

# --- Fatos emitidos pela Capsule após executar uma ação ---
signal capsule_moved(new_position: Vector2i, direction: Vector2i)
signal capsule_rotated(new_direction: Vector2i)

# --- Fatos emitidos por sistemas de estado/recursos ---
signal oxygen_changed(new_value: float)
