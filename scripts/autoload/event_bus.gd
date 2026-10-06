extends Node
## Autoload global de sinais (Observer / Event-Driven Architecture).
## Nenhum nó deve conhecer diretamente quem emite ou escuta estes sinais:
## a UI, a Capsule e os sistemas de estado se comunicam apenas por aqui.

# --- Intenções vindas da UI (painel de movimentação) ---
signal request_move_forward
signal request_rotate_left
signal request_rotate_right

# --- Intenções vindas da UI (fluxo de partida) ---
signal request_restart

# --- Fatos emitidos pela Capsule após executar uma ação ---
signal capsule_moved(new_position: Vector2i, direction: Vector2i)
signal capsule_rotated(new_direction: Vector2i)
## Tentou andar para uma célula bloqueada (parede ou fora do labirinto); a cápsula não se moveu.
signal capsule_collided(blocked_cell: Vector2i, direction: Vector2i)
## Entrou na célula de saída. Emitido ANTES de capsule_moved desse mesmo passo,
## para que chegar à saída tenha prioridade sobre o custo de oxigênio do passo.
signal capsule_reached_exit(exit_cell: Vector2i)

# --- Fatos emitidos por sistemas de estado/recursos ---
signal oxygen_changed(current: float, maximum: float)
## Fim da partida: vitória (chegou à saída) ou derrota (oxigênio esgotado).
signal game_over(won: bool)
