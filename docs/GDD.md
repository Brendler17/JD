# Game Design Document — Profundidade Zero

> Documento vivo. Deve ser atualizado a cada nova mecânica, sistema ou decisão de design implementada/discutida ao longo do desenvolvimento. Ver também [`one-sheet.md`](one-sheet.md) (pitch resumido) e [`TDD.md`](TDD.md) (documento técnico irmão).

## 1. Visão Geral

- **Nome do jogo:** Profundidade Zero
- **Gênero:** Horror psicológico / navegação às cegas / gerenciamento de recursos
- **Plataforma:** PC (Windows/Linux), engine Godot 4. Build web (itch.io) como meta secundária.
- **Público-alvo / Classificação:** 14+ (T/Teen) — suspense e perigo implícito, sem violência gráfica explícita.
- **Pitch:** o jogador guia uma cápsula submersa, sem visão do ambiente, por um labirinto, usando um painel de botões e um sonar de uso limitado, administrando oxigênio, informação e risco até alcançar a saída.

## 2. Player Experience & Sentimento Pretendido

- Tensão constante por privação sensorial (o jogador "vê" o mundo apenas por sinais indiretos: sonar e áudio).
- Decisões de risco x recompensa a cada ativação do sonar e a cada movimento.
- Sensação de isolamento e vulnerabilidade dentro da cápsula.

*(A detalhar: referências de tom, moodboard, exemplos de "momentos" que o jogo deve gerar.)*

## 3. Core Loop

1. Jogador avalia a situação (áudio ambiente, oxigênio restante, última leitura de sonar).
2. Jogador decide: ativar o sonar (arriscar atrair inimigo, ganhar informação) e/ou usar o painel de movimentação.
3. Jogador usa o painel de movimentação para agir.
4. O ambiente reage (colisão consome oxigênio, inimigo pode se aproximar).
5. Volta ao passo 1, até alcançar a saída (vitória) ou esgotar oxigênio / ser alcançado (derrota).

## 4. Mecânicas

### 4.1 Painel de Movimentação

O jogador **não** controla a cápsula por teclado. A movimentação ocorre por um **painel visual de botões**, clicado com o mouse:

| Botão | Ação | Custo de oxigênio |
|---|---|---|
| Andar | Move a cápsula uma célula para frente, na direção em que está apontada | Sim |
| Girar 90º Esquerda | Rotaciona a cápsula 90º à esquerda, sem deslocamento | Não |
| Girar 90º Direita | Rotaciona a cápsula 90º à direita, sem deslocamento | Não |

Regras:
- A cápsula sempre se move "para frente" em relação à direção atual — não há strafe nem movimento livre.
- Apenas o botão **Andar** consome oxigênio. Girar é uma ação sem custo de recurso (mas pode ter custo de tempo/risco a definir, ex.: turnos de aproximação de inimigo).

### 4.2 Sonar

- Uso limitado (quantidade a definir).
- Revela a distância até o obstáculo mais próximo à frente da cápsula.
- Risco: cada ativação pode atrair um inimigo invisível e intransponível.

*(A detalhar: alcance, cooldown, feedback sonoro/visual, custo exato de recarga.)*

### 4.3 Oxigênio

- Recurso central e condição de derrota.
- Consumido ao usar o botão Andar e por colisões.
- Esgotar oxigênio ou colidir repetidamente leva à morte.

*(A detalhar: valor inicial, taxa de consumo por movimento, taxa por colisão, se há regeneração.)*

### 4.4 Labirinto

- Representado como uma matriz (grade) com no mínimo um caminho válido entre entrada e saída.
- Modo Campanha (MVP): labirinto único, ponto A → ponto B.
- Modo Roguelike (pós-MVP): múltiplos mapas gerados, dificuldade crescente.

### 4.5 Inimigo

- Invisível e intransponível.
- Reage ao uso do sonar (se aproxima quando o jogador "faz barulho").

*(A detalhar: comportamento de aproximação, condição de "pegar" o jogador, indícios sonoros de proximidade.)*

## 5. Progressão

- **MVP:** Modo Campanha — um labirinto, do início ao fim.
- **Pós-MVP:** Modo Roguelike — múltiplos mapas, progresso de tentativas anteriores retorna como bônus permanente (upgrades/moedas) nas tentativas seguintes.

*(A detalhar: quais upgrades existem, curva de dificuldade entre mapas.)*

## 6. Áudio & Atmosfera

A atmosfera é construída quase inteiramente por áudio, já que o jogador não tem visão do ambiente externo.

*(A detalhar: camadas de áudio ambiente, sons de sonar, sons de colisão, sons de aproximação do inimigo, música/tensão dinâmica.)*

## 7. UI/UX

- Painel de botões de movimentação, centralizado na parte inferior da tela, na ordem **[◀ Girar Esq.] [▲ Andar] [Girar Dir. ▶]** — a ordem espacial espelha a ação (esquerda à esquerda, frente no centro), reduzindo erro de clique sob tensão. Acionado apenas por mouse (teclado não ativa os botões).
- Indicador de oxigênio.
- Indicador/feedback do sonar (quando ativado).

*(A detalhar: layout do painel, indicadores visuais mínimos já que o jogo é majoritariamente às escuras.)*

## 8. Escopo & Fora do Escopo (MVP)

**Dentro do MVP:**
- Movimentação por painel (Andar/Girar).
- Consumo de oxigênio por movimento e colisão.
- Um labirinto único, modo Campanha.

**Fora do MVP (pós-MVP / roguelike):**
- Geração procedural de labirintos.
- Progressão meta (upgrades/moedas entre tentativas).
- Múltiplos inimigos ou variações de inimigo.

## 9. Registro de Decisões

> Cada nova decisão de design tomada em conversas com a IA ou discussões de equipe deve ser registrada aqui, com data.

- **2026-10-06 — Layout do painel de movimentação:** botões na ordem Girar Esq. / Andar / Girar Dir., centralizados na base da tela, com input exclusivamente por mouse (sem atalhos de teclado), reforçando a fantasia de "operar um painel físico" dentro da cápsula.
