# [Nome do jogo a definir]

Jogo de terror psicológico em primeira pessoa, desenvolvido em Godot 4.7, para a
disciplina de Jogos Digitais. Inspirado em *Iron Lung*: o jogador está preso
dentro de uma cápsula sem visibilidade do ambiente externo, navegando um
labirinto (matriz com no mínimo um caminho válido) apenas com sons e um sonar de uso limitado.

## Como abrir o projeto

1. Instale o Godot 4.7 (https://godotengine.org/download/linux/).
2. Abra o Godot, clique em "Importar" e selecione a pasta deste repositório
   (arquivo `project.godot`).
3. `run/main_scene` já aponta para `scenes/main/main.tscn`.

## Estrutura de pastas

```
├── addons/             # plugins de terceiros (ex: dialog manager)
├── assets/
│   ├── audio/
│   │   ├── music/      # trilha / música ambiente
│   │   └── sfx/        # efeitos sonoros (colisão, sonar, passos, alarmes)
│   ├── fonts/
│   ├── sprites/        # sprites 2D (UI, ícones do painel)
│   └── textures/       # texturas do interior da cápsula
├── scenes/
│   ├── main/           # cena principal / bootstrap do jogo
│   ├── ui/             # HUD, menus, painel de controle da cápsula
│   ├── levels/         # cada mapa/labirinto é uma cena aqui
│   └── entities/       # cápsula, inimigo, objetos interativos
├── scripts/
│   ├── autoload/       # Singletons/Autoloads (EventBus, GameState, AudioManager)
│   ├── entities/       # scripts das entidades (Capsule.gd, Enemy.gd)
│   ├── systems/        # lógica de sistemas (SonarSystem.gd, MazeGenerator.gd)
│   └── ui/             # scripts de interface
├── resources/
│   ├── maze_configs/     # Resources (.tres) com definição de cada labirinto/dificuldade
│   └── enemy_configs/    # Resources (.tres) com parâmetros do inimigo
├── docs/                 # GDD, diagramas de classes/arquitetura
│   ├── one-sheet.pdf
│   └── one-sheet.docx    # Versão editável
├── project.godot
└── .gitignore
```

## Convenções

- **Autoloads (Singletons)**: usar para o `EventBus` (sinais globais) e `GameState`
  (máquina de estados: Menu → Jogando → Colisão → Morto → Vitória).
- **Nomenclatura de cenas/scripts**: PascalCase para nomes de classes/nós
  (`SonarSystem`, `MazeGrid`), snake_case para arquivos (`sonar_system.gd`).
- **Resources (.tres)** são usados para dados de configuração (labirintos, inimigos,
  power-ups) para manter o design orientado a dados, facilitando adicionar novos
  mapas sem tocar em código — importante para a fase roguelike do projeto.

## Time

- Equipe: Profundidade Zero Studio
- Integrantes: Gustavo Marcos Brendler e Rafael Nunes Siqueira
