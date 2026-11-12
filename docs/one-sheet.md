# Profundidade Zero

*Profundidade Zero Studio · One-Sheet de Game Design*

| | |
|---|---|
| **Plataformas** | PC (Windows / Linux) — engine Godot 4. Build para web (itch.io) como meta secundária. |
| **Faixa etária** | 14+ (equivalente T / Teen) — tensão psicológica e perigo implícito, sem violência gráfica explícita. |
| **Classificação pretendida** | T (Teen) — conteúdo de suspense/horror atmosférico. |

## Resumo (foco em gameplay)

O jogador está preso dentro de uma cápsula submersa, sem qualquer visão do ambiente externo, guiando-a por um labirinto (representado como uma matriz com no mínimo um caminho válido) usando apenas o **painel físico do posto de comando** e um sonar. Cada pulso do sonar revela os obstáculos mais próximos ao redor — mas também carrega o risco de atrair algo no escuro. Colisões consomem oxigênio, o recurso central do jogo; esgotá-lo ou colidir repetidamente leva à morte. O objetivo é alcançar a saída administrando informação, risco e recursos escassos, em uma atmosfera construída quase inteiramente por áudio.

## Controles / Painel de movimentação

O jogo é em **primeira pessoa, dentro da cápsula**. Em pé, o jogador anda pela cabine e examina objetos com a mira. Para navegar, ele **senta no posto de comando e opera o painel físico com o mouse**: não existe tela sobreposta, e oxigênio, sonar, rumo e alertas aparecem nos próprios instrumentos da cabine (mostradores, tela CRT, monitor). A cápsula **não** é pilotada por teclado, e sim pelos botões do painel:

| Botão | Ação | Custo de oxigênio |
|---|---|---|
| **Frente / Ré** | Move a cápsula uma célula para frente ou para trás | 1 |
| **Girar 90º Esq./Dir.** | Rotaciona a cápsula 90º, sem se deslocar | 1 |
| **Sonar** | Revela o primeiro obstáculo nas 4 direções e atrai a criatura | 4 |

Não existe movimento livre nem strafe: a cápsula anda só na direção em que está apontada e vira em incrementos de 90º. Bater numa parede custa caro (8).

## Modos de gameplay

- **Modo Campanha (MVP):** um labirinto único, do ponto A ao ponto B.
- **Modo Roguelike (pós-MVP):** múltiplos mapas com dificuldade crescente; o progresso de uma tentativa que termina em morte retorna como bônus permanente (melhorias/moedas) na tentativa seguinte.

## Diferenciais de venda

- **Navegação 100% às cegas** — o horror nasce da privação sensorial e do áudio, não de sustos visuais roteirizados.
- **Narrativa e tutorial pelo rádio** — o jogador é situado e instruído apenas pela voz de um comandante do lado de fora, numa transmissão cheia de estática e interferências; sirene e luz vermelha piscando anunciam o perigo.
- **Sonar como faca de dois gumes** — obter informação tem preço: cada uso pode atrair um inimigo invisível e intransponível.
- **Escopo gráfico enxuto, execução afiada** — toda a produção acontece dentro da cápsula, liberando o tempo do time para polir áudio e sistemas em vez de arte 3D cara.
- **Progressão por risco calculado** — oxigênio, sonar e dano acumulado criam decisões constantes de risco x recompensa.
- **Replayability roguelike** — labirintos regenerados e progressão meta (upgrades) recompensam tentativas repetidas.

## Produtos concorrentes

- **Iron Lung** (David Szymanski) — referência direta de atmosfera e câmera em primeira pessoa dentro de um veículo isolado.
- **Duskers** (Misfits Attic) — exploração às cegas de ambientes hostis via sensores, com gerenciamento de recursos escassos.
- **Phasmophobia** (Kinetic Games) — horror centrado em pistas sonoras/sensoriais como mecânica principal de jogo.

---

Disciplina de Jogos Digitais — Ciência da Computação · Engine: Godot 4 · Equipe: 2 integrantes
