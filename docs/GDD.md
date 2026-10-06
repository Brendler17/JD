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

### 2.1 Perspectiva & Interação (visão final)

- **Primeira pessoa, sempre dentro da cápsula 3D.** O jogador nunca vê o exterior: não há janelas, câmera externa nem mapa. Tudo o que se sabe do lado de fora chega por **som** (ambiente, colisões, sonar, inimigo).
- **Mira:** no centro da tela há apenas um pequeno ponto (a "mira"); não há HUD flutuante tradicional. O mouse movimenta o olhar dentro da cabine e o ponto indica o que está sendo apontado.
- **Painel físico (diegético):** os botões de movimentação (Andar / Girar Esq. / Girar Dir.) e demais controles (sonar, etc.) são objetos 3D num painel **dentro da cápsula**. O jogador aponta a mira para um botão e clica para acioná-lo.
- **Jogador parado (MVP):** o personagem fica sentado/fixo no posto de comando; só o olhar se move (mouse). Não há deslocamento dentro da cabine.
- **Stretch goal — andar pela cabine (WASD):** se sobrar tempo, permitir que o jogador se mova dentro da cápsula para interagir com outros pontos do submarino, como **anotações clicáveis** que abrem em tela e contam parte da história/lore. Fora do MVP (ver §8).
- **Indicadores diegéticos:** informações como oxigênio devem, idealmente, viver em instrumentos da própria cabine (mostradores, luzes, sons de alarme), e não em elementos 2D sobre a tela.
- **Estado atual (protótipo):** ainda não há assets nem texturas. Enquanto isso, o painel de botões, o medidor de oxigênio e a tela de fim são **UI 2D provisória** e a câmera é top-down de debug — todos substituíveis sem mudar as regras do jogo, pois se comunicam apenas por sinais.

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

| Parâmetro | Valor (MVP, ponto de partida) |
|---|---|
| Oxigênio inicial | 150 |
| Custo por "Andar" | 1 |
| Custo por colisão | 5 |
| Custo por girar | 0 |
| Regeneração | Nenhuma |

- Com o primeiro labirinto (menor caminho de 88 passos), sobram ~62 de margem: o equivalente a ~12 colisões ou a uma boa quantidade de becos sem saída. É um valor inicial para playtest, não final.
- Uma colisão custa o mesmo que 5 passos: bater na parede deve doer o suficiente para fazer o jogador hesitar antes de andar às cegas.
- **Chegar à saída com o último ponto de oxigênio conta como vitória.**
- Fim da partida: tela de vitória ("Saída alcançada") ou derrota ("Oxigênio esgotado"), com opção de tentar novamente (reinicia o mesmo labirinto).

### 4.4 Labirinto

- Representado como uma matriz (grade) com no mínimo um caminho válido entre entrada e saída.
- Modo Campanha (MVP): labirinto único, ponto A → ponto B.
- Modo Roguelike (pós-MVP): múltiplos mapas gerados, dificuldade crescente.
- Células: parede, livre, início (1) e saída (1). Tudo além dos limites do mapa é parede.
- **Colisão:** tentar andar para uma parede **não move** a cápsula — o comando é "desperdiçado" e conta como colisão (que custará oxigênio, conforme §4.3). O jogador sente a parede, mas não atravessa nem é empurrado.
- Primeiro labirinto do MVP: 15 × 15 células (4 m cada), início no canto inferior esquerdo, saída no canto superior direito, menor caminho de 88 passos. Tamanho e comprimento serão rebalanceados quando o consumo de oxigênio estiver definido.

### 4.5 Inimigo

- Invisível e intransponível.
- Reage ao uso do sonar (se aproxima quando o jogador "faz barulho").

- **Indícios de proximidade:** sirene + luz vermelha piscando (ver §6.3), metal rangendo/sendo espremido (§6.4) e — proposta — interferência crescente no rádio (§6.2).

*(A detalhar: comportamento de aproximação, condição de "pegar" o jogador.)*

## 5. Progressão

- **MVP:** Modo Campanha — um labirinto, do início ao fim.
- **Pós-MVP:** Modo Roguelike — múltiplos mapas, progresso de tentativas anteriores retorna como bônus permanente (upgrades/moedas) nas tentativas seguintes.

*(A detalhar: quais upgrades existem, curva de dificuldade entre mapas.)*

## 6. Áudio & Atmosfera

A atmosfera é construída quase inteiramente por áudio, já que o jogador não tem visão do ambiente externo.

### 6.1 Rádio do comandante (narrativa e tutorial)

- **Toda a informação inicial chega por áudio**, pela voz de alguém do lado de fora (um comandante/operador) falando por **rádio**. Nada de telas de tutorial ou textos explicativos.
- **Tom:** realista — como uma transmissão de verdade para o fundo do mar: voz comprimida/abafada, chiado, **interferências** e cortes ocasionais.
- **Conteúdo da introdução:** situar o jogador (quem é, o que faz ali, qual a missão) e ensinar o básico: como se mover pelo painel, como funciona o oxigênio, o custo das colisões e o sonar.
- **Proposta (a validar) — tutorial contextual:** manter a introdução curta (só contexto + "ande até a saída") e entregar o resto em falas disparadas na **primeira vez** que algo acontece: primeira colisão ("Cuidado, cada impacto compromete o casco e o ar."), primeiro uso do sonar, oxigênio baixo pela primeira vez. Jogadores esquecem informação dada toda de uma vez, e uma fala que chega no momento do evento ensina melhor e mantém o rádio vivo durante a partida.
- **Proposta (a validar) — legendas:** exibir legendas das falas do rádio (acessibilidade e apresentação em sala com som ruim). Opcional: botão de "repetir última transmissão" no painel.

### 6.2 Rádio e o inimigo

- Ideia levantada: disparar a voz do comandante quando o inimigo se revela.
- **Proposta (a validar):** usar a voz **uma única vez**, no **primeiro encontro** (fala roteirizada e assustada, que se perde em estática — "O que foi isso no sonar? ... repita... sinal... perdendo..."). Nos encontros seguintes, **sem fala**: só a **interferência do rádio aumentando** conforme o inimigo se aproxima. Motivo: no horror, explicar demais mata a tensão, e uma fala repetida vira rotina em poucos encontros. Já o rádio que "morre" perto da criatura vira um **sensor de proximidade diegético**, coerente com um jogo cego guiado por som.

### 6.3 Alarme: sirene + luz vermelha

- **Quando:** o jogador está em perigo — **inimigo próximo** ou **oxigênio baixo** (mesmo limiar do indicador, 25%).
- **Som:** sirene apitando.
- **Visual:** luz vermelha piscando dentro da cabine, bem *oldschool* (giroflex/lâmpada de alerta). No protótipo atual, pode ser um piscar vermelho sobre a tela até o cockpit existir.
- **Proposta (a validar) — distinguir as causas:** mesma luz vermelha, mas **sons diferentes** — oxigênio baixo = bipe de alarme ritmado; inimigo = sirene + metal rangendo. Se as duas causas soarem igual, o jogador não sabe se deve economizar ar ou fugir.
- **Proposta (a validar) — não mascarar o áudio do jogo:** como o jogo depende de ouvir o ambiente, a sirene não deve tocar contínua em volume alto. Opções: tocar em pulsos com pausas, abaixar a música/ambiente só nos picos, ou ter um **botão "silenciar alarme" no painel** — a luz continua piscando, mas o jogador escolhe recuperar a audição (decisão de risco extra, e um ótimo momento de tensão).

### 6.4 Camadas sonoras previstas

| Camada | Quando |
|---|---|
| Ambiente submarino (pressão, correntes, bolhas) | Sempre |
| Motor/propulsão | Ao andar |
| Servo/engrenagem | Ao girar |
| Impacto metálico forte | Colisão |
| Ping do sonar + eco | Uso do sonar |
| Metal rangendo / sendo espremido | Inimigo próximo (cresce com a proximidade) |
| Sirene | Perigo (inimigo) |
| Bipe de alarme | Oxigênio baixo |
| Rádio do comandante (voz + estática) | Introdução, eventos e encontros (ver §6.1–6.2) |

## 7. UI/UX

- Painel de botões de movimentação, centralizado na parte inferior da tela, na ordem **[◀ Girar Esq.] [▲ Andar] [Girar Dir. ▶]** — a ordem espacial espelha a ação (esquerda à esquerda, frente no centro), reduzindo erro de clique sob tensão. Acionado apenas por mouse (teclado não ativa os botões).
- Indicador de oxigênio no canto superior esquerdo (texto "O₂ atual / máximo" + barra), que fica vermelho com 25% ou menos.
- Tela de fim de partida (vitória/derrota) com botão "Tentar novamente"; o painel de movimentação é desabilitado ao fim.
- Indicador/feedback do sonar (quando ativado).
- **Na versão final, todos esses elementos ficam no painel 3D dentro da cápsula e são acionados pela mira central** (ver §2.1); o layout 2D atual é provisório e serve de referência para a disposição dos botões no painel físico.

*(A detalhar: layout do painel, indicadores visuais mínimos já que o jogo é majoritariamente às escuras.)*

## 8. Escopo & Fora do Escopo (MVP)

**Dentro do MVP:**
- Movimentação por painel (Andar/Girar).
- Consumo de oxigênio por movimento e colisão.
- Um labirinto único, modo Campanha.

**Fora do MVP (pós-MVP / roguelike / stretch goals):**
- Andar dentro da cabine (WASD) e anotações clicáveis de lore.
- Geração procedural de labirintos.
- Progressão meta (upgrades/moedas entre tentativas).
- Múltiplos inimigos ou variações de inimigo.

## 9. Registro de Decisões

> Cada nova decisão de design tomada em conversas com a IA ou discussões de equipe deve ser registrada aqui, com data.

- **2026-10-06 — Layout do painel de movimentação:** botões na ordem Girar Esq. / Andar / Girar Dir., centralizados na base da tela, com input exclusivamente por mouse (sem atalhos de teclado), reforçando a fantasia de "operar um painel físico" dentro da cápsula.
- **2026-10-06 — Movimentação direto no espaço 3D:** em vez de movimentar a cápsula numa matriz 2D e espelhar o resultado no 3D, a cápsula se move direto no mundo 3D, com a matriz servindo apenas como lógica (posição e colisão). Motivos: evitar o custo de manter duas representações sincronizadas e permitir visualizar o labirinto em 3D para depurar sua geração. Parâmetros definidos: **célula de 4 m**, **câmera de debug top-down fixa** (provisória, até existir a câmera em primeira pessoa do cockpit) e **movimento instantâneo** por enquanto (animação fica para a etapa de game feel).
- **2026-10-06 — Labirinto e colisão:** mapas definidos como texto (`#` parede, `.` livre, `S` início, `E` saída), editáveis direto no editor — o mesmo formato poderá ser gerado proceduralmente no modo Roguelike. Colidir com uma parede mantém a cápsula na mesma célula (sem deslocamento nem empurrão) e é registrado como colisão para fins de custo de oxigênio.
- **2026-10-06 — Valores iniciais de oxigênio e fim de partida:** oxigênio 150, −1 por passo, −5 por colisão, girar grátis, sem regeneração (valores de partida para playtest). Chegar à saída com o último ponto de oxigênio é vitória. Ao fim, tela de vitória/derrota com "Tentar novamente". O labirinto segue fixo por enquanto (facilita o balanceamento); geração procedural com seed foi discutida como próximo passo provável, para evitar que o jogador decore o mapa — decisão sobre a Campanha também ser procedural ainda em aberto.
- **2026-10-06 — Perspectiva final e interação por mira:** o jogo é em 1ª pessoa, dentro de uma cápsula 3D sem qualquer visão externa (informação só por som). Na tela há apenas um ponto central (mira); o mouse movimenta o olhar e o clique aciona o botão apontado, em um painel físico dentro da cabine. Assets/texturas ainda não existem; a UI 2D e a câmera top-down atuais são provisórias. Ver §2.1.
- **2026-10-06 — Jogador parado, rádio, alarme:** no MVP o jogador fica parado no posto de comando, só olhando com o mouse e interagindo com o painel; andar pela cabine com WASD e anotações de lore são stretch goals. Toda a introdução/tutorial chega por **rádio**, na voz de um comandante do lado de fora, com áudio realista e interferências. Situações de perigo (inimigo ou oxigênio baixo) disparam **sirene + luz vermelha piscando** (estilo *oldschool*), e o inimigo também traz **sons de metal sendo espremido**. Propostas registradas para validação: tutorial contextual, voz só no primeiro encontro com o inimigo + interferência como indicador de proximidade, sons de alarme distintos por causa e botão de silenciar alarme. Ver §6.
