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

Cena: Main (cabine) — recarregada a cada partida
├── LevelSetup (script da Main) → gera a MazeGrid e a injeta nos consumidores
├── CapsuleInterior → malha importada da Unreal (atlas único, ver §11)
├── CabinLights / AlarmLight / AlarmSystem
├── Interactables   → Area3D acionadas pela mira (textos, sentar no posto)
├── Player          → 1ª pessoa; modos WALKING / NAVIGATING / READING / DISABLED
├── CommandPanel    → painel diegético: PanelScreens sobre a malha (§5.2)
├── MazeDebug (y = −200, invisível da cabine)
│   ├── Capsule     → executa as intenções, sonar e colisão na grade
│   ├── MazeBuilder → labirinto 3D a partir da MazeGrid (só visual/debug)
│   └── Enemy       → turnos, caça a origem do sonar
└── UI (CanvasLayer) → só mira/prompt, visualizador de texto e tela de fim
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
| State Pattern (enum) | `Player.Mode` | Separar o controle em pé (andar + mira), sentado (mira no painel, olhar limitado), lendo e fim de partida |
| Component | `PanelScreen` | Qualquer cena 2D vira uma tela 3D clicável sobre a malha, sem código específico por tela |
| Dependency Injection (manual) | `LevelSetup.maze_consumers` | O labirinto gerado é entregue a quem precisa (`maze`) antes do `_ready()` |

*(A detalhar conforme mais sistemas forem implementados: Component Pattern, Object Pooling, etc., se/quando forem adotados.)*

## 4. Estrutura de Pastas

```
scripts/
├── autoload/   → EventBus, GameState, AudioManager
├── systems/    → MazeGrid, AlarmSystem, RadioSystem/RadioLine e outros sistemas
├── entities/   → Capsule, Enemy, Player, Interactable
├── cockpit/    → PanelScreen, CommandPanel e scripts das telas do painel
└── ui/         → mapa do sonar, HUD, textos, fim de partida
scenes/
├── main/       → cena principal
├── entities/   → cena da Cápsula, Enemy
├── systems/    → radio_system.tscn (as 13 falas como dados)
├── levels/     → cenas de labirinto/nível
├── cockpit/    → command_panel.tscn + screens/ (conteúdo 2D de cada tela)
└── ui/         → teclado, HUD, textos, fim de partida
resources/
├── maze_configs/ → labirintos escritos à mão
└── ui/           → cockpit_theme.tres (tema das telas do painel)
```

## 5. Sistema de Movimentação (Painel de Botões)

A cápsula **não** é controlada por teclado. O input vem do **teclado em cruz do painel diegético** (5 botões, acionados com a mira, ver §5.2):

| Botão | Intenção no `EventBus` | O₂ |
|---|---|---|
| ▲ Frente | `request_move_forward` | 1 |
| ▼ Ré | `request_move_backward` (anda no sentido oposto, sem girar) | 1 |
| ◀ Girar 90º | `request_rotate_left` | 1 |
| Girar 90º ▶ | `request_rotate_right` | 1 |
| (( · )) Sonar | `request_sonar_ping` | 4 |

Notas técnicas:
- Movimentação em grade (grid-based), não livre: cada passo desloca a cápsula por exatamente uma célula da `MazeGrid`.
- Rotação em incrementos fixos de 90º (4 direções possíveis: cima/baixo/esquerda/direita).
- Os botões só emitem **intenções**. A `Capsule` executa e emite os fatos (`capsule_moved`, `capsule_rotated`, `capsule_collided`, `sonar_pinged`). O `GameState` cobra o oxigênio ouvindo esses fatos, e a UI continua "burra" (dumb UI / thin view).
- **Implementação atual:** teclas físicas `PanelButton3D` (§5.2) no `CommandPanel` › `Keypad`. Cada uma emite a intenção correspondente no `EventBus` ao ser solta sobre si mesma e se desabilita em `game_over`. O antigo `MovementPanel` (botões 2D) foi removido.
- **Capsule em 3D:** `Node3D`; rotação apenas no eixo Y. No Godot, `+Y` gira no sentido anti-horário visto de cima, então `RIGHT = -90º` e `LEFT = +90º` (`FACING_ROTATION_DEGREES`). Visual provisório: `Body` (caixa 1.8 × 1.2 × 2.2 m) + `Nose` (cone laranja apontando para `-Z`) para tornar a direção legível.
- **Manobras com duração (implementado):** cada intenção vira uma manobra em `Capsule._begin_maneuver(kind, duration, action)`. Ela emite `maneuver_started(kind, duration)`, arma um `Timer` filho (one-shot) e, no `timeout`, executa `action` (só se `GameState` ainda estiver `PLAYING`) e emite `maneuver_finished(kind)`. Durações exportadas: `move_duration` 1,0, `rotate_duration` 0,8, `sonar_duration` 0,9. `maneuvering = true` faz pedidos novos serem **ignorados**, sem fila. `kind`: `&"forward"`, `&"backward"`, `&"rotate_left"`, `&"rotate_right"`, `&"sonar"`.
  - Timer filho em vez de `SceneTreeTimer`: é liberado com a cena no reinício, então uma ação pendente nunca roda numa cápsula já liberada.
  - Regras não mudaram: `GameState`, `Enemy` e o mapa continuam reagindo aos fatos (`capsule_moved/collided/rotated`, `sonar_pinged`), que agora chegam no fim da manobra. `maneuver_*` serve só para a apresentação.
  - A posição/rotação 3D do nó `Capsule` (só visível na câmera de debug) continua instantânea no fim da manobra.

### 5.1 Mundo lógico e câmera de debug

- A `main.tscn` é a cabine. O labirinto 3D (`MazeDebug`: `DebugFloor`, `MazeBuilder`, `Capsule`, `Enemy`) fica em **y = −200**, longe e invisível da cabine.
- `DebugCamera` (`scripts/systems/debug_camera_toggle.gd`): `Camera3D` top-down ortográfica (`size = 76`) sobre o labirinto. **F3** alterna entre ela e a câmera do jogador (a esfera vermelha do inimigo só aparece aqui).
- `DebugFloor`: `PlaneMesh` 60 × 60 m com o shader `assets/shaders/debug_grid.gdshader`, que desenha as bordas das células em coordenadas de mundo a partir de `cell_size`.

### 5.2 Cockpit em 1ª pessoa e painel diegético (implementado)

**Em pé (WALKING):** `Player` (`CharacterBody3D`) com WASD + mouse-look e mouse capturado. Um `RayCast3D` (camada 2) a partir da câmera aciona o `Interactable` sob a mira com o clique esquerdo. A HUD 2D (`FirstPersonHud`) mostra só a mira e o prompt.

**Sentado (NAVIGATING):** `Interactable.ENTER_NAVIGATION` (cadeira/painel) → `EventBus.request_enter_navigation` → o `Player` anima a câmera até o `SeatView` (tween de 0,6 s). Ao fim da animação, `_seated = true` e emite `navigation_mode_changed(true)`.
- **Mira + mouse-look sentado (2026-11-12, substitui o cursor livre com edge-pan):** o mouse continua capturado. Em `_input`, o movimento acumula em `_seat_look` (radianos, yaw ±`SEAT_YAW_RANGE` = 40°, pitch de −`SEAT_PITCH_DOWN` = −20° a +`SEAT_PITCH_UP` = 50°; medidos a partir do `SeatView`: knob do alarme a 29,5° de lado/26° acima, mostradores a ~30° de lado, centro do monitor a 42° acima) e a câmera é `seat_view * Basis(pitch, yaw) + balanço da manobra + tranco`. A cada frame, `_update_panel_hover()` relança a mira (centro da tela) como `InputEventMouseMotion` sintético por `_forward_to_panel`, mantendo o hover certo mesmo quando a câmera se move sem mouse (balanço). O clique esquerdo é duplicado com `position` no centro e repassado. Esc libera o cursor, e o próximo clique só recaptura. O prompt vem de `PanelButton3D.get_prompt()` (`PROMPTS` por ação, vazio se travada); a `FirstPersonHud` fica visível sentada, mas só tinge a mira (o texto cobriria as teclas vizinhas).
- **Entrada no painel:** em `_input`, todo `InputEventMouseMotion`/`InputEventMouseButton` vira um raio da câmera (`project_ray_origin/normal`) na camada `PanelScreen.PANEL_LAYER` (layer 4, só áreas). O nó pai da área atingida recebe o evento via `forward_mouse(event, world_position)`. Pode ser uma `PanelScreen` ou uma `PanelButton3D`, e o `Player` só exige esse método (*duck typing*). Trocar de controle chama `release_hover()` no anterior. Soltar o botão sempre vai para o controle onde ele foi pressionado (interseção com o plano dele), senão uma tecla ficaria presa ao arrastar para fora. Clique direito (`exit_navigation`) levanta.
- Raycast próprio em vez de `physics_object_picking`: o picking da Godot atinge qualquer `CollisionObject3D` pickable (colisões da cabine, outros `Interactable`), e a máscara dedicada evita esse conflito.

**`PanelScreen`** (`scripts/cockpit/panel_screen.gd`, `class_name`, componente reutilizável):
- Cria um `SubViewport` (`resolution`, `UPDATE_ALWAYS`) com a cena `content` instanciada e o exibe num `QuadMesh` (`size` em metros, plano XY local, virado para +Z) com material *unshaded* (`brightness` multiplica a cor, e valores > 1 alimentam o glow). `transparent` serve para os mostradores redondos.
- Se `interactive`, adiciona uma `Area3D` fina (layer 4). `world_to_pixel()` converte o ponto 3D atingido em UV/pixel, e `forward_mouse()` duplica o evento com essa posição e o injeta com `SubViewport.push_input()`. Os Controls de dentro funcionam como UI 2D normal (hover, pressed, disabled).
- `content_node` expõe a raiz instanciada para injeção de dados.

**`PanelButton3D`** (`scripts/cockpit/panel_button_3d.gd`, `class_name`): tecla física montada em código. `BoxMesh` (ou `CylinderMesh` com `round`) cuja face fica em z = 0 e que cresce para +Z, com `Label3D` gravado na tecla, `Area3D` na layer 4 e `AudioStreamPlayer3D` (`panel_click.wav`, bus SFX).
- `forward_mouse`: hover liga emissão ciano. Ao pressionar, a tecla afunda `travel` (tween de 0,05 s) e toca o clique com pitch levemente aleatório. Ao soltar, a tecla volta e só aciona se ainda estiver em hover (`release_hover` já foi chamado se o cursor saiu).
- `Action`: `MOVE_FORWARD`, `MOVE_BACKWARD`, `ROTATE_LEFT`, `ROTATE_RIGHT`, `SONAR` e `TOGGLE_ALARM_MUTE`. Este último também escuta `alarm_muted_changed` para acender em âmbar (indicador).
- `game_over` desabilita a tecla (escurece e ignora entrada).
- Teclas de manobra escutam `maneuver_started/finished`: `busy` ignora entrada e escurece. A tecla que disparou a manobra (`_engaged`) fica afundada e acesa até `maneuver_finished`. Como os sinais são síncronos, ao voltar de `_trigger()` o `busy` já indica se a `Capsule` aceitou. Se ela recusou (fim de partida), a tecla sobe na hora.
- **Balanço da câmera (`Player`):** em `maneuver_started`, um envelope `sin(πt)` ao longo da duração aplica `MANEUVER_TILT[kind]` (pitch/yaw/roll em rad: andar ±0,022 de pitch, girar ±0,045 de roll e ±0,012 de yaw), somado à orientação sentada. Deslocamentos alimentam o tremor existente com `MANEUVER_RUMBLE` (0,0035).
- `HeadingScreen` mostra o estado da manobra (`ManeuverLabel`, piscando durante a manobra).

**`CommandPanel`** (`scenes/cockpit/command_panel.tscn` + `scripts/cockpit/command_panel.gd`): instanciado na `Main` com transform identidade (mesmo espaço da malha da cabine). Os filhos são `PanelScreen` posicionadas sobre a malha. As posições foram obtidas por raycast na malha (colisão trimesh temporária) a partir de screenshots. Base do plano do painel amarelo: X = (−1, 0, 0), Y = (0, 0,9627, 0,2707), Z = (0, 0,2707, −0,9627).

| Tela | Conteúdo (`scenes/cockpit/screens/`) | Tamanho | Interativa |
|---|---|---|---|
| `Keypad/HeadingScreen` (faixa superior da área cinza) | `heading_screen.tscn`: rumo, alerta, dica de levantar | 0,46 × 0,20 m | Não |
| `SonarScreen` (CRT) | `sonar_screen.tscn`: `navigation_map.gd` em tela cheia | 0,47 × 0,56 m | Não |
| `OxygenDial` / `InterferenceDial` (relógios) | `gauge_dial.gd` (`Kind.OXYGEN` / `Kind.INTERFERENCE`), desenhado em `_draw()` | Ø 0,25 m | Não |
| `StatusMonitor` (monitor superior) | `status_monitor.tscn`: log rolante (10 linhas), `OxygenGauge` e custos | 1,30 × 0,76 m | Não |

- **`Keypad`** (`Node3D` com a base do painel amarelo, origem no centro da área cinza + 3,5 cm na normal, para cobrir os botões modelados): `HeadingScreen`, `Plate` (`BoxMesh` 0,46 × 0,46 m escuro) e 5 `PanelButton3D` de 0,10 × 0,10 × 0,03 m em cruz (passo de 0,125 m).
- **`AlarmMuteKnob`** (`PanelButton3D`, `round`, Ø 0,075 m, vermelho) sobre o primeiro knob modelado sob o monitor superior (`(0,858; 0,687; −0,575)`, base do monitor), com legenda `Label3D` "SILENCIAR ALARME".
- `CommandPanel.maze` é um consumidor do `LevelSetup` e repassa a `MazeGrid` ao mapa do CRT.
- Todas as telas continuam "dumb UI" e só escutam o `EventBus`. `Capsule`, `GameState`, `Enemy` e `MazeGrid` não mudaram.
- Tema compartilhado das telas: `resources/ui/cockpit_theme.tres` (fonte/cor padrão dos `Label`).
- Removidos: `scenes/ui/navigation_console.tscn` e `scripts/ui/navigation_console.gd` (o console 2D). A lógica de rumo/alerta foi para `heading_screen.gd` e a de status para `status_monitor.gd`. O medidor de interferência virou mostrador.

## 6. Sistema de Sonar

Implementado na `Capsule` (não há `SonarSystem` separado): `request_sonar_ping` → para cada uma das 4 direções, percorre a grade a partir da célula atual até a primeira célula não andável (pode estar fora dos limites) → `EventBus.sonar_pinged(origin, hits)`. O `GameState` cobra `OXYGEN_COST_SONAR` (4). O `Enemy` passa a caçar `origin`. O mapa (`navigation_map.gd`) revela os `hits` e anima o pulso, e o `Enemy` emite `enemy_detected` se estiver no trajeto (§9). Sem limite de usos nem cooldown.

## 7. Sistema de Oxigênio

Implementado no autoload **`GameState`** (`scripts/autoload/game_state.gd`), que também controla o estado da partida.

### 7.1 Valores

| Constante | Valor |
|---|---|
| `MAX_OXYGEN` | 200 |
| `OXYGEN_COST_MOVE` | 1 por Frente/Ré bem-sucedido |
| `OXYGEN_COST_ROTATE` | 1 por giro |
| `OXYGEN_COST_SONAR` | 4 por pulso |
| `OXYGEN_COST_COLLISION` | 8 por Frente/Ré contra parede |
 Oxigênio é `float` (permite drenos fracionários futuros, ex.: por tempo) e é exibido arredondado para cima. Valores são constantes no script por enquanto; se o balanceamento exigir iteração frequente, migrar para um Resource de configuração.

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

- `scenes/ui/oxygen_gauge.tscn` (`OxygenGauge`): `Label` "O₂ atual / máximo" + `ProgressBar`. Muda para a cor de alerta (vermelho) em ≤ 25% do máximo. Hoje fica dentro do monitor superior do painel (§5.2). O mostrador analógico de O₂ (`gauge_dial.gd`) lê os mesmos sinais.
- `scenes/ui/game_over_screen.tscn` (`GameOverScreen`, tela cheia, oculta por padrão): escurece a tela e mostra título/subtítulo de vitória ou derrota e o botão "Tentar novamente", que emite `request_restart`.
- As teclas `PanelButton3D` se desabilitam ao receber `game_over`.

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
- O custo de oxigênio da colisão é aplicado pelo `GameState` ouvindo `capsule_collided` (§7).

## 9. Inimigo (Enemy)

Implementado em `scripts/entities/enemy.gd` + `scenes/entities/enemy.tscn` (fica em `MazeDebug`; a esfera vermelha só aparece na câmera de debug, F3).

- **Turnos:** age uma vez após cada ação da cápsula (`capsule_moved`, `capsule_rotated`, `capsule_collided`, `sonar_pinged`). Não age fora de `GameState.State.PLAYING`.
- **Nascimento:** célula livre aleatória a ≥ 10 passos do início (nunca na saída); sem candidata, a célula mais distante.
- **Estados:** `WANDERING` (1 passo aleatório a cada 2 turnos, evitando voltar) e `HUNTING` (1 passo por turno pelo menor caminho até o alvo). Cada `sonar_pinged` coloca o inimigo em `HUNTING` com alvo = célula de onde o pulso saiu; ao chegar e não achar a cápsula, volta a vagar. A ≤ 2 passos da cápsula, ele a "sente" e o alvo passa a ser a própria cápsula.
- **Contato:** mesma célula que a cápsula (por movimento de qualquer um dos dois) → `capsule_caught` → `GameState` encerra com `LOST` / `EndReason.CAUGHT`.
- **Proximidade:** após cada turno emite `enemy_proximity_changed(steps)` (distância pelo labirinto, via `MazeGrid.get_distances_from()`).
- **Sonar:** emite `enemy_detected(cell)` (uma vez por pulso) se o inimigo está a até `GameState.SONAR_DETECT_RADIUS` (4,5 células, distância euclidiana a partir da origem, atravessando paredes) **ou** no trecho reto entre a cápsula e o obstáculo atingido por um dos 4 sinais. O mapa mostra um eco vermelho que some em 2,5 s (nunca fica registrado) e desenha o raio como um anel que se expande. O sinal não para no inimigo: a parede atrás dele também é revelada.
- **Apresentação:** `AlarmSystem` (`scripts/systems/alarm_system.gd`) emite `alarm_started/stopped(&"enemy")` com o inimigo a ≤ 4 passos e `(&"low_oxygen")` com O₂ ≤ 25%. `AlarmLight` (`OmniLight3D` vermelha na cabine) pisca enquanto houver alarme (mais rápido para o inimigo). No painel: alerta piscando na tela do teclado, linha no log do monitor superior e mostrador de **interferência** (cheio a 1 passo, zerado a partir de 9, com ponteiro tremendo proporcional à proximidade).
- Áudio: sirene, bipe e metal rangendo tocam pelo `AudioManager` (§10). O mudo do alarme fica no `AlarmSystem`: `request_toggle_alarm_mute` (só com alarme ativo) → `muted` + `alarm_muted_changed(muted)`. Qualquer `alarm_started` novo, ou o fim de todos os alarmes, rearma (`muted = false`). A luz não é afetada.

## 10. Áudio

Implementado. Ver GDD §6 e `docs/roteiro-radio.md`.

- **`AudioManager` (autoload, `scripts/autoload/audio_manager.gd`, registrado após o `GameState`):** escuta o `EventBus` e toca:

| Sinal | Som (`assets/audio/sfx/`) | Bus |
|---|---|---|
| (sempre) | Cama `ambience.mp3` ↔ `ambience2.mp3` alternando com crossfade de 6 s (`CrossfadeLoop`). O `ambience.mp3` tem fade-out próprio nos ~10 s finais: em laço simples deixava um buraco de silêncio a cada 48 s | Ambience |
| `enemy_proximity_changed` | Camada de tensão `ambience3.mp3` (ronco grave), em laço com crossfade; volume sobe com a proximidade (zero a ≥ 9 passos, cheio a 1) e cai no `game_over` | Ambience |
| `enemy_heard_sonar(steps)` | `monster3.mp3`, chamado distante 1,2–2 s depois do pulso, se a criatura está a ≤ 10 passos (cooldown 20 s); mais baixo quanto mais longe | Distant |
| `radio_line_started/finished` | Ducking: bus Ambience a −6 dB durante as falas (tween no volume do bus) | — |
| `capsule_collided` | `crash.mp3` | SFX |
| `maneuver_started(&"sonar")` | `sonar.mp3`: o ping sai no início, e o mapa revela no fim (eco voltando) | SFX |
| `maneuver_started(&"forward"/&"backward")` | `capsule_move.mp3` (pitch 0,9 na ré). Em `maneuver_finished` some em fade de 0,35 s; em `capsule_collided` é cortado seco | SFX |
| `maneuver_started(&"rotate_*")` | `capsule_rotate_a/b.wav`, sorteado, pitch 0,9–1,1 | SFX |
| `enemy_detected` | `monster.mp3` | SFX |
| `enemy_proximity_changed` (≤ 4 passos) | `metal.mp3`, −18 dB + 4 dB por passo mais perto; não reinicia se já está tocando | SFX |
| `capsule_caught` | `monster2.mp3` | SFX |
| `alarm_started/stopped(&"enemy")` | `siren.mp3` em laço | Alarm |
| `alarm_started/stopped(&"low_oxygen")` | `o2_beep.wav` em laço (bipe duplo gerado em Python) | Alarm |
| `alarm_muted_changed` | `AudioServer.set_bus_mute("Alarm")` | — |

- Laços: reinício no `finished` (vale para MP3 e WAV sem mexer nas opções de importação). `stop()` não emite `finished`. `PROCESS_MODE_ALWAYS`. Como é autoload, o ambiente não corta ao reiniciar a partida.
- Exceção à regra "só o AudioManager toca som": o clique das teclas (`PanelButton3D`) é feedback do próprio objeto e posicional (`AudioStreamPlayer3D`).
- **Buses (`default_bus_layout.tres`):** `Master` › `Ambience`, `SFX`, `Alarm`, `Radio` (HighPass 350 Hz + LowPass 3200 Hz + Distortion overdrive, `drive` 0,25 controlado em tempo real pelo `RadioSystem`) e `Distant` (LowPass 700 Hz + Reverb: sons "do lado de fora" do casco).
- Origem/licença dos SFX: `assets/audio/CREDITS.md`.
- **`RadioSystem` (`scripts/systems/radio_system.gd` + `scenes/systems/radio_system.tscn`, nó da `main.tscn`, consumidor de `maze`):** decide quando cada fala toca e é o próprio aparelho (voz, estática e squelch no bus `Radio`). Vive na cena, então o reinício zera as falas já tocadas.
  - **Dados:** `RadioLine` (`scripts/systems/radio_line.gd`, Resource): `id`, `subtitle`, `priority` (`NORMAL`, `URGENT`, `FINAL`), `max_wait`, `delay`. As 13 falas ficam como sub-resources na `radio_system.tscn` (editáveis no inspetor). O áudio é achado por convenção: `res://assets/audio/radio/radio_<id>.wav` (ou `.ogg`/`.mp3`). Sem arquivo, a fala roda só com legenda e duração estimada (0,065 s por caractere, mínimo 2,5 s).
  - **Gatilhos:** `intro` 3 s após carregar; `idle_seat` 30 s após o fim da intro sem `navigation_mode_changed(true)`; `first_seat` (sentar); `first_collision`; `first_sonar` (`sonar_pinged`); `first_enemy` (`enemy_detected` ou `alarm_started(&"enemy")`); `low_oxygen` (`alarm_started(&"low_oxygen")`, mesmo limiar de 25%); `first_alarm` (qualquer `alarm_started`, depois da fala da causa); `station` (20º `maneuver_finished`); `near_exit` (`capsule_moved` a ≤ 3 passos da saída, BFS a partir da saída); `win`/`lost_oxygen`/`lost_caught` (`game_over` + `GameState.end_reason`).
  - **Fila:** uma fala por vez, até 3 na fila, 0,8 s entre falas. `URGENT` (`first_enemy`) entra na frente e **corta** uma fala `NORMAL` em andamento (squelch de fechamento, 0,35 s, e entra); a fala cortada volta a contar como não tocada. Fala que espera mais que `max_wait` (tempo de jogo) é descartada sem contar como tocada, e o mesmo evento pode dispará-la de novo. `FINAL` corta tudo, limpa a fila e toca após `delay` (vitória 1,2 s, O₂ 2 s, contato 3 s, para o rugido terminar).
  - **Interferência (0..1):** máximo entre a proximidade do inimigo (mesma escala do mostrador INTERF.) e um *override* roteirizado. Controla o volume da estática (`radio_static.wav`, que soa mesmo sem fala quando a criatura está perto), quedas aleatórias de volume da voz e o `drive` da distorção do bus. Durante `first_enemy` o override sobe até 1 (ease-in, 90% da fala) e "engole" o fim da frase; depois volta em 2,5 s.
  - **Sinais:** `radio_line_started(id, subtitle, duration)`, `radio_line_finished(id)` e `radio_busy_changed(busy)` (fala tocando, na fila ou final agendada). Ao sair da árvore (reinício) com fala no ar, emite `finished` para não deixar o ambiente abaixado.
  - **SFX gerados (Python):** `radio_static.wav` (4 s em laço, ruído filtrado com flutter e estalos), `radio_squelch_open.wav` e `radio_squelch_close.wav`.
- **Legendas (`RadioSubtitles`, `scripts/ui/radio_subtitles.gd` + `scenes/ui/radio_subtitles.tscn`, último filho de `UI`):** caixa na base da tela com "◂ SUPERFÍCIE" e o texto revelado no ritmo da fala (`visible_ratio` em 80% da duração). Fica acima da tela de fim. Não ficaram no monitor superior porque, sentado no posto, só a última linha dele aparece; o monitor registra ">> TRANSMISSÃO RECEBIDA — SUPERFÍCIE" no log.
- **`CaughtSequence` (`scripts/systems/caught_sequence.gd`, nó da `main.tscn`):** apresentação da derrota por contato (`game_over` com `EndReason.CAUGHT`). 0 s: `cabin_impact(1.0)`; até 2,4 s: luzes de `CabinLights` falham aleatoriamente (cada vez mais), `PanelScreen.power` e os `Label3D` do painel piscam, `AlarmLight` estroboscópica (o script dela é pausado); 1,1 s: `cabin_impact(0.6)`; 2,4 s: apagão (luzes, telas e rótulos a 0, luz ambiente do `Environment` a 0,015, com uma última piscada fraca da luz de teto). O `Environment` é duplicado antes de escurecer, porque é sub-resource da cena em cache e o reinício o reaproveitaria. `RadioSystem`: `lost_caught` com `delay` 4 s, falando no escuro.
- **`cabin_impact(strength)` (EventBus):** golpe no casco. `Player`: tranco de câmera (`IMPACT_KICK`, decai) somado ao olhar do posto, ou aplicado sobre a pose congelada no fim da partida, + tremor. `AudioManager`: `crash.mp3` e `metal.mp3` graves (pitch 0,6–0,85), mais altos quanto mais forte. Pensado também para futuros ataques não letais.
- **`PanelScreen.power`:** multiplica o brilho do quad (0 = apagada), usado para falhas e apagões.
- **`AudioManager` na derrota por contato:** a cama de ambiente some (−60 dB em 2 s, após 2 s) e volta em `request_restart`.
- **Rádio antes da intro:** nenhuma fala começa antes da `intro` (que é `URGENT`), para sentar no posto nos primeiros segundos não adiantar o tutorial.
- **Tela de fim + rádio:** `GameOverScreen` espera `radio_busy_changed(false)` (+0,8 s de silêncio) antes de aparecer em fade, com limite de 20 s; um clique antecipa. A checagem é adiada (`call_deferred`) porque o `RadioSystem` agenda a fala final no mesmo `game_over`.
- **`Enemy`:** emite `enemy_heard_sonar(steps)` quando um pulso o coloca em caça (distância dele até a origem do pulso).

## 11. Assets da Cabine & Iluminação

- **Origem:** `assets/imports/capsula_completa/SM_MERGED_StaticMeshActor_1.gltf`, exportado da Unreal com *Merge Actors*: **1 malha, 1 material, 1 atlas 2048×2048** (BaseColor + Normal), sem colisão própria. Por isso tudo fica borrado de perto (o painel amarelo ocupa uma fração pequena do atlas) e as variações de material da Unreal se perderam (paredes ferrugem viraram brancas).
- `assets/imports/deepwater_station/` (~1,1 GB, 61 glTFs com texturas próprias em alta resolução) **não é usado** por nenhuma cena. Não contém o painel amarelo (que veio de outro pacote).
- **Solução aplicada às telas:** `PanelScreen` sobrepõe telas renderizadas em tempo real à malha (§5.2). Isso resolve nitidez e interação de uma vez.
- **Opções para o restante (por custo/benefício):**
  1. **Reexportar da Unreal sem mesclar** (ou com *Merge Actors* gerando um material/atlas por grupo e em 4096+). É a solução de verdade: cada objeto volta com a própria textura em resolução original.
  2. **Reexportar só o painel e os objetos próximos ao posto** como malhas separadas e substituí-los na cena (escondendo a parte da malha mesclada atrás). Menor esforço com o maior ganho visual.
  3. **Upscale por IA do atlas** (ex.: Real-ESRGAN / Upscayl, ou ferramentas de textura por IA). Ganho limitado: o atlas tem poucos pixels por objeto, então a IA "inventa" detalhe e pode borrar as costuras entre ilhas de UV. Usar só como paliativo.
  4. **Retexturizar via IA generativa** (ex.: geração de textura a partir do modelo). Exige malhas separadas com UV próprio, ou seja, depende do item 1 ou 2.
- **Pipeline recomendado para reexportar da Unreal com fidelidade** (o objetivo é trazer cada objeto com **as texturas originais do pacote**, sem rebake):
  1. **Não usar *Merge Actors*.** Na Unreal, selecionar os atores da cabine na viewport/Outliner → *File › Export Selected…* → **FBX**. Um único FBX com vários atores mantém cada um como **nó e malha separados**, com transform e slots de material próprios. A Godot 4 importa FBX nativamente (ufbx). Exportar em partes (paredes, painel, props) facilita reimportar só o que mudar.
  2. **Exportar as texturas originais**, não as "bakeadas": no Content Browser, *Browse to Asset* no material de cada objeto → selecionar as texturas (`T_*_BC`, `T_*_ORM`, `T_*_N`, emissivas) → *Asset Actions › Bulk Export* (PNG/TGA). Nos pacotes usados, o ORM (Occlusion-Roughness-Metallic) já vem no mesmo layout do **`ORMMaterial3D`** da Godot, que aceita a textura direto, sem conversão.
  3. **Recriar os materiais na Godot** (`ORMMaterial3D`: albedo = BC, ORM = ORM, normal = N, emissão). Copiar os **parâmetros dos Material Instances** (tintas de cor, intensidade de emissão, tiling). É aqui que volta o tom ferrugem das paredes, que na Unreal é um parâmetro de cor sobre a textura base. Para automatizar, um script de importação (`EditorScenePostImport`) pode trocar os materiais pelo nome do slot.
  4. **Normal map:** a Unreal usa convenção DirectX (Y−) e a Godot OpenGL (Y+). Na importação da textura, marcar *Normal Map* e inverter o canal verde (`process/normal_map_invert_y = true`), senão os relevos ficam "afundados".
  5. **Escala/eixos:** Unreal em cm e Z-up; no export FBX, manter as unidades e conferir escala 0,01 na importação (ou *Convert Scene* no exportador). Validar com o `CabinCollision` atual.
  6. **Telas emissivas** (monitores, CRT): na Unreal são materiais com textura de UI/emissiva. Na Godot elas continuam sendo `PanelScreen`, que já é mais fiel e é interativa.
  7. **Alternativa mais rápida (menos fiel):** o exportador **glTF** da Unreal com *Bake Material Inputs* e *Default Material Bake Size* em 2048/4096 **por material**. Ainda faz bake, mas um por objeto em vez de um atlas para a cena toda.
  - **Iluminação equivalente:** boa parte do visual da demo vem do **Lumen** (iluminação global) + exposição/pós-processamento da Unreal. No renderer GL Compatibility não há GI. Trocar para **Forward+** liberaria SDFGI/VoxelGI, SSAO, SSR e névoa volumetrica, muito mais perto da demo, ao custo da build web e de PCs fracos. Decisão de projeto em aberto.
- **Iluminação (`main.tscn` › `WorldEnvironment`/`CabinLights`):** ambiente 0,22, tonemap ACES (`tonemap_white` 6), glow (threshold 0,85) e ajuste de contraste/saturação. Luzes de teto em y = 1,75 (dentro do volume da cabine). A traseira tem sombra; a frontal ficou sem sombra para não projetar a cadeira serrilhada no painel. Dois `AccentLeft/Right` laranja perto do teto e `ConsoleGlow` reduzido (0,2) para não esverdear o painel. Compatível com o renderer GL Compatibility (sem SSAO/volumetria).

## 12. Build & Ferramentas

- Repositório Git, branch `main`.
- Export para PC (Windows/Linux) obrigatório; export web (itch.io) como meta secundária.

- **Captura visual para debug:** o Godot (snap) grava frames com `--write-movie <arquivo>.png --fixed-fps 30 --quit-after N`. O snap não enxerga `/tmp`, então é preciso gravar em `~/snap/godot-4/common/`. Scripts `--script` (estendendo `SceneTree`) servem para posicionar a câmera, tirar screenshots, fazer raycast de pixels para coordenadas 3D e simular cliques (`Input.parse_input_event`). Nesses scripts, autoloads devem ser acessados por `root.get_node("EventBus")`. Depois de criar um `class_name` novo fora do editor, rodar `godot --headless --import` para atualizar o cache de classes.

## 13. Registro de Implementações

> Cada implementação deve ser registrada aqui, com data e um resumo curto do que foi construído/alterado.

- **2026-09-15 — `EventBus` (autoload):** criado `scripts/autoload/event_bus.gd` e registrado como singleton `EventBus` em `project.godot` (`[autoload]`). Define o contrato de sinais para a primeira fatia vertical (painel de movimentação): `request_move_forward`, `request_rotate_left`, `request_rotate_right` (intenções da UI) e `capsule_moved`, `capsule_rotated`, `oxygen_changed` (fatos emitidos pela Capsule/GameState). Nenhum outro sistema ainda escuta ou emite esses sinais — próximos passos: `Capsule` e o painel de UI.
- **2026-09-15 — `Capsule` (entidade):** criado `scripts/entities/capsule.gd` + `scenes/entities/capsule.tscn`. A Capsule guarda posição em grade (`grid_position: Vector2i`) e direção atual (`enum Facing`, 4 direções), e reage a `EventBus.request_move_forward/request_rotate_left/request_rotate_right`, emitindo de volta `capsule_moved`/`capsule_rotated`. Movimento é sempre "para frente" na direção atual; rotação em incrementos de 90º, sem deslocamento. Consumo de oxigênio **não** é tratado aqui — fica para o `GameState`, que vai escutar `capsule_moved`. Ainda não há checagem de colisão com paredes (depende da `MazeGrid`, que ainda não existe) nem instância na `main.tscn` (isso fica para quando o painel de UI estiver pronto). Visual é um `Polygon2D` triangular só para tornar a rotação visível em teste.
- **2026-10-06 — `MovementPanel` (UI) + integração na `main.tscn`:** criados `scripts/ui/movement_panel.gd` + `scenes/ui/movement_panel.tscn`, com os 3 botões (Girar Esq. / Andar / Girar Dir.) emitindo `request_rotate_left` / `request_move_forward` / `request_rotate_right` no `EventBus`. O painel não referencia a Capsule. `main.tscn` agora instancia a `Capsule` (em `grid_position = (4, 4)`, só para ficar visível na tela) e o painel dentro de um `CanvasLayer`. Primeira fatia vertical jogável: clicar nos botões move/gira a cápsula. Pendências: bloqueio de cliques durante animação (ainda não há animação — movimento é instantâneo), colisão com paredes (depende da `MazeGrid`) e consumo de oxigênio (depende do `GameState`).
- **2026-10-06 — Capsule migrada para 3D + cena de debug:** decisão de abandonar a ideia de mover a cápsula numa matriz 2D e espelhar a posição no 3D a cada passo (custo de sincronização e perda do debug visual do labirinto em 3D). Agora a grade é apenas lógica e a representação é direto em 3D (ver §2.1). Criado `scripts/systems/grid.gd` (`class_name Grid`, `CELL_SIZE = 4.0` m, `grid_to_world()`); `Capsule` passou de `Node2D` para `Node3D` (rotação no eixo Y, meshes provisórios `Body` + `Nose`), removendo seu `cell_size` local. `main.tscn` virou cena 3D de debug com câmera top-down ortográfica fixa, chão com grade (`assets/shaders/debug_grid.gdshader`), luz e ambiente (ver §5.1). Contrato do `EventBus` inalterado (`capsule_moved` continua emitindo posições de grade). Movimento segue instantâneo.
- **2026-10-06 — `MazeGrid` + `MazeBuilder` + colisão:** criado o Resource `MazeGrid` (mapa textual `#`/`.`/`S`/`E`, fora dos limites = parede) e o primeiro labirinto do MVP (`resources/maze_configs/campaign_01.tres`, 15 × 15). Criado o `MazeBuilder` (`@tool`), que gera as paredes em 3D via `MultiMeshInstance3D` + marcador da saída, visível também no editor. `Capsule` agora recebe a `MazeGrid`, nasce em `start_cell` e consulta a matriz antes de andar; novo sinal `EventBus.capsule_collided(blocked_cell, direction)`. `Grid` passou a ser `@tool` (usado pelo builder no editor). `main.tscn`: adicionado `MazeBuilder`, Capsule ligada ao labirinto, chão de debug/câmera reajustados para 15 × 15 (chão 60 × 60 m centrado em `(28, 0, 28)`). Detecção de chegada na saída existe na API (`is_exit`), mas a reação (vitória) fica para o `GameState`. Ver §8.
- **2026-10-06 — `GameState` (autoload) + oxigênio + fim de partida:** criado `scripts/autoload/game_state.gd`, registrado em `project.godot` após o `EventBus`. Estados `PLAYING/WON/LOST`; oxigênio 150, −1 por passo, −5 por colisão. Novos sinais no `EventBus`: `capsule_reached_exit`, `game_over(won)`, `request_restart`; `oxygen_changed` passou a enviar `(current, maximum)`. `Capsule` emite `capsule_reached_exit` antes de `capsule_moved` (vitória tem prioridade sobre o custo do passo). `MovementPanel` desabilita os botões no fim. Nova HUD: `OxygenGauge` e `GameOverScreen` (com reinício via recarga de cena), instanciadas em `main.tscn` › `UI`. Ver §7.
- **2026-10-06 — Documentada a direção técnica do cockpit em 1ª pessoa (planejado, não implementado):** câmera dentro da cápsula com mouse-look, mira central como único elemento 2D, botões 3D acionados por raycast emitindo as mesmas intenções do `EventBus`. A UI 2D atual é provisória. Ver §5.2.
- **2026-10-06 — Arquitetura planejada de áudio/alarme (não implementada):** documentados `AudioManager`, buses (`Ambience`/`SFX`/`Alarm`/`Radio`) com efeito de rádio aplicado em tempo real, `RadioSystem` orientado a dados (`RadioLine`) e `AlarmSystem` emitindo `alarm_started/stopped(reason)` para luz vermelha e sirene. Ver §10.
- **2026-10-27 — Cabine em 1ª pessoa + painel de navegação + labirinto procedural + sonar:** a `main.tscn` agora é a cabine (`assets/imports/capsula_completa`, modelo único sem colisão própria) com colisão simplificada por caixas (`CabinCollision`: piso em y ≈ −1,77, paredes laterais/fundo e o bloco do posto de comando). **Jogador** (`scenes/entities/player.tscn` + `scripts/entities/player.gd`): `CharacterBody3D` sem malha, WASD/setas + mouse-look, clique esquerdo aciona o `Interactable` sob a mira (`RayCast3D` na camada 2). Modos `WALKING / NAVIGATING / READING / DISABLED`. **Interactable** (`scripts/entities/interactable.gd`, `Area3D` layer 2): `SHOW_TEXT` emite `request_show_note` (abre `NoteViewer`) e `ENTER_NAVIGATION` emite `request_enter_navigation` (cadeira e painel central). Ao sentar, a câmera vai para `SeatView` e aparece o `NavigationConsole` (O₂ à esquerda, mapa no centro, teclado à direita); clique direito levanta. **Teclado** (`MovementPanel`, agora `GridContainer` em cruz): Frente, Ré, Girar E/D e Sonar. **Capsule**: `request_move_backward` (anda no sentido oposto, sem girar) e `request_sonar_ping` → `sonar_pinged(origin, hits)` com o primeiro obstáculo nas 4 direções. **Oxigênio**: máx. 200; mover/ré 1, girar 1, sonar 4, colisão 8 (colisão não move). **Mapa** (`scripts/ui/navigation_map.gd`): top-down desenhado em `_draw()`, começa sem paredes; revela por colisão e sonar, mostra rastro, posição/rumo e a saída. **Labirinto procedural** (`scripts/systems/maze_generator.gd`, recursive backtracker + laços opcionais) gera as mesmas linhas textuais da `MazeGrid`; garante caminho até a saída com menor caminho ≥ 1/4 das células livres. `LevelSetup` (script da `Main`) gera o labirinto em `_enter_tree()` e o injeta em `MazeBuilder`, `Capsule` e `NavigationConsole`; cada reinício gera um novo (`fixed_seed`/`fixed_maze` permitem reproduzir). O mundo lógico (`MazeDebug`) fica em y = −200, com câmera top-down alternável por F3. Novos sinais no `EventBus`: `request_move_backward`, `request_sonar_ping`, `sonar_pinged`, `request_show_note`, `request_enter_navigation`, `interaction_prompt_changed`, `note_closed`, `navigation_mode_changed`. HUD 2D antiga (painel no rodapé e O₂ no canto) substituída por `FirstPersonHud` (mira + prompt).
- **2026-10-27 — Inimigo, alarme e derrota por contato:** `Enemy` em turnos (vaga; caça a origem de cada pulso de sonar; persegue a cápsula a ≤ 2 passos; contato = derrota). `MazeGrid.get_distances_from()` (BFS) adicionado. `GameState` ganhou `EndReason` (`REACHED_EXIT`, `OUT_OF_OXYGEN`, `CAUGHT`), lido pela tela de fim ("CONTATO"). `AlarmSystem` + `AlarmLight` (luz vermelha da cabine). Painel: alerta no cabeçalho, medidor de interferência e eco vermelho no mapa. Novos sinais: `enemy_proximity_changed`, `enemy_detected`, `capsule_caught`, `alarm_started`, `alarm_stopped`. Ver §9.
- **2026-11-11 — Painel diegético (`CommandPanel` + `PanelScreen`), remoção do console 2D e passada de iluminação:** criado o componente `PanelScreen` (SubViewport → quad 3D, com entrada de mouse por raycast na layer 4 e `push_input`) e a cena `scenes/cockpit/command_panel.tscn`, com cinco telas sobre a malha da cabine: teclado (interativo), sonar no CRT, mostradores de O₂ e interferência e monitor de log. `Player` no modo NAVIGATING agora encaminha os eventos de mouse às telas, gira o olhar quando o cursor chega às bordas e tem o `SeatView` recuado e mais alto, enquadrando o painel inteiro. Removidos `navigation_console.tscn/.gd`. A lógica foi para `keypad_screen.gd` e `status_monitor.gd`. Novo `gauge_dial.gd` e tema `resources/ui/cockpit_theme.tres`. As teclas do `MovementPanel` cresceram (140 × 124). Iluminação da `main.tscn` refeita para o clima da demo em Unreal. Documentada a limitação do atlas único da cabine e as opções de correção (§11). Sem novos sinais no `EventBus`. Ver §5.2 e §11.
- **2026-11-11 — Diagnóstico: "andar e girar a câmera ao mesmo tempo não funciona":** não é bug de código (a física lê o teclado e `_unhandled_input` lê o mouse de forma independente). No notebook de desenvolvimento (touchpad ELAN, GNOME/Wayland), a opção do sistema *desativar touchpad enquanto digita* bloqueia o touchpad enquanto W/A/S/D está pressionado. Com mouse externo ou com a opção desligada, funciona.
- **2026-11-11 — Teclas físicas (`PanelButton3D`), silenciar alarme, `AudioManager` e edge-pan:** criado `PanelButton3D` (tecla/knob 3D com curso, hover, clique posicional e cancelamento ao soltar fora). O `Keypad` do `CommandPanel` agora tem `HeadingScreen` + placa + 5 teclas, e `AlarmMuteKnob` fica sob o monitor. Removidos `MovementPanel` (`scenes/ui/movement_panel.tscn`, `scripts/ui/movement_panel.gd`) e `keypad_screen` (virou `heading_screen`). `Player` aceita qualquer controle com `forward_mouse/release_hover` e o olhar sentado virou edge-pan acumulado. Novos sinais: `request_toggle_alarm_mute` e `alarm_muted_changed(muted)`, com mudo implementado no `AlarmSystem`. Novo autoload `AudioManager` + `default_bus_layout.tres` (Ambience/SFX/Alarm). SFX gerados: `panel_click.wav` e `o2_beep.wav`. Documentado o pipeline de reexportação fiel da Unreal (§11). Ver §5.2, §9 e §10.
- **2026-11-11 — Manobras com duração (game feel):** `Capsule` executa cada ação depois de um tempo (`_begin_maneuver` + `Timer`), ignorando pedidos durante a manobra. Novos sinais `maneuver_started(kind, duration)` e `maneuver_finished(kind)`. `PanelButton3D` trava as teclas e mantém afundada a tecla acionada. `HeadingScreen` mostra o estado. `AudioManager` toca motor (fade/corte na colisão), rangido no giro e o ping do sonar no início. `Player` inclina e vibra a câmera. Novos SFX CC0 `capsule_move.mp3` e `capsule_rotate_a/b.wav`, com créditos em `assets/audio/CREDITS.md`. Ver §5, §5.2 e §10.
- **2026-11-12 — `RadioSystem`, legendas e camadas de ambiente:** implementado o rádio do comandante com as 13 falas gravadas (`assets/audio/radio/`), fila com prioridades (`URGENT` interrompe, `FINAL` corta tudo), validade na fila, interferência ligada à proximidade do inimigo (estática, quedas de sinal, distorção) e override roteirizado na fala `first_enemy`. Novo bus `Radio` (filtros + distorção) e `Distant` (abafado + reverb). Legendas na base da tela (`RadioSubtitles`); tela de fim espera a fala final. `AudioManager`: cama de ambiente com crossfade (`ambience` ↔ `ambience2`, corrige o buraco de silêncio do laço antigo), camada de tensão `ambience3` por proximidade, chamado distante `monster3` quando a criatura ouve o sonar (novo sinal `enemy_heard_sonar`) e ducking do ambiente durante as falas. Novos sinais: `radio_line_started`, `radio_line_finished`, `radio_busy_changed`, `enemy_heard_sonar`. Ver §10.
- **2026-11-12 — Sonar com raio, `CaughtSequence` e `cabin_impact`:** `Enemy` detecta por raio (`GameState.SONAR_DETECT_RADIUS` = 4,5) além do feixe; `NavigationMap` desenha o anel do raio. Nova sequência de derrota por contato (falha de luzes/telas, dois golpes, apagão) e sinal `cabin_impact` (tranco de câmera no `Player`, impacto + esmagamento no `AudioManager`). `PanelScreen.power`. Correções: nenhuma fala do rádio antes da intro; `GameOverScreen`/`RadioSubtitles` não criam timer/tween fora da árvore no reinício. Ver §9 e §10.
- **2026-11-12 — Mira sentado no posto:** `Player` em `NAVIGATING` mantém o mouse capturado, faz mouse-look limitado e lança a mira central no painel (hover a cada frame + clique); removido o edge-pan (`SEAT_EDGE_*`). `PanelButton3D.get_prompt()`; `FirstPersonHud` permanece visível sentada e só tinge a mira. Ver §5.2.
