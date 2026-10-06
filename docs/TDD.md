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
├── MazeGrid (Resource) → grade do labirinto (dados)
└── Enemy          → reage ao uso do sonar
```

*(Diagrama de origem: `classes.svg`. Manter este documento sincronizado se o diagrama mudar.)*

### 2.1 Espaço lógico (grade) x espaço 3D

O jogo é **3D desde a base**: a cápsula e o labirinto existem no mundo 3D, sem nenhuma representação 2D paralela sendo espelhada a cada movimento.

- **Fonte de verdade da posição:** a célula lógica da grade (`Vector2i`), guardada na Capsule (`grid_position`). Regras de jogo (movimento, colisão com paredes via `MazeGrid`, sonar) operam sobre a grade — consultas em matriz, O(1) e determinísticas.
- **Representação:** a posição 3D é derivada da célula via `Grid.grid_to_world()` (`scripts/systems/grid.gd`) a cada mudança; não há física 3D (raycast/`CharacterBody3D`) na movimentação.
- **Mapeamento de eixos:** coluna `x` → eixo X do mundo; linha `y` → eixo Z do mundo; o centro da célula fica em `(x, 0, y) * CELL_SIZE`. "Cima" na matriz (`y - 1`) coincide com o "frente" padrão do Godot (`-Z`).
- **Tamanho da célula:** `Grid.CELL_SIZE = 4.0` metros — constante única, compartilhada por Capsule, chão de debug e (futuramente) `MazeGrid`/construtor de paredes.

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

*(A detalhar: valores exatos de consumo, se cliques repetidos rápidos são bloqueados durante a animação de movimento/rotação.)*

## 6. Sistema de Sonar

*(A detalhar: fórmula de cálculo de distância, alcance máximo, custo/cooldown, probabilidade de atrair o inimigo.)*

## 7. Sistema de Oxigênio

*(A detalhar: valor inicial, taxa de consumo por "Andar", taxa por colisão, onde o valor é armazenado — provavelmente `GameState`.)*

## 8. Labirinto (MazeGrid)

- O labirinto será construído **diretamente em 3D** a partir da matriz (paredes instanciadas por célula), servindo também de debug visual para validar se a matriz está correta. Tamanho de célula vem de `Grid.CELL_SIZE`.

*(A detalhar: formato dos dados — matriz 2D, tipos de célula (livre/parede/saída), como é carregado/gerado para o MVP (fixo) vs. pós-MVP (procedural).)*

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
