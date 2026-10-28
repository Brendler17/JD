extends Node
## Autoload global de sinais (Observer / Event-Driven Architecture).
## Nenhum nó deve conhecer diretamente quem emite ou escuta estes sinais:
## a UI, a Capsule e os sistemas de estado se comunicam apenas por aqui.

# --- Intenções vindas da UI (painel de navegação) ---
signal request_move_forward
signal request_move_backward
signal request_rotate_left
signal request_rotate_right
signal request_sonar_ping

# --- Intenções vindas de objetos interativos da cabine (Interactable) ---
## Abre o visualizador de texto (anotações, etiquetas, equipamentos).
signal request_show_note(title: String, body: String)
## Senta no posto de comando: troca do controle em 1ª pessoa para o controle da cápsula.
signal request_enter_navigation

# --- Fatos do jogador em 1ª pessoa / modos de controle ---
## O que está sob a mira mudou ("" = nada interativo).
signal interaction_prompt_changed(prompt: String)
## O visualizador de texto foi fechado.
signal note_closed
## true = controlando a cápsula pelo painel; false = andando em 1ª pessoa.
signal navigation_mode_changed(active: bool)

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
## Pulso de sonar emitido de `origin`: `hits` traz o primeiro obstáculo atingido
## em cada uma das 4 direções (pode estar fora dos limites do labirinto).
signal sonar_pinged(origin: Vector2i, hits: Array[Vector2i])

# --- Fatos emitidos pelo Enemy ---
## Distância (em passos pelo labirinto) entre o inimigo e a cápsula, após cada turno.
## -1 = sem caminho entre os dois.
signal enemy_proximity_changed(steps: int)
## Um pulso de sonar passou pelo inimigo antes de atingir uma parede: eco não identificado.
signal enemy_detected(cell: Vector2i)
## O inimigo alcançou a cápsula (derrota).
signal capsule_caught(cell: Vector2i)

# --- Fatos emitidos pelo AlarmSystem ---
## `reason`: &"enemy" (inimigo próximo) ou &"low_oxygen" (oxigênio baixo).
signal alarm_started(reason: StringName)
signal alarm_stopped(reason: StringName)

# --- Fatos emitidos por sistemas de estado/recursos ---
signal oxygen_changed(current: float, maximum: float)
## Fim da partida: vitória (chegou à saída) ou derrota (oxigênio esgotado).
signal game_over(won: bool)
