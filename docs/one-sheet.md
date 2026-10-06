# Profundidade Zero

*Profundidade Zero Studio · One-Sheet de Game Design*

| | |
|---|---|
| **Plataformas** | PC (Windows / Linux) — engine Godot 4. Build para web (itch.io) como meta secundária. |
| **Faixa etária** | 14+ (equivalente T / Teen) — tensão psicológica e perigo implícito, sem violência gráfica explícita. |
| **Classificação pretendida** | T (Teen) — conteúdo de suspense/horror atmosférico. |

## Resumo (foco em gameplay)

O jogador está preso dentro de uma cápsula submersa, sem qualquer visão do ambiente externo, guiando-a por um labirinto (representado como uma matriz com no mínimo um caminho válido) usando apenas um **painel visual de botões** e um sonar de uso limitado. Cada ativação do sonar revela a distância até o obstáculo mais próximo à frente — mas também carrega o risco de atrair algo no escuro. Colisões consomem oxigênio, o recurso central do jogo; esgotá-lo ou colidir repetidamente leva à morte. O objetivo é alcançar a saída administrando informação, risco e recursos escassos, em uma atmosfera construída quase inteiramente por áudio.

## Controles / Painel de movimentação

O jogo é em **primeira pessoa, dentro da cápsula**. Na tela há apenas um pequeno ponto central (a mira): o mouse movimenta o olhar pela cabine e o clique aciona o botão apontado. A movimentação **não** ocorre por teclado (setas/WASD), e sim por um **painel físico de botões dentro da cápsula**:

| Botão | Ação | Consome oxigênio? |
|---|---|---|
| **Andar** | Move a cápsula uma célula para frente, na direção atual | **Sim** |
| **Girar 90º Esquerda** | Rotaciona a cápsula 90º para a esquerda, sem se deslocar | Não |
| **Girar 90º Direita** | Rotaciona a cápsula 90º para a direita, sem se deslocar | Não |

Não existe movimento livre nem strafe: a cápsula sempre anda "para frente" na direção em que está apontada, e vira em incrementos de 90º. Apenas o ato de andar gasta oxigênio — girar é uma ação "gratuita" que só custa tempo/risco (ex.: se houver inimigo se aproximando por turno).

## Modos de gameplay

- **Modo Campanha (MVP):** um labirinto único, do ponto A ao ponto B.
- **Modo Roguelike (pós-MVP):** múltiplos mapas com dificuldade crescente; o progresso de uma tentativa que termina em morte retorna como bônus permanente (melhorias/moedas) na tentativa seguinte.

## Diferenciais de venda

- **Navegação 100% às cegas** — o horror nasce da privação sensorial e do áudio, não de sustos visuais roteirizados.
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
