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

*(A detalhar: valores exatos de consumo, se cliques repetidos rápidos são bloqueados durante a animação de movimento/rotação.)*

## 6. Sistema de Sonar

*(A detalhar: fórmula de cálculo de distância, alcance máximo, custo/cooldown, probabilidade de atrair o inimigo.)*

## 7. Sistema de Oxigênio

*(A detalhar: valor inicial, taxa de consumo por "Andar", taxa por colisão, onde o valor é armazenado — provavelmente `GameState`.)*

## 8. Labirinto (MazeGrid)

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
