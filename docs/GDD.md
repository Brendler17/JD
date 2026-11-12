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
- **Painel físico (diegético) — implementado:** toda a operação da cápsula acontece **no próprio painel do posto de comando**, dentro da cabine (ver §7). Não existe mais tela 2D sobreposta ao sentar.
- **Andando pela cabine (implementado):** em pé, o jogador anda com WASD/setas e olha com o mouse; a mira central indica o que pode ser acionado (clique esquerdo). Objetos examináveis (rádio, terminal, cilindros, escotilha, caderno) abrem um texto curto de lore/dica. O antigo "jogador parado (MVP)" foi superado por essa implementação.
- **Sentado no posto:** clicar na cadeira ou no painel senta o jogador. O **cursor fica livre** e o jogador clica diretamente nos controles do painel. Encostar o cursor nas bordas da tela gira o olhar naquela direção (para cima, o monitor superior e o knob do alarme), e o olhar **fica onde parou** quando o cursor volta ao meio (*edge-pan*). Assim o que se vê não escorrega de baixo do cursor na hora de clicar. Clique direito levanta. *Decisão:* em pé usa-se a mira; sentado, o cursor — mais preciso para um painel com vários controles pequenos, sem perder a diegese.
- **Indicadores diegéticos:** oxigênio e interferência são **mostradores analógicos** do painel, o mapa do sonar aparece na **tela CRT**, o registro de eventos no **monitor superior**, e o perigo pisca na luz vermelha da cabine — nada flutua sobre a tela.
- **Estado atual:** a cabine usa o modelo importado da demo em Unreal (ver §2.2). Restam como UI 2D apenas a mira/prompt (em pé), o visualizador de textos e a tela de fim de partida.

### 2.2 Direção de arte (referência: demo em Unreal)

- **Referência visual:** vídeo da demo em Unreal (`Profundidade Zero - Demo Unreal.mp4`, fora do repositório). Cabine **escura**, iluminada por poucas luzes pontuais quentes, com paredes metálicas em tons de ferrugem, faixas de luz laranja e telas emissivas nítidas (monitor vermelho, CRT ciano) como principais fontes de cor.
- **Iluminação na Godot:** ajustada para se aproximar desse clima (pouca luz ambiente, contraste, luzes de acento laranja e brilho/bloom nas telas).
- **Limitação conhecida:** a cabine foi exportada da Unreal como **uma única malha mesclada com um único atlas de textura 2048×2048** (*Merge Actors*). Cada objeto recebe poucos pixels dessa imagem, então tudo fica borrado de perto, sobretudo o painel. O tom ferrugem das paredes também se perdeu na mesclagem (na Godot as paredes saem brancas). As telas do painel já foram resolvidas sobrepondo telas renderizadas pelo jogo (§7). Para o resto, ver opções no TDD §11.

### 2.3 Narrativa & Lore

**Premissa (o que o jogador ouve):** a Superfície (centro de operações de uma empresa de pesquisa oceânica) desceu a **Cápsula Dez** a **4.000 metros**, numa descida que deveria ser de rotina até a **Estação Tétis**, uma estação de pesquisa no fundo de um sistema de galerias de rocha. O cabo de reboque rompeu. Sem janelas e sem câmeras, o jogador precisa guiar a cápsula pelas galerias (o labirinto) até um ponto de resgate marcado no sonar, onde a Superfície consegue engatar outro cabo.

**A verdade (o que a Superfície esconde):**
1. **A Estação Tétis parou de responder** antes de qualquer cápsula descer. A "descida de rotina" é, na verdade, uma tentativa de descobrir o que aconteceu.
2. **Dez cápsulas desceram antes** (da Zero à Nove) e nenhuma voltou. O teaser é a última transmissão da **Cápsula Zero**, a primeira. A Cápsula Dez é a próxima da fila, e o comandante já fez essa chamada dez vezes.
3. **Existe algo lá embaixo**: uma criatura que nunca é vista e que reage ao som. A Superfície sabe que ela existe (os sinais das outras cápsulas sumiram do mesmo jeito), mas não sabe o que é. Prefere não contar, para o piloto não desistir.

**Como o jogador descobre (em camadas, nunca de forma explícita):**

| Camada | Canal | Exemplo |
|---|---|---|
| Deslizes no rádio | Falas que começam a revelar algo e se corrigem | "Mas lá embaixo... o pulso viaja longe."; "Não. De novo não..."; "Ninguém chegou tão... vocês estão perto." |
| Objetos da cabine | Textos examináveis (§2.1) | Etiqueta do rádio com "Tétis" riscado; terminal com um registro corrompido da "CÁPSULA 09 — SINAL PERDIDO"; dez riscos gravados na escotilha |
| Desfecho | Fala final de cada resultado | Vitória: "você foi a primeira a voltar". Derrota: "Registre... sinal perdido. Preparem a Onze." |

**Regras de tom:**
- A criatura **nunca é mostrada nem nomeada**. O horror vem do que o comandante não diz.
- O comandante não é vilão: é um profissional cansado que mente por protocolo e por culpa. As falas soam controladas, e é nos deslizes que ele se revela.
- Nada de exposição longa. Cada revelação cabe numa frase ou num objeto.
- O jogador é anônimo: só "Cápsula Dez".

**Em aberto (decidir depois):** o que é a criatura e o que houve com a Tétis (de propósito, pode nunca ser respondido); se, no modo roguelike, cada nova tentativa vira a "Cápsula Onze", "Doze"... (a fala de derrota já deixa essa porta aberta).

*(A detalhar: moodboard e referências de tom.)*

## 3. Core Loop

1. Jogador avalia a situação (áudio ambiente, oxigênio restante, última leitura de sonar).
2. Jogador decide: ativar o sonar (arriscar atrair inimigo, ganhar informação) e/ou usar o painel de movimentação.
3. Jogador usa o painel de movimentação para agir.
4. O ambiente reage (colisão consome oxigênio, inimigo pode se aproximar).
5. Volta ao passo 1, até alcançar a saída (vitória) ou esgotar oxigênio / ser alcançado (derrota).

## 4. Mecânicas

### 4.1 Painel de Movimentação

O jogador **não** controla a cápsula por teclado. A movimentação ocorre por um **teclado em cruz no painel do posto de comando** (área central do painel amarelo), clicado com o mouse:

| Botão | Ação | Custo de oxigênio |
|---|---|---|
| ▲ Frente | Move a cápsula uma célula para frente, na direção em que está apontada | 1 |
| ▼ Ré | Recua uma célula, sem girar | 1 |
| ◀ Girar 90º | Rotaciona a cápsula 90º à esquerda, sem deslocamento | 1 |
| Girar 90º ▶ | Rotaciona a cápsula 90º à direita, sem deslocamento | 1 |
| (( · )) Sonar | Pulso de sonar nas 4 direções (§4.2) | 4 |

Regras:
- A cápsula só se move para frente ou para trás em relação à direção atual — não há strafe nem movimento livre.
- Toda ação custa oxigênio e dá um turno ao inimigo (§4.5); colidir custa mais (§4.3).
- **Manobras têm duração (game feel, implementado):** andar/ré levam 1,0 s, girar 0,8 s e sonar 0,9 s. Durante a manobra, a tecla acionada fica afundada, as outras travam e a tela mostra "AVANÇANDO…", "GIRANDO…" ou "AGUARDANDO ECO…". O **resultado só chega no fim**: a batida na parede vem depois de quase um segundo de motor ligado (antecipação: "será que tem parede?"), o eco do sonar volta depois do ping, e só então o inimigo age. Cada clique vira um compromisso, o que reforça a tensão de andar às cegas.
- **Sensação física:** motor ao andar (corta seco no impacto, some em fade ao chegar), rangido do casco ao girar, inclinação da cabine (para trás/frente ao andar, para o lado da curva ao girar) e vibração leve durante o deslocamento.

### 4.2 Sonar

- **Implementado:** cada pulso revela, nas **4 direções**, o primeiro obstáculo atingido, que fica registrado no mapa da tela CRT. O resto do corredor continua desconhecido.
- **Custo:** 4 de oxigênio por pulso, sem limite de usos (o custo em O₂ e o risco já limitam o uso).
- **Risco:** cada pulso atrai o inimigo para o ponto de onde saiu (§4.5). Um eco que passa pela criatura aparece como **ponto vermelho passageiro**.

*(A detalhar: feedback sonoro do ping/eco.)*

### 4.3 Oxigênio

- Recurso central e condição de derrota.
- Consumido ao usar o botão Andar e por colisões.
- Esgotar oxigênio ou colidir repetidamente leva à morte.

| Parâmetro | Valor (MVP, ponto de partida) |
|---|---|
| Oxigênio inicial | 200 |
| Custo por Frente/Ré | 1 |
| Custo por girar | 1 |
| Custo por sonar | 4 |
| Custo por colisão | 8 |
| Regeneração | Nenhuma |

- Valores atuais de playtest (revisados em 2026-10-27, junto com o labirinto procedural, quando girar e sonar passaram a custar). Não são finais.
- Uma colisão custa o mesmo que 8 passos: bater na parede deve doer o suficiente para fazer o jogador hesitar antes de andar às cegas.
- **Leitura:** mostrador analógico de O₂ no painel (faixa vermelha nos últimos 25%) e valor numérico no monitor superior.
- **Chegar à saída com o último ponto de oxigênio conta como vitória.**
- Fim da partida: tela de vitória ("Saída alcançada") ou derrota ("Oxigênio esgotado"), com opção de tentar novamente (gera um labirinto novo, ver §4.4).

### 4.4 Labirinto

- Representado como uma matriz (grade) com no mínimo um caminho válido entre entrada e saída.
- Modo Campanha (MVP): labirinto único, ponto A → ponto B.
- Modo Roguelike (pós-MVP): múltiplos mapas gerados, dificuldade crescente.
- Células: parede, livre, início (1) e saída (1). Tudo além dos limites do mapa é parede.
- **Colisão:** tentar andar para uma parede **não move** a cápsula — o comando é "desperdiçado" e conta como colisão (que custará oxigênio, conforme §4.3). O jogador sente a parede, mas não atravessa nem é empurrado.
- **Geração procedural (implementada):** cada partida, e cada "Tentar novamente", gera um labirinto novo de 15 × 15 células (4 m cada), com alguns caminhos alternativos. O menor caminho até a saída é sempre ≥ 1/4 das células livres. Ainda é possível fixar uma semente ou um mapa escrito à mão para testes e balanceamento.

### 4.5 Inimigo

- Invisível e intransponível.
- Reage ao uso do sonar (se aproxima quando o jogador "faz barulho").

- **Indícios de proximidade:** sirene + luz vermelha piscando (ver §6.3), metal rangendo/sendo espremido (§6.4) e — proposta — interferência crescente no rádio (§6.2).

- **Comportamento (implementado, valores para playtest):** age em turnos — cada ação do jogador (andar, girar, colidir, sonar) dá um turno à criatura. Normalmente vaga devagar (1 célula a cada 2 turnos). **Cada pulso de sonar a faz caçar o ponto de onde o pulso saiu**, 1 célula por turno; se o jogador já tiver saído dali, ela perde o rastro e volta a vagar. A 2 células ou menos, ela sente a cápsula e a persegue diretamente.
- **Condição de derrota:** a criatura alcançar a célula da cápsula (ou a cápsula entrar na célula dela) — tela "CONTATO".
- **Leitura pelo jogador:** nunca aparece no mapa de forma permanente. Um sinal de sonar que passa por ela devolve um **eco vermelho** passageiro; o **medidor de interferência** do painel sobe conforme ela se aproxima; a ≤ 4 células, **luz vermelha da cabine** + "ALERTA: CONTATO PRÓXIMO" no painel.

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
- **Roteiro definido:** 13 falas (introdução, cobrança para sentar, primeiro uso do painel, primeira colisão, primeiro sonar, primeiro alarme, primeiro encontro com a criatura, O₂ baixo, aviso sobre a Estação Tétis, perto da saída, vitória e duas derrotas) em [`roteiro-radio.md`](roteiro-radio.md), escritas segundo a lore (§2.3): o comandante esconde a verdade e se revela em deslizes. Identificação no rádio: "Superfície" (comandante) e "Cápsula Dez" (jogador). Várias frases repetem o teaser (protocolo decorado). Vozes geradas pela equipe com a mesma voz do teaser, gravadas limpas; o efeito de rádio é aplicado pelo jogo.
- **Implementado — rádio no jogo:** as 13 falas tocam nos gatilhos do roteiro, no máximo uma vez por partida, uma por vez. O comandante se **interrompe** no meio de uma fala comum quando a criatura aparece pela primeira vez ("Espera... o que foi isso?"). Dicas que esperariam demais na fila são descartadas e voltam a valer se o evento se repetir, para nenhuma dica chegar fora de hora. A voz passa por filtro de rádio, com estática e chiado de abrir e fechar a transmissão.
- **Implementado — legendas:** na base da tela, com o texto revelado no ritmo da fala (acessibilidade e apresentação em sala com som ruim). Ficaram fora do monitor superior porque, sentado no posto, ele quase não aparece no campo de visão; o monitor só registra "TRANSMISSÃO RECEBIDA". *Opcional (não feito):* botão de "repetir última transmissão" no painel.
- **Implementado — o desfecho é do rádio:** no fim da partida, a tela de vitória/derrota só aparece depois da última fala do comandante (um clique antecipa). A fala final é o fecho da história e não compete com a tela.

### 6.2 Rádio e o inimigo

- Ideia levantada: disparar a voz do comandante quando o inimigo se revela.
- **Implementado** (validar em playtest): usar a voz **uma única vez**, no **primeiro encontro** (fala roteirizada e assustada, que se perde em estática — "O que foi isso no sonar? ... repita... sinal... perdendo..."). Nos encontros seguintes, **sem fala**: só a **interferência do rádio aumentando** conforme o inimigo se aproxima. Motivo: no horror, explicar demais mata a tensão, e uma fala repetida vira rotina em poucos encontros. Já o rádio que "morre" perto da criatura vira um **sensor de proximidade diegético**, coerente com um jogo cego guiado por som.

### 6.3 Alarme: sirene + luz vermelha

- **Quando:** o jogador está em perigo — **inimigo próximo** ou **oxigênio baixo** (mesmo limiar do indicador, 25%).
- **Som:** sirene apitando.
- **Visual:** luz vermelha piscando dentro da cabine, bem *oldschool* (giroflex/lâmpada de alerta). No protótipo atual, pode ser um piscar vermelho sobre a tela até o cockpit existir.
- **Proposta (a validar) — distinguir as causas:** mesma luz vermelha, mas **sons diferentes** — oxigênio baixo = bipe de alarme ritmado; inimigo = sirene + metal rangendo. Se as duas causas soarem igual, o jogador não sabe se deve economizar ar ou fugir.
- **Implementado — silenciar alarme:** knob vermelho sob o monitor superior. Corta o **som** dos alarmes ativos (sirene e bipe), mas a luz vermelha continua piscando. Só funciona com algum alarme tocando. Um perigo **novo**, ou o fim de todos os alarmes, rearma o som sozinho, para o jogador não silenciar uma vez e esquecer. O monitor registra "ALARME SILENCIADO" e "ALARME REARMADO".
- **Implementado — sons distintos:** inimigo = sirene; O₂ baixo = bipe duplo (gerado proceduralmente, distinto da sirene).
- **Proposta (a validar) — não mascarar o áudio do jogo:** como o jogo depende de ouvir o ambiente, a sirene não deve tocar contínua em volume alto. Opções: tocar em pulsos com pausas, abaixar a música/ambiente só nos picos, ou ter um **botão "silenciar alarme" no painel** — a luz continua piscando, mas o jogador escolhe recuperar a audição (decisão de risco extra, e um ótimo momento de tensão).

### 6.4 Camadas sonoras previstas

Status: ✅ = implementado (`AudioManager`, com SFX em `assets/audio/sfx/`).

| Camada | Quando |
|---|---|
| Ambiente submarino (pressão, correntes, bolhas) | Sempre ✅ |
| Motor/propulsão | Ao andar ✅ (pitch mais grave na ré) |
| Servo/engrenagem → rangido do casco | Ao girar ✅ (2 variações, pitch aleatório) |
| Impacto metálico forte | Colisão ✅ |
| Ping do sonar + eco | Uso do sonar ✅ (+ rosnado quando o eco passa pelo inimigo ✅) |
| Metal rangendo / sendo espremido | Inimigo a ≤ 4 passos, mais alto quanto mais perto ✅ |
| Sirene | Perigo (inimigo) ✅ |
| Bipe de alarme | Oxigênio baixo ✅ |
| Rádio do comandante (voz + estática) | Introdução, eventos e encontros (ver §6.1–6.2) ✅ |
| Estática do rádio sem voz | Criatura perto: sobe com a proximidade (sensor diegético) ✅ |
| Ronco grave de tensão (camada de ambiente) | Cresce conforme a criatura se aproxima ✅ |
| Chamado distante da criatura | Logo após um pulso de sonar que ela ouviu, se estiver a ≤ 10 passos ✅ |
| Clique mecânico | Teclas e knob do painel ✅ |
| Criatura alcança a cápsula | Derrota por contato ✅ |

## 7. UI/UX

### 7.1 Posto de comando (painel diegético) — implementado

Tudo vive no painel físico em frente à cadeira, operado com o cursor quando o jogador está sentado (§2.1):

| Instrumento do painel | O que mostra / faz |
|---|---|
| Relógio superior esquerdo | **O₂**: ponteiro cai a cada ação; faixa vermelha nos 25% finais |
| Relógio inferior esquerdo | **Interferência**: sobe e treme conforme o inimigo se aproxima (sensor diegético de proximidade) |
| Área central — tela | **Rumo** atual, **estado da manobra** (PRONTO / AVANÇANDO… / GIRANDO… / AGUARDANDO ECO…) e alerta piscando (CONTATO PRÓXIMO / O₂ BAIXO) |
| Área central — teclas | **Teclas físicas 3D** em cruz Frente/Ré/Girar/Sonar (§4.1). Brilham no hover e afundam com clique sonoro ao pressionar. Só acionam se soltas em cima da tecla, então dá para desistir arrastando para fora. Durante a manobra, a tecla acionada fica afundada e acesa e as outras escurecem |
| Knob vermelho (sob o monitor) | **Silenciar alarme** (§6.3): acende em âmbar enquanto o som está silenciado |
| Tela CRT (direita) | **Mapa do sonar**: paredes descobertas por sonar/colisão, rastro, posição e rumo, saída em verde, eco vermelho do inimigo |
| Monitor superior (vermelho) | **Registro** de eventos (deslocamento, impacto, pulso, alertas), O₂ numérico e tabela de custos |

- Layout do teclado em cruz: a disposição espacial espelha a ação (frente em cima, ré embaixo, giros nas laterais), reduzindo erro de clique sob tensão. Acionado apenas por mouse.
- No fim da partida, o teclado é desabilitado e aparece a tela de fim (vitória/derrota) com "Tentar novamente" (ainda 2D).

*(A detalhar: usar os outros 3 knobs (ex.: volume do rádio, brilho do sonar). Legendas do rádio: implementadas na base da tela, ver §6.1.)*

## 8. Escopo & Fora do Escopo (MVP)

**Dentro do MVP:**
- Movimentação pelo painel diegético (Frente/Ré/Girar/Sonar).
- Consumo de oxigênio por ação e colisão.
- Inimigo atraído pelo sonar.
- Modo Campanha, ponto A → ponto B.

**Já implementado além do escopo original do MVP:**
- Andar dentro da cabine (WASD) e textos examináveis de lore.
- Geração procedural de labirintos.

**Fora do MVP (pós-MVP / roguelike / stretch goals):**
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
- **2026-10-27 — Cabine 3D, andar pela cabine, painel em cruz e labirinto procedural** *(registro retroativo, a partir do TDD)*: a cabine importada da demo em Unreal virou a cena principal. O jogador anda com WASD, examina objetos com a mira e senta no posto para navegar. O teclado ganhou Ré e Sonar, e o oxigênio foi rebalanceado (200; mover/ré/girar 1; sonar 4; colisão 8). Cada partida gera um labirinto novo. Ver §2.1, §4.1, §4.3 e §4.4.
- **2026-10-27 — Inimigo implementado:** turnos atrelados às ações do jogador; sonar atrai a criatura para o ponto do pulso (fugir depois de usar o sonar é a resposta ao risco); a 2 células ela sente a cápsula; contato = derrota. Proximidade comunicada por interferência no painel, eco vermelho no sonar e luz vermelha a ≤ 4 células. Valores iniciais para playtest. Ver §4.5.
- **2026-11-11 — Painel diegético, direção de arte e iluminação:** a tela 2D que abria ao sentar (O₂, mapa, teclado e status sobrepostos à cena) foi removida, porque quebrava a imersão proposta. Agora **tudo acontece no painel da cabine**: O₂ e interferência em mostradores analógicos, teclado na área central do painel amarelo, mapa do sonar no CRT e registro de eventos no monitor superior. Sentado, o jogador usa o **cursor livre** para clicar no painel, e levar o cursor às bordas gira o olhar. Em pé, segue a mira. A iluminação foi escurecida para se aproximar da demo em Unreal (pouca luz ambiente, acentos laranja, brilho nas telas). Registrada a limitação do atlas único da cabine importada (texturas borradas e paredes sem o tom ferrugem). Ver §2.1, §2.2 e §7.1.
- **2026-11-11 — Teclas físicas, silenciar alarme, áudio e olhar por edge-pan:** as teclas desenhadas na tela viraram **teclas 3D** com curso, brilho de hover e clique sonoro (dá para desistir soltando fora da tecla). Um knob vermelho sob o monitor **silencia o som do alarme**, mantendo a luz, e se rearma com um perigo novo ou quando os alarmes acabam. Primeiro áudio no jogo: ambiente, impacto, sonar, eco do inimigo, metal rangendo por proximidade, sirene (inimigo), bipe (O₂) e som de captura. O olhar sentado passou a ser *edge-pan*, que mantém a orientação, porque no modelo anterior o olhar voltava ao centro e o knob escorregava de baixo do cursor. Ver §2.1, §6.3, §6.4 e §7.1.
- **2026-11-11 — Peso das ações (manobras com duração):** cada ação da cápsula leva tempo (andar/ré 1,0 s, girar 0,8 s, sonar 0,9 s) e o resultado (impacto, eco do sonar, turno do inimigo) só chega no fim. Durante a manobra o painel trava. Novos sons de motor e de rangido ao girar (Freesound, CC0, ver `assets/audio/CREDITS.md`), inclinação e vibração da cabine. *Motivo:* antes, clicar "Frente" só mudava um ponteiro e um ponto no mapa, então a ação central não tinha peso físico nem antecipação. Valores para playtest. Ver §4.1 e §6.4.
- **2026-11-11 — Roteiro do rádio:** escritas as 12 falas do comandante, com gatilho e tom de cada uma, em `docs/roteiro-radio.md`. Seguem o tutorial contextual (§6.1) e a regra de voz só no primeiro encontro com a criatura (§6.2). As derrotas terminam com o comandante chamando sem resposta, em vez de uma tela explicativa. Áudios a gerar pela equipe; sistema de reprodução ainda não implementado.
- **2026-11-11 — Lore definida (direção "resgate + mistério"):** a Cápsula Dez desce a 4.000 m numa "descida de rotina" até a Estação Tétis. O cabo rompe e é preciso chegar ao ponto de resgate. A Superfície esconde que a Tétis parou de responder, que dez cápsulas (Zero a Nove) desceram antes sem voltar e que existe uma criatura que reage ao som. O teaser passa a ser a **última transmissão da Cápsula Zero**. A verdade chega em camadas: deslizes do comandante no rádio, objetos examináveis da cabine (textos reescritos) e a fala final (vitória: "você foi a primeira a voltar"; derrota: "preparem a Onze"). Roteiro revisado para 13 falas. Ver §2.3 e §6.1.
- **2026-11-12 — Rádio implementado e novas camadas de som:** o rádio do comandante entrou no jogo com as 13 falas gravadas, legendas na base da tela (o monitor superior fica fora da vista no posto) e interferência que cresce com a proximidade da criatura, inclusive sem fala. A primeira aparição da criatura **interrompe** o comandante. A tela de fim espera a fala final, que é o desfecho da história. Som: o ambiente ganhou uma camada grave de tensão ligada à proximidade e um **chamado distante da criatura logo depois de um sonar que ela ouviu**, dando ao jogador o retorno do risco central (o sonar atrai a criatura) sem texto. Corrigido o buraco de silêncio que o laço do ambiente deixava a cada 48 s. Ver §6.
