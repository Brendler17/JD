# Technical Design Document — Profundidade Zero

> Documento vivo. Deve ser atualizado a cada nova mecânica, sistema ou decisão técnica implementada/discutida ao longo do desenvolvimento. Ver também [`one-sheet.md`](one-sheet.md) (pitch resumido) e [`GDD.md`](GDD.md) (documento de design irmão).

## 1. Stack & Engine

- **Engine:** Godot 4.7 (GL Compatibility renderer).
- **Linguagem:** GDScript.
- **Plataformas alvo:** PC (Windows/Linux); web (itch.io) como meta secundária.

## 2. Arquitetura Geral

Baseada em **Autoloads (Singletons)** para estado/serviços globais + **cenas instanciadas** para o gameplay em si, comunicando-se por **sinais** (Observer / Event-Driven Architecture), evitando acoplamento direto entre nós.

```
Autoloads (Singletons) — persistem entre cenas
├── EventBus       → sinais globais do jogo (Observer / Event Bus)
├── GameState      → estado do jogo (State Pattern)
└── AudioManager   → toca áudio conforme sinais do EventBus

Cena: Cápsula — instanciada a cada partida
├── Capsule        → recebe input do painel, emite sinais via EventBus
├── SonarSystem    → calcula distância/risco do sonar
├── MazeGrid (Resource) → grade do labirinto (dados, fonte de verdade das regras)
├── MazeBuilder    → constrói o labirinto em 3D a partir da MazeGrid (só visual)
└── Enemy          → reage ao uso do sonar
```

*(Diagrama de origem: `classes.svg`. Manter este documento sincronizado se o diagrama mudar.)*

### 2.1 Espaço lógico (grade) x espaço 3D

O jogo é **3D desde a base**: a cápsula e o labirinto existem no mundo 3D, sem nenhuma representação 2D paralela sendo espelhada a cada movimento.

- **Fonte de verdade da posição:** a célula lógica da grade (`Vector2i`), guardada na Capsule (`grid_position`). Regras de jogo (movimento, colisão com paredes via `MazeGrid`, sonar) operam sobre a grade — consultas em matriz, O(1) e determinísticas.
- **Representação:** a posição 3D é derivada da célula via `Grid.grid_to_world()` (`scripts/systems/grid.gd`) a cada mudança; não há física 3D (raycast/`CharacterBody3D`) na movimentação.
- **Mapeamento de eixos:** coluna `x` → eixo X do mundo; linha `y` → eixo Z do mundo; o centro da célula fica em `(x, 0, y) * CELL_SIZE`. "Cima" na matriz (`y - 1`) coincide com o "frente" padrão do Godot (`-Z`).
- **Tamanho da célula:** `Grid.CELL_SIZE = 4.0` metros — constante única, compartilhada por Capsule, chão de debug e `MazeBuilder`.

## 3. Padrões de Projeto (Design Patterns)

| Padrão | Onde é usado | Motivo |
|---|---|---|
| Observer / Event Bus | `EventBus` autoload | Desacoplar emissores (Capsule, SonarSystem) de consumidores (GameState, AudioManager) |
| State Pattern | `GameState` | Controlar estados do jogo (menu, jogando, morto, vitória, etc.) |
| Resource | `MazeGrid` | Representar a grade do labirinto como dado serializável, independente de nós de cena |

*(A detalhar conforme mais sistemas forem implementados: Component Pattern, Object Pooling, etc., se/quando forem adotados.)*

## 4. Estrutura de Pastas

```
scripts/
├── autoload/   → EventBus, GameState, AudioManager
├── systems/    → SonarSystem, MazeGrid e outros sistemas de gameplay
├── entities/   → Capsule, Enemy
└── ui/         → painel de movimentação e demais telas
scenes/
├── main/       → cena principal
├── entities/   → cena da Cápsula, Enemy
├── levels/     → cenas de labirinto/nível
└── ui/         → painel de botões, HUD
```

## 5. Sistema de Movimentação (Painel de Botões)

A cápsula **não** é controlada por teclado. O input vem de um **painel de UI** com 3 botões clicáveis (mouse):

| Botão | Efeito | Consome oxigênio? |
|---|---|---|
| Andar | Move a cápsula 1 célula para frente, na direção atual | Sim |
| Girar 90º Esquerda | Rotaciona a cápsula -90º, sem deslocamento | Não |
| Girar 90º Direita | Rotaciona a cápsula +90º, sem deslocamento | Não |

Notas técnicas:
- Movimentação em grade (grid-based), não livre — cada "Andar" desloca a cápsula por exatamente uma célula da `MazeGrid`.
- Rotação em incrementos fixos de 90º (4 direções possíveis: cima/baixo/esquerda/direita).
- Cada clique nos botões deve emitir um sinal via `EventBus` (ex.: `capsule_moved`, `capsule_rotated`, `capsule_collided`) para que `GameState`/`AudioManager` reajam sem acoplamento direto ao painel de UI.
- Consumo de oxigênio deve ser tratado pelo `GameState` (ou sistema de recursos dedicado) ouvindo o sinal de movimento — **não** diretamente pelo botão de UI, para manter a UI "burra" (dumb UI / thin view).
- **Implementação atual:** `scenes/ui/movement_panel.tscn` (`HBoxContainer` ancorado no centro-inferior da tela) + `scripts/ui/movement_panel.gd`. Os botões são acessados por nome único (`%RotateLeftButton`, `%MoveForwardButton`, `%RotateRightButton`) e o sinal `pressed` de cada um é conectado direto ao `emit` do sinal correspondente no `EventBus`. Os botões usam `focus_mode = NONE`, então teclado (Espaço/Enter) não aciona o painel — input é exclusivamente por mouse, como definido no design.
- Na `main.tscn`, o painel fica dentro de um `CanvasLayer` (`UI`) para ficar fixo na tela, independente de câmera; a `Capsule` é instanciada como filha direta de `Main`.
- **Capsule em 3D:** `Node3D`; rotação apenas no eixo Y. No Godot, `+Y` gira no sentido anti-horário visto de cima, então `RIGHT = -90º` e `LEFT = +90º` (`FACING_ROTATION_DEGREES`). Visual provisório: `Body` (caixa 1.8 × 1.2 × 2.2 m) + `Nose` (cone laranja apontando para `-Z`) para tornar a direção legível.
- **Movimento e rotação instantâneos** (sem tween) por enquanto — a animação entra junto com o trabalho de game feel.

### 5.1 Cena de debug (`main.tscn`)

Enquanto não há câmera de cockpit, a `main.tscn` é uma cena 3D de debug:
- `DebugCamera`: `Camera3D` **top-down fixa**, projeção **ortográfica** (`size = 76`), em `(30, 50, 34)` olhando para baixo (tela "cima" = `-Z` = "cima" na matriz).
- `DebugFloor`: `PlaneMesh` 64 × 64 m (16 × 16 células, cobrindo as células `0..15`) com o shader `assets/shaders/debug_grid.gdshader`, que desenha as bordas das células em coordenadas de mundo a partir de `cell_size`.
- `Sun` (`DirectionalLight3D`) + `WorldEnvironment` com fundo escuro e luz ambiente.
- A câmera final será em primeira pessoa dentro da cápsula; a câmera de debug deve virar um toggle de desenvolvimento quando ela existir.

### 5.2 Alvo final: cockpit em 1ª pessoa e interação por mira (planejado)

Ainda não implementado (depende de assets do interior da cápsula). Direção técnica prevista:
- `Camera3D` filha da `Capsule` (posição do "piloto"), com **mouse-look** limitado (yaw/pitch com limites) para olhar o interior da cabine; mouse capturado (`Input.MOUSE_MODE_CAPTURED`).
- **Mira:** um único `Control` (ponto) centralizado num `CanvasLayer` — é o único elemento 2D na tela.
- **Botões físicos:** cada botão do painel é um nó 3D com `Area3D`/`StaticBody3D` + um componente `InteractableButton` que, ao ser acionado, emite a **mesma intenção** de hoje no `EventBus` (`request_move_forward`, `request_rotate_left`, ...). Feedback (afundar o botão, clique sonoro) fica no próprio componente.
- **Detecção:** um `RayCast3D` a partir do centro da câmera (ou `PhysicsDirectSpaceState3D.intersect_ray`) identifica o botão sob a mira; o clique do mouse aciona o botão apontado. Destacar o botão sob a mira (hover) é desejável para legibilidade.
- Instrumentos (oxigênio etc.) migram para mostradores 3D na cabine que escutam os mesmos sinais (`oxygen_changed`, `game_over`) que a HUD 2D escuta hoje.
- **Consequência para a arquitetura atual:** como `MovementPanel`, `OxygenGauge` e `GameOverScreen` só falam com o `EventBus`, a troca para o cockpit é uma substituição da camada de apresentação — `Capsule`, `GameState` e `MazeGrid` não mudam.
- O mundo externo (labirinto em 3D) continua existindo para lógica/debug, mas não é visível de dentro da cápsula (cabine fechada).

*(A detalhar: valores exatos de consumo, se cliques repetidos rápidos são bloqueados durante a animação de movimento/rotação.)*

## 6. Sistema de Sonar

*(A detalhar: fórmula de cálculo de distância, alcance máximo, custo/cooldown, probabilidade de atrair o inimigo.)*

## 7. Sistema de Oxigênio

Implementado no autoload **`GameState`** (`scripts/autoload/game_state.gd`), que também controla o estado da partida.

### 7.1 Valores

| Constante | Valor |
|---|---|
| `MAX_OXYGEN` | 150 |
| `OXYGEN_COST_MOVE` | 1 por "Andar" bem-sucedido |
| `OXYGEN_COST_COLLISION` | 5 por "Andar" contra parede |

Girar não consome. Oxigênio é `float` (permite drenos fracionários futuros, ex.: por tempo) e é exibido arredondado para cima. Valores são constantes no script por enquanto; se o balanceamento exigir iteração frequente, migrar para um Resource de configuração.

### 7.2 Estados da partida (State Pattern via enum)

`enum State { PLAYING, WON, LOST }`. Só em `PLAYING` o oxigênio é consumido; qualquer evento após o fim é ignorado.

```
PLAYING ──capsule_reached_exit──▶ WON
PLAYING ──oxygen chega a 0──────▶ LOST
WON/LOST ──request_restart──────▶ PLAYING (recarrega a cena)
```

### 7.3 Fluxo de sinais

- **Escuta:** `capsule_moved` (−1), `capsule_collided` (−5), `capsule_reached_exit` (→ `WON`), `request_restart`.
- **Emite:** `oxygen_changed(current, maximum)` a cada alteração e `game_over(won)` ao encerrar.
- **Prioridade da saída:** a `Capsule` emite `capsule_reached_exit` **antes** de `capsule_moved` no passo que entra na saída. Assim o `GameState` já está em `WON` quando o custo do passo chega, e chegar à saída com o último ponto de oxigênio conta como vitória.
- **Reinício:** `request_restart` → `_start_run()` (zera estado e oxigênio, emite `oxygen_changed`) + `get_tree().reload_current_scene()`. Os nós da cena antiga são liberados e suas conexões com o `EventBus` são desfeitas automaticamente pelo Godot.
- O `GameState` não conhece Capsule, UI nem labirinto. As UIs podem **ler** `GameState.oxygen`/`MAX_OXYGEN` para inicializar (o primeiro `oxygen_changed` pode ocorrer antes de a UI existir), mas nunca escrevem nele.

### 7.4 UI de estado

- `scenes/ui/oxygen_gauge.tscn` (`OxygenGauge`, canto superior esquerdo): `Label` "O₂ atual / máximo" + `ProgressBar`; muda para a cor de alerta (vermelho) em ≤ 25% do máximo. Não captura mouse.
- `scenes/ui/game_over_screen.tscn` (`GameOverScreen`, tela cheia, oculta por padrão): escurece a tela e mostra título/subtítulo de vitória ou derrota e o botão "Tentar novamente", que emite `request_restart`.
- `MovementPanel` desabilita seus botões ao receber `game_over`.

## 8. Labirinto (MazeGrid)

Dividido em **dados** (`MazeGrid`) e **representação** (`MazeBuilder`), seguindo a regra de §2.1.

### 8.1 `MazeGrid` — `scripts/systems/maze_grid.gd` (Resource, `@tool`)

- O mapa é escrito como texto em `rows: PackedStringArray` — uma string por linha (`y`), um caractere por coluna (`x`):

| Caractere | `CellType` | Andável? |
|---|---|---|
| `#` | `WALL` | Não |
| `.` | `FLOOR` | Sim |
| `S` | `START` (exatamente 1) | Sim |
| `E` | `EXIT` (exatamente 1) | Sim |

- O setter de `rows` faz o parse para um array linear (`_cells[y * width + x]`), preenche `width`, `height`, `start_cell`, `exit_cell` e emite `changed`. Linhas de tamanhos diferentes, caracteres desconhecidos (tratados como parede) e quantidade errada de `S`/`E` geram erro/aviso no console.
- API: `get_cell()`, `is_inside()`, `is_walkable()`, `is_exit()`, `get_cells_of_type()`. **Fora dos limites conta como parede** — o labirinto nunca "vaza", mesmo sem borda de `#`.
- Formato textual escolhido por ser legível e editável direto no Inspector/`.tres`, e fácil de gerar por código no pós-MVP (o gerador procedural só precisa produzir as strings).
- MVP: `resources/maze_configs/campaign_01.tres` — 15 × 15, `S` em `(1, 13)`, `E` em `(13, 1)`, menor caminho de 88 passos, todas as 97 células livres alcançáveis (validado por BFS). Balanceamento de tamanho/caminho fica para quando o oxigênio existir.

### 8.2 `MazeBuilder` — `scripts/systems/maze_builder.gd` (`Node3D`, `@tool`)

- Recebe a mesma `MazeGrid` (`@export var maze`) e gera, como filhos: `Walls` — um único `MultiMeshInstance3D` com um bloco `CELL_SIZE × 3 m × CELL_SIZE` por célula `#` (1 draw call independente do tamanho do labirinto) — e `ExitMarker`, uma placa verde na célula de saída.
- Roda **no editor** (`@tool`): o labirinto aparece na viewport 3D e é reconstruído ao editar o Resource (sinal `changed`). Os nós gerados não têm `owner`, então nunca são salvos na cena.
- Não tem regras de jogo: é descartável/substituível quando entrar arte final.

### 8.3 Colisão

- A `Capsule` recebe a mesma `MazeGrid` (`@export var maze`), posiciona-se em `maze.start_cell` no `_ready()` e, a cada "Andar", consulta `maze.is_walkable(alvo)`. Se bloqueado: **não se move** e emite `EventBus.capsule_collided(blocked_cell, direction)`; caso contrário, move e emite `capsule_moved`. Sem `maze` definido, a cápsula anda livremente (útil para testes isolados).
- O custo de oxigênio da colisão será aplicado pelo `GameState` ouvindo `capsule_collided` (ainda não implementado).

## 9. Inimigo (Enemy)

*(A detalhar: como recebe o evento de uso do sonar, lógica de aproximação, condição de derrota por contato.)*

## 10. Áudio

*(A detalhar: como `AudioManager` mapeia sinais do `EventBus` para sons/músicas.)*

## 11. Build & Ferramentas

- Repositório Git, branch `main`.
- Export para PC (Windows/Linux) obrigatório; export web (itch.io) como meta secundária.

## 12. Registro de Implementações

> Cada implementação deve ser registrada aqui, com data e um resumo curto do que foi construído/alterado.

- **2026-09-15 — `EventBus` (autoload):** criado `scripts/autoload/event_bus.gd` e registrado como singleton `EventBus` em `project.godot` (`[autoload]`). Define o contrato de sinais para a primeira fatia vertical (painel de movimentação): `request_move_forward`, `request_rotate_left`, `request_rotate_right` (intenções da UI) e `capsule_moved`, `capsule_rotated`, `oxygen_changed` (fatos emitidos pela Capsule/GameState). Nenhum outro sistema ainda escuta ou emite esses sinais — próximos passos: `Capsule` e o painel de UI.
- **2026-09-15 — `Capsule` (entidade):** criado `scripts/entities/capsule.gd` + `scenes/entities/capsule.tscn`. A Capsule guarda posição em grade (`grid_position: Vector2i`) e direção atual (`enum Facing`, 4 direções), e reage a `EventBus.request_move_forward/request_rotate_left/request_rotate_right`, emitindo de volta `capsule_moved`/`capsule_rotated`. Movimento é sempre "para frente" na direção atual; rotação em incrementos de 90º, sem deslocamento. Consumo de oxigênio **não** é tratado aqui — fica para o `GameState`, que vai escutar `capsule_moved`. Ainda não há checagem de colisão com paredes (depende da `MazeGrid`, que ainda não existe) nem instância na `main.tscn` (isso fica para quando o painel de UI estiver pronto). Visual é um `Polygon2D` triangular só para tornar a rotação visível em teste.
- **2026-10-06 — `MovementPanel` (UI) + integração na `main.tscn`:** criados `scripts/ui/movement_panel.gd` + `scenes/ui/movement_panel.tscn`, com os 3 botões (Girar Esq. / Andar / Girar Dir.) emitindo `request_rotate_left` / `request_move_forward` / `request_rotate_right` no `EventBus`. O painel não referencia a Capsule. `main.tscn` agora instancia a `Capsule` (em `grid_position = (4, 4)`, só para ficar visível na tela) e o painel dentro de um `CanvasLayer`. Primeira fatia vertical jogável: clicar nos botões move/gira a cápsula. Pendências: bloqueio de cliques durante animação (ainda não há animação — movimento é instantâneo), colisão com paredes (depende da `MazeGrid`) e consumo de oxigênio (depende do `GameState`).
- **2026-10-06 — Capsule migrada para 3D + cena de debug:** decisão de abandonar a ideia de mover a cápsula numa matriz 2D e espelhar a posição no 3D a cada passo (custo de sincronização e perda do debug visual do labirinto em 3D). Agora a grade é apenas lógica e a representação é direto em 3D (ver §2.1). Criado `scripts/systems/grid.gd` (`class_name Grid`, `CELL_SIZE = 4.0` m, `grid_to_world()`); `Capsule` passou de `Node2D` para `Node3D` (rotação no eixo Y, meshes provisórios `Body` + `Nose`), removendo seu `cell_size` local. `main.tscn` virou cena 3D de debug com câmera top-down ortográfica fixa, chão com grade (`assets/shaders/debug_grid.gdshader`), luz e ambiente (ver §5.1). Contrato do `EventBus` inalterado (`capsule_moved` continua emitindo posições de grade). Movimento segue instantâneo.
- **2026-10-06 — `MazeGrid` + `MazeBuilder` + colisão:** criado o Resource `MazeGrid` (mapa textual `#`/`.`/`S`/`E`, fora dos limites = parede) e o primeiro labirinto do MVP (`resources/maze_configs/campaign_01.tres`, 15 × 15). Criado o `MazeBuilder` (`@tool`), que gera as paredes em 3D via `MultiMeshInstance3D` + marcador da saída, visível também no editor. `Capsule` agora recebe a `MazeGrid`, nasce em `start_cell` e consulta a matriz antes de andar; novo sinal `EventBus.capsule_collided(blocked_cell, direction)`. `Grid` passou a ser `@tool` (usado pelo builder no editor). `main.tscn`: adicionado `MazeBuilder`, Capsule ligada ao labirinto, chão de debug/câmera reajustados para 15 × 15 (chão 60 × 60 m centrado em `(28, 0, 28)`). Detecção de chegada na saída existe na API (`is_exit`), mas a reação (vitória) fica para o `GameState`. Ver §8.
- **2026-10-06 — `GameState` (autoload) + oxigênio + fim de partida:** criado `scripts/autoload/game_state.gd`, registrado em `project.godot` após o `EventBus`. Estados `PLAYING/WON/LOST`; oxigênio 150, −1 por passo, −5 por colisão. Novos sinais no `EventBus`: `capsule_reached_exit`, `game_over(won)`, `request_restart`; `oxygen_changed` passou a enviar `(current, maximum)`. `Capsule` emite `capsule_reached_exit` antes de `capsule_moved` (vitória tem prioridade sobre o custo do passo). `MovementPanel` desabilita os botões no fim. Nova HUD: `OxygenGauge` e `GameOverScreen` (com reinício via recarga de cena), instanciadas em `main.tscn` › `UI`. Ver §7.
- **2026-10-06 — Documentada a direção técnica do cockpit em 1ª pessoa (planejado, não implementado):** câmera dentro da cápsula com mouse-look, mira central como único elemento 2D, botões 3D acionados por raycast emitindo as mesmas intenções do `EventBus`. A UI 2D atual é provisória. Ver §5.2.
