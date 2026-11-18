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
- **Sentado no posto:** clicar na cadeira ou no painel senta o jogador. A **mira continua no centro da tela** e o mouse move o olhar, dentro de um limite (±40° para os lados, 50° para cima e 20° para baixo), o bastante para alcançar com folga o knob do alarme, os mostradores e o monitor superior inteiro. O controle sob a mira acende e a mira muda de cor. O clique esquerdo aciona o controle sob a mira. Clique direito levanta. *Decisão (2026-11-12):* a mira vale também sentado, no lugar do cursor livre com olhar pelas bordas. O controle fica igual em pé e sentado, e operar o painel passa a ser olhar para a tecla, o que é mais imersivo.
- **Indicadores diegéticos:** oxigênio e interferência são **mostradores analógicos** do painel, o mapa do sonar aparece na **tela CRT**, o registro de eventos no **monitor superior**, O₂ numérico, casco e custos no **monitor lateral esquerdo** ("Suporte de vida"), e o perigo pisca na luz vermelha da cabine — nada flutua sobre a tela.
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
- Toda ação custa oxigênio. Andar, ré, colidir e sonar dão um turno ao inimigo; **girar não** (desde 2026-11-16, §4.6.1). Colidir custa mais (§4.3).
- **Manobras têm duração (game feel, implementado):** andar/ré levam 1,0 s, girar 0,8 s e sonar 0,9 s. Durante a manobra, a tecla acionada fica afundada, as outras travam e a tela mostra "AVANÇANDO…", "GIRANDO…" ou "AGUARDANDO ECO…". O **resultado só chega no fim**: a batida na parede vem depois de quase um segundo de motor ligado (antecipação: "será que tem parede?"), o eco do sonar volta depois do ping, e só então o inimigo age. Cada clique vira um compromisso, o que reforça a tensão de andar às cegas.
- **Sensação física:** motor ao andar (corta seco no impacto, some em fade ao chegar), rangido do casco ao girar, inclinação da cabine (para trás/frente ao andar, para o lado da curva ao girar) e vibração leve durante o deslocamento.

### 4.2 Sonar

- **Implementado:** cada pulso revela, nas **4 direções**, o primeiro obstáculo atingido, que fica registrado no mapa da tela CRT. O resto do corredor continua desconhecido.
- **Custo:** 4 de oxigênio por pulso, sem limite de usos (o custo em O₂ e o risco já limitam o uso).
- **Risco:** cada pulso atrai o inimigo para o ponto de onde saiu (§4.5).
- **Raio de detecção (implementado):** o pulso revela a criatura como **ponto vermelho passageiro** se ela estiver a até **4,5 células** em linha reta (atravessando paredes) ou no feixe reto de uma das 4 direções. Um anel se expande no CRT até o limite do raio, para o jogador entender o alcance. O sonar vira a ferramenta para planejar a fuga, e o dilema fica claro: ver onde ela está custa chamá-la.

*(A detalhar: feedback sonoro do ping/eco.)*

### 4.3 Oxigênio

- Recurso central e condição de derrota.
- Consumido ao usar o botão Andar e por colisões.
- Esgotar oxigênio ou colidir repetidamente leva à morte.

| Parâmetro | Valor (MVP, ponto de partida) |
|---|---|
| Oxigênio inicial | 240 *(era 200 até 2026-11-16, §4.6.1)* |
| Custo por Frente/Ré | 1 |
| Custo por girar | 1 |
| Custo por sonar | 4 |
| Custo por colisão | 8 |
| Regeneração | Nenhuma |

- Valores atuais de playtest (revisados em 2026-10-27, junto com o labirinto procedural, quando girar e sonar passaram a custar). Não são finais.
- Uma colisão custa o mesmo que 8 passos: bater na parede deve doer o suficiente para fazer o jogador hesitar antes de andar às cegas.
- **Leitura:** mostrador analógico de O₂ no painel (escala invertida: cheio à esquerda, ponteiro sobe para a faixa vermelha à direita nos últimos 25%) e valor numérico grande, com barra, no monitor lateral esquerdo ("Suporte de vida", §7.1).
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

- **Comportamento (implementado, valores para playtest; rebalanceado em 2026-11-12, ver §4.6):** age em turnos — andar, ré, colidir e sonar dão um turno à criatura (girar não, desde 2026-11-16). Nos primeiros 15 turnos ela dorme (período de calma, §4.6.1). Normalmente vaga devagar (1 célula a cada 2 turnos). **Cada pulso de sonar a faz caçar o ponto de onde o pulso saiu**, 1 célula por turno; se não achar a cápsula lá, ela mergulha e reaparece longe. A 2 células ou menos, ela sente a cápsula e passa a **rondá-la devagar** (1 célula a cada 2 turnos); encostada, joga o dado a cada turno (ataca ou hesita).
- **Condição de derrota:** o casco aguenta **2 golpes**; o **3º** rompe o casco — tela "CONTATO". Cada golpe que o casco aguenta a faz mergulhar e reaparecer longe.
- **Leitura pelo jogador:** nunca aparece no mapa de forma permanente. Um sinal de sonar que passa por ela devolve um **eco vermelho** passageiro; o **medidor de interferência** do painel sobe conforme ela se aproxima; a ≤ 4 células, **luz vermelha da cabine** + "ALERTA: CONTATO PRÓXIMO" no painel.
- **Ouvir a criatura (implementado):** quando um pulso a coloca em caça e ela está a ≤ 10 casas, um chamado distante responde logo depois. É o retorno do risco do sonar.
- **Derrota por contato (implementado):** a cápsula leva um golpe violento (tranco de câmera, impacto e rugido), as luzes e as telas falham por ~2,4 s com um segundo golpe no meio, e então tudo apaga. Uma luz ainda tenta voltar uma vez. O ambiente morre e o comandante chama no escuro ("perdemos sua telemetria... igual às outras") antes da tela de fim.

### 4.6 Rebalanceamento da criatura (implementado em 2026-11-12, valores para playtest)

**Problema (relatado em playtest, 2026-11-12):** a vitória é praticamente impossível.
- Em caça, a criatura anda 1 casa por turno, a mesma velocidade do jogador. Girar gasta um turno sem sair do lugar, então ela ganha terreno em toda curva.
- A ≤ 2 casas ela persegue a cápsula para sempre.
- O sonar é necessário para navegar e a chama na velocidade máxima.
- O contato mata na hora. O caminho até a saída leva ~50 ações, e ela nasce a 10 casas.

**Combinação aprovada pelo usuário (opções B + C + A dentro da C + D):**

| Regra | Proposta (valores para playtest) |
|---|---|
| **C. Casco com integridade** | 3 pontos. Cada ataque tira 1; o 3º dispara a sequência de contato (`CaughtSequence`, já implementada). Ataque não letal: `cabin_impact(~0.7)`, luzes e telas piscam ~1 s, e o casco fica visível no painel |
| **A. Dado quando adjacente** | Ao sentir a cápsula (≤ 2 casas), ela **ronda**: anda 1 casa a cada 2 turnos (mais lenta que a cápsula, o que abre uma janela de fuga) e perde o rastro se a cápsula passar de 4 casas. Encostada (1 casa): a cada turno, **60% hesita** (fica parada ao lado) e **40% ataca**. *(60% confirmado pelo usuário; rebalancear se preciso.)* |
| **D. Sonar com ela perto** | Usar o sonar com ela dentro do raio (`SONAR_DETECT_RADIUS` = 4,5): ela avança direto e **o ataque é garantido, sem dado**. Lição: perto dela, silêncio |
| **B. Mergulho** | Depois de **atacar**, ou de **investigar o ponto do sonar sem achar a cápsula**, ela some por 4 turnos e reaparece longe (≥ 10 casas da cápsula), vagando até ser atraída de novo. A interferência cai e o alarme apaga, dando um momento de alívio |
| **Trombada** | Se a cápsula entra na casa onde ela está, é golpe garantido (sem dado) |

**Exemplos de jogo:**
1. *Fuga limpa:* o sonar mostra um ponto a 4 casas a leste e o chamado distante responde. O jogador recua de ré (sem girar, sem dar turno de graça). Ela chega ao cruzamento, não acha ninguém e mergulha. O alarme apaga.
2. *Ela encosta:* sirene e interferência no máximo. Se o dado mandar hesitar, o jogador foge pelo lado livre e a distância aumenta. Se mandar atacar, vem o golpe, o casco cai de 3 para 2, ela mergulha e reaparece longe.
3. *Pânico:* com ela a 3 casas, o jogador usa o sonar para vê-la. Ela vem direto e ataca sem dado; o casco cai de 2 para 1.

**Decisões tomadas (2026-11-12):**
- Chance de hesitar: ~~60%~~ **70%** desde a rodada 2 (§4.6.1), e a primeira encostada sempre hesita.
- ~~Casco mostrado como linha no monitor superior.~~ **Substituído em 2026-11-16:** no playtest, O₂ e casco ficavam pequenos demais no monitor superior. Os dois foram para o **monitor lateral esquerdo** (antes apagado), com número grande e 3 blocos desenhados (cheio = intacto, contorno riscado = perdido; vermelho com 1 ponto). Ver §7.1.

**Ainda em aberto:**
- ~~Opção E~~ → incorporada na rodada 2, abaixo.
- Falas do rádio para golpe não letal, casco crítico, sonar perto dela, O₂ e interferência: **gravadas e implementadas em 2026-11-16** (falas 14–19 em [`roteiro-radio.md`](roteiro-radio.md)), aguardando gravação.

**Apresentação do golpe não letal (implementada):** tranco de câmera e impacto (`cabin_impact` 0,7), rugido da criatura um pouco mais baixo que o do golpe final, luzes e telas falhando por ~1 s, linha "!! GOLPE NO CASCO — INTEGRIDADE 2/3" no registro do monitor. Detalhes técnicos no TDD §9.

### 4.6.1 Rodada 2 de balanceamento (R1–R5 implementados em 2026-11-16, valores para playtest)

**Playtest (2026-11-16):** o usuário não terminou em 5 tentativas com o rebalanceamento de 2026-11-12. Falta saber **do que** morreu (O₂ ou criatura). A telemetria por partida (CSV) é a forma de responder isso sem depender de memória.

**Método:** com 0% de vitória, ajustar uma constante por vez demora demais. Aplicar um **pacote grande** até o jogo ficar fácil e depois **voltar pela metade** (busca binária) até a taxa-alvo: ~40–60% de vitória da 3ª–4ª partida em diante.

**Pacote aprovado e implementado (R1–R5, aplicados juntos):**

| # | Mudança | Por quê |
|---|---|---|
| R1 | **Período de calma:** a criatura fica dormente nos primeiros ~15 turnos e nasce a ≥ 14 casas | O jogador aprende painel, sonar e O₂ sem pressão. Hoje ela pode chegar antes de o jogador entender os instrumentos |
| R2 | **Girar não dá turno à criatura** (metade da opção E) | Cada curva hoje é um turno de graça para ela. Girar é "mirar", não deslocar, e o custo de O₂ continua |
| R3 | **Ver ≠ chamar:** o sonar continua *revelando* até 4,5 casas, mas a carga garantida só acontece a ≤ 3 casas. Entre 3 e 4,5 ela só caça o ponto do pulso (comportamento normal) | Devolve ao sonar o papel de planejar a fuga. Hoje, vê-la quase sempre significa tomar o golpe |
| R4 | **Primeira encostada sempre hesita** e `ATTACK_CHANCE` 0,4 → 0,3 | A primeira vez ensina a regra ("ela hesita, fuja") sem custar casco |
| R5 | **O₂ 200 → 240** | Margem para o desvio que fugir dela exige |

**Detalhes da implementação:**
- **R1:** "dormir" = não anda, não ronda e não reage ao sonar. Durante a calma, um pulso perto ainda a **revela** no CRT, mas não a chama e não toca o chamado distante. Trombar nela continua sendo golpe. Os turnos de calma contam só as ações que dão turno (girar não conta).
- **R3:** carga com o pulso a ≤ 3 células em linha reta (mesma métrica do raio de 4,5).
- **R4:** a primeira encostada vale para a partida inteira. Depois dela, a cada turno encostada, 30% de ataque.
- **Diálogos:** nenhuma fala precisou mudar. A fala 19 (opcional) passa a tocar sempre no primeiro encontro de perto, porque a primeira encostada agora sempre hesita.
- **Próximo passo:** playtest. Se ficar fácil demais, desfazer pela metade, nesta ordem: R5 (O₂ 220), R3 (carga a 3,5), R4 (ataque 35%), R1 (calma de 10 turnos). R2 fica, porque corrige uma injustiça e não é só um número.

**Outras alavancas (cardápio, se o pacote não bastar ou para afinar):**
- **Vagar sem rumo de verdade:** ao vagar, ela evita se aproximar da cápsula. Só o sonar (ou o azar) a traz. Isso deixa toda perseguição com uma **causa** que o jogador entende.
- `STALK_LOSE_RANGE` 4 → 3: ela perde o rastro mais cedo.
- Labirinto 15×15 → 13×13, ou `loop_chance` 0,08 → 0,15: rota mais curta e mais saídas de fuga.
- Casco 3 → 4, ou reparo de casco como powerup (§4.7).
- **Informação em vez de números:** raspar de casco quando ela está encostada, para o jogador saber que é hora de fugir (GDD §6.4).
- Modo "treino" na primeira partida (sem criatura, só rádio e instrumentos), se o tutorial pelo rádio não bastar.

### 4.7 Powerups no labirinto (em avaliação, 2026-11-16)

**Ideia do usuário:** itens espalhados pelo labirinto, vistos no sonar só **no feixe** (as 4 linhas retas do pulso, até a primeira parede), como era a criatura antes do raio. Candidatos: sonar grátis, sonar melhorado, escudo, oxigênio, dica de caminho livre e ping de saída.

**Avaliação (MDA):**
- **Mecânica → dinâmica:** dá ao sonar um segundo motivo além de navegar (procurar recursos). Como o item só aparece no feixe, procurar exige girar e pulsar, ou seja, gastar O₂ e chamar a criatura. O risco central fica mais rico, sem regra nova de risco.
- **Becos sem saída** viram escolha (hoje são só prejuízo). Itens no fundo de becos criam a dinâmica "desvio arriscado por recompensa".
- **Estética:** cuidado com a fantasia de poder. Os itens devem ser **alívio escasso**, não arsenal. Poucos por mapa (3–4) e de efeito pequeno.
- **Lore (forte):** os itens são **destroços das Cápsulas Zero a Nove**: cilindros de O₂, placas de casco, boias de sinalização. Cada coleta lembra que outros morreram ali. O comandante pode ter um deslize ao ver o registro ("Isso é da Cápsula Seis... não devia estar aí").

**Avaliação de cada candidato:**

| Candidato | Veredito | Observação |
|---|---|---|
| Ganho de O₂ | ✅ **MVP** | Alívio direto. Cilindro de destroço: +30 O₂ |
| Escudo (colisão/ataque) | ✅ **MVP, como reparo** | Em vez de um escudo separado, **+1 casco** (até o máximo). Usa o sistema que já existe, sem estado novo |
| Sonar melhorado | 🟡 Depois | Ex.: os próximos 3 pulsos com raio maior ou revelando o corredor inteiro. Bom, mas exige mexer no sonar |
| Sonar grátis | 🟡 Fraco | 4 de O₂ é pouco para empolgar. Pode ser o efeito do "sonar melhorado" ou ser cortado |
| Dica de caminho livre | 🟡 Cuidado | Mostrar o caminho até a saída mata a exploração. Se entrar: só as **3 próximas casas** do caminho, uma vez |
| Ping de saída | ❌ Cortar | A saída **já** aparece em verde no CRT. Redundante, a menos que a saída deixe de ser visível |

**Sugestões novas:**
- ⭐ **Boia-isca (MVP):** solta um pulso falso numa casa à frente. A criatura caça a isca em vez da cápsula. Aproveita o comportamento que já existe (ela caça o ponto do pulso) e transforma a fuga em decisão ativa. É o item com mais sinergia com o núcleo do jogo.
- **Carga de choque:** se ela estiver encostada, a obriga a mergulhar na hora. É uma saída de emergência e precisa ser muito rara (1 por mapa, no máximo).
- **Caixa-preta:** revela no CRT um trecho do mapa registrado por uma cápsula anterior e toca um áudio curto dela. Item de lore + navegação.

**Regras propostas:** coleta automática ao entrar na casa. Depois de detectado, o item fica marcado no mapa (âmbar), para não punir a memória do jogador. O₂ e reparo têm efeito imediato. A isca precisa de acionamento: um dos 3 knobs livres sob o monitor vira "ISCA". O registro anota a coleta e o monitor lateral mostra a carga disponível.

**Escopo:** MVP com 3 itens (O₂, reparo, isca), estimado em 1–2 dias. Arquitetura em resumo: `PickupSpawner` como consumidor do `LevelSetup` (posiciona em becos, longe do início), `Pickup` como `Resource` com o tipo de efeito, sinais `pickup_detected`/`pickup_collected` e efeitos aplicados no `GameState`. A isca reusa `Enemy._on_sonar_pinged`. **Implementar só depois** de acertar o balanceamento base (§4.6.1), senão os itens mascaram o problema.

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
- **Implementado — rádio no jogo:** as 13 falas (19 desde 2026-11-16, com as falas de instrumentos e de casco) tocam nos gatilhos do roteiro, no máximo uma vez por partida, uma por vez. O comandante se **interrompe** no meio de uma fala comum quando a criatura aparece pela primeira vez ("Espera... o que foi isso?"). Dicas que esperariam demais na fila são descartadas e voltam a valer se o evento se repetir, para nenhuma dica chegar fora de hora. A voz passa por filtro de rádio, com estática e chiado de abrir e fechar a transmissão.
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

Tudo vive no painel físico em frente à cadeira, operado com a mira quando o jogador está sentado (§2.1):

| Instrumento do painel | O que mostra / faz |
|---|---|
| Relógio superior esquerdo | **O₂**: ponteiro parte da esquerda (cheio) e avança para a direita a cada ação; faixa vermelha à direita nos 25% finais. **Padrão dos dois relógios: perigo sempre à direita**. Os dois relógios são os **originais do painel** (mostrador envelhecido e ponteiro 3D da malha, que gira). Só a faixa vermelha e a legenda são impressas por cima, como tinta no mostrador |
| Relógio inferior esquerdo | **Interferência**: sobe e treme conforme o inimigo se aproxima (sensor diegético de proximidade) |
| Área central — tela | **Rumo** atual, **estado da manobra** (PRONTO / AVANÇANDO… / GIRANDO… / AGUARDANDO ECO…) e alerta piscando (CONTATO PRÓXIMO / O₂ BAIXO) |
| Área central — teclas | **Teclas físicas 3D** em cruz Frente/Ré/Girar/Sonar (§4.1). Brilham no hover e afundam com clique sonoro ao pressionar. Só acionam se soltas em cima da tecla, então dá para desistir arrastando para fora. Durante a manobra, a tecla acionada fica afundada e acesa e as outras escurecem |
| Knob vermelho (sob o monitor) | **Silenciar alarme** (§6.3): é o knob original "BCN" do painel, pintado de vermelho, com uma **etiqueta de rotuladora** "SILENCIAR ALARME" colada por cima da gravação antiga (gambiarra de bordo, coerente com a cápsula). Afunda ao clicar e acende em âmbar enquanto o som está silenciado |
| Tela CRT (direita) | **Mapa do sonar**: paredes descobertas por sonar/colisão, rastro, posição e rumo, saída em verde, eco vermelho do inimigo |
| Monitor superior (vermelho) | Só o **registro** de eventos (deslocamento, impacto, pulso, golpes, alertas), em fonte grande |
| Monitor lateral esquerdo ("Suporte de vida", âmbar) | **O₂** em número grande + barra, **casco** em 3 blocos (cheio = intacto) e **custo de O₂** por ação. Vermelho com O₂ ≤ 25% ou casco 1. Ao alcance do olhar sentado (canto esquerdo, ~45° de lado). Visto de lado, o texto fica mais estreito (perspectiva), mas continua nítido: a tela usa mipmaps (ver TDD §7.1) |

- Layout do teclado em cruz: a disposição espacial espelha a ação (frente em cima, ré embaixo, giros nas laterais), reduzindo erro de clique sob tensão. Acionado apenas por mouse.
- No fim da partida, o teclado é desabilitado e aparece a tela de fim (vitória/derrota) com "Tentar novamente" e "Menu principal" (ainda 2D).

*(A detalhar: usar os outros 3 knobs (ex.: volume do rádio, brilho do sonar). Legendas do rádio: implementadas na base da tela, ver §6.1.)*

### 7.1.1 Cenas de fim de partida (implementado em 2026-11-16)

Cada fim tem uma pequena cena na própria cabine, no mesmo vocabulário do golpe no casco (tranco de câmera, luzes e telas falhando), sincronizada com a fala final do comandante. A tela de fim só aparece depois dela.

- **Contato (criatura):** já existia (§4.5): dois golpes, luzes e telas enlouquecendo, apagão, e o rádio fala no escuro.
- **Vitória:** o cabo de resgate engata com um tranco leve e as luzes oscilam com a energia nova. No "cabo travado" vem um segundo tranco e a cabine inclina, puxada para cima. Começa a subida: vibração contínua, ronco grave do motor, luzes esquentando e o monitor registrando "SUBINDO — PROFUNDIDADE 3.990 m…", cada vez mais rápido. Termina num clarão quente.
- **Oxigênio:** o suporte de vida desliga. Luzes e telas entram em queda de energia, a visão escurece pelas bordas e perde a cor, pulsando como um batimento cada vez mais lento, e a cabeça vai pendendo. As telas morrem uma a uma e o som some junto. O "sinal perdido. Preparem a Onze" é dito no escuro total.
- *Motivo:* pedido do usuário. Antes, vitória e oxigênio mostravam só o painel parado durante a fala final; agora o desfecho é sentido, não só ouvido.

### 7.2 Menus (implementado em 2026-11-16)

Os menus ficam **fora** da ficção (2D sobre a tela), com o mesmo visual dos monitores da cabine: fundo escuro, âmbar e ferrugem. Toda troca de tela passa por um fade para preto.

- **Menu principal** (cena inicial): título, a frase "Quatro mil metros. Sem janelas. Só o painel e o som." e os botões **Novo jogo**, **Opções**, **Controles**, **Créditos** e **Sair**. Ao fundo, uma tela de sonar com um pulso a cada ~5 s, o som do sonar baixinho e três ecos vermelhos que acendem quando o pulso passa. A cama de ambiente do jogo já toca no menu. O rodapé recomenda fones de ouvido, porque o jogo é guiado por som.
- **Pausa (Esc):** congela a partida (rádio e efeitos param; o ambiente continua) e libera o cursor. Botões: **Continuar**, **Opções**, **Controles**, **Reiniciar partida**, **Menu principal** e **Sair do jogo**. Esc dentro de um submenu volta à lista; na lista, continua o jogo. Sair da partida pela pausa conta como **abandono** na telemetria.
- **Opções** (iguais no menu e na pausa, salvas entre sessões): volume geral, voz do rádio, efeitos, ambiente, sensibilidade do mouse (0,25× a 2,5×), legendas do rádio (liga/desliga) e tela cheia, além de "Restaurar padrão".
- **Controles:** resumo de andar pela cabine e operar o posto, terminando com "o resto, a Superfície explica pelo rádio". O tutorial continua sendo o rádio (§6.1).
- **Créditos:** Gustavo Brendler e Rafael Nunes Siqueira; Godot; voz do comandante gerada por IA no sintetizador próprio da equipe (feito com o Google AI Studio); ambiente e efeitos do Pixabay; sons CC0 do Freesound (motor e rangido); clique, bipe e estática sintetizados pela equipe. Registro completo em `assets/audio/CREDITS.md`.
- *Decisão:* o Esc, que antes só liberava o cursor, agora abre a pausa. Com uma anotação aberta, o Esc continua fechando a anotação.

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
- **2026-11-12 — Sonar com raio e sequência de contato:** o sonar passa a revelar a criatura em qualquer posição dentro de 4,5 células (antes, só no feixe reto), com anel de alcance no CRT. A derrota por contato ganhou uma sequência de ataque e apagão antes do rádio e da tela de fim (§4.5). Motivo: o fim era abrupto e não comunicava que a criatura tinha pegado a cápsula. **Em discussão:** rebalancear a criatura (hoje a vitória é praticamente impossível): casco com integridade (2 ataques aguentados), dado quando ela fica adjacente (ataca ou hesita), ataque garantido se o jogador usar o sonar com ela perto, e ela some e reaparece longe depois de investigar ou atacar.
- **2026-11-12 — Rebalanceamento da criatura implementado:** o casco aguenta 2 golpes (o 3º é a derrota por contato); perto da cápsula, a criatura ronda devagar e, encostada, joga o dado a cada turno (60% hesita, 40% ataca); usar o sonar com ela dentro do raio a faz vir direto e atacar sem dado; depois de atacar, ou de investigar um pulso à toa, ela mergulha por 4 turnos e reaparece a 10 casas ou mais. O casco aparece numa linha do monitor superior (teste antes de ocupar um knob). Motivo: a vitória era praticamente impossível (§4.6).
- **2026-11-12 — Mira também sentado no posto:** substitui o cursor livre com *edge-pan*. Sentado, o mouse move o olhar dentro de limites (ampliados para ±40°/+50°/−20°, para o knob do alarme ficar ao alcance), e o clique aciona o controle sob a mira central. A tecla sob a mira acende e a mira muda de cor; o texto de ação fica oculto sentado, porque cobriria as teclas vizinhas. Motivo: pedido do usuário, controle único e mais imersivo.
- **2026-11-16 — Monitor lateral "Suporte de vida", falas novas, powerups e rodada 2 de balanceamento:** O₂ numérico, casco e custos saíram do monitor superior (ilegíveis do assento) e foram para o monitor apagado à esquerda do painel, com números grandes, barra e blocos desenhados. O monitor superior ficou só com o registro, em fonte maior. Escritas as falas 14–19 do rádio (monitor de O₂, interferência, primeiro golpe, casco crítico, sonar perto dela e, opcional, ela encostada), que ensinam os instrumentos e as consequências sem narrar a IA da criatura. Avaliados os powerups (§4.7: MVP com O₂, reparo de casco e boia-isca; ping de saída cortado por ser redundante) e proposta a rodada 2 de balanceamento (§4.6.1), depois de 5 derrotas seguidas no playtest. Powerups e rodada 2 ainda não implementados.
- **2026-11-16 — Rodada 2 de balanceamento implementada (R1–R5):** período de calma (a criatura dorme nos primeiros 15 turnos e nasce a ≥ 14 passos), girar não dá turno a ela, o sonar só a faz vir em carga a ≤ 3 células (continua revelando até 4,5), a primeira encostada sempre hesita e o ataque encostada caiu para 30%, O₂ inicial 240. Motivo: 0 vitórias em 5 tentativas no playtest. Os diálogos 14–19 não mudaram. Ver §4.6.1.
- **2026-11-16 — Mostradores com o perigo do mesmo lado:** o vermelho do O₂ ficava no início da escala e o da interferência no fim. Agora os dois têm a faixa vermelha à direita, e a escala do O₂ foi invertida: o ponteiro começa à esquerda com o tanque cheio e avança para o vermelho conforme o ar acaba. Motivo: pedido do usuário. Uma regra única de leitura ("ponteiro à direita = perigo") vale para os dois relógios num relance.
- **2026-11-16 — Falas 14–19 no jogo e legendas mais limpas:** as 6 falas novas (monitor de O₂, interferência, primeiro golpe, casco crítico, sonar perto dela e ela encostada) foram gravadas e ligadas aos gatilhos do roteiro. Nas legendas, reticências duplicadas viraram uma só. Motivo: pedido do usuário, porque "... ..." poluía a leitura.
- **2026-11-16 — Telemetria de playtest:** cada partida jogada pelo editor grava um resumo (`telemetry/runs.csv`) e o passo a passo (`run_<data>.csv`: cada ação, a reação da criatura, O₂, casco e distâncias). `python3 tools/telemetry_report.py` mostra a taxa de vitória, as causas de derrota, as médias de vitória x derrota e qual alavanca mexer. Motivo: o usuário venceu com a rodada 2, e a partir daqui o balanceamento precisa de números, não de impressão. Alvo: 40–60% de vitória da 3ª–4ª partida em diante (§4.6.1).
- **2026-11-16 — Menu principal, pausa e opções:** o jogo agora abre num menu principal com fundo de sonar e tem pausa no Esc e opções salvas (volumes por categoria, sensibilidade, legendas, tela cheia). A tela de fim ganhou "Menu principal". Motivo: pedido do usuário, como passo para o build exportável e os playtests com outras pessoas. Ver §7.2.
- **2026-11-16 — Créditos definidos:** equipe Gustavo Brendler e Rafael Nunes Siqueira. Só as falas do comandante vêm do sintetizador de IA da equipe (feito com o Google AI Studio). Ambiente, criatura, impactos, sirene e sonar são do Pixabay (Pixabay Content License); motor e rangido, do Freesound (CC0); clique, bipe e estática, síntese procedural. Os do Pixabay ficaram registrados pela busca de origem, sem autor (`assets/audio/CREDITS.md`).
- **2026-11-16 — Cenas de fim de partida:** vitória (cabo engata, cabine puxada, subida com luzes esquentando e profundidade no monitor, clarão) e falta de oxigênio (queda de energia, visão escurecendo com batimento, cabeça pendendo, telas morrendo, som sumindo), no mesmo estilo do golpe no casco e sincronizadas com a fala final. Ver §7.1.1.
- **2026-11-17 — Relógios e knob originais do painel:** com a malha nova do painel (SM_Devices01 em 4K), os mostradores desenhados por cima saíam da borda dos relógios e cobriam o visual envelhecido. Agora os relógios são os **originais**: o ponteiro 3D da malha gira, e só a faixa vermelha (25% finais) e a legenda (O₂ / INTERF.) ficam impressas no mostrador. O botão de silenciar o alarme passou a ser o **knob "BCN" original pintado de vermelho**, com uma etiqueta de rotuladora "SILENCIAR ALARME" sobre a gravação antiga (a legenda anterior ficava sobreposta ao "BCN"). O monitor lateral esquerdo ficou nítido quando visto de lado. Motivo: pedido do usuário, manter o realismo dos instrumentos originais com a funcionalidade do jogo. Ver §7.1.
