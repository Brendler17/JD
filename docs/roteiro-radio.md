# Roteiro do Rádio — Profundidade Zero

> Falas do comandante ("Superfície") para a Cápsula Dez. Implementa GDD §6.1–6.2 (introdução curta + falas disparadas **na primeira vez** que algo acontece; cada fala toca no máximo uma vez por partida) e a lore do GDD §2.3: o comandante **esconde** que a Estação Tétis parou de responder, que dez cápsulas desceram antes e que existe uma criatura. Ele se revela só em deslizes. As legendas usam o mesmo texto.
>
> O teaser (`Teaser - Diálogo.wav`) é a última transmissão da **Cápsula Zero**. Várias falas reaproveitam frases dele, de propósito: o comandante repete o mesmo protocolo para cada cápsula.

## Diretrizes para gerar os áudios

- **Uma fala por arquivo**, com o nome indicado (`radio_<id>.mp3` ou `.wav`), em `assets/audio/radio/`. Mesma voz do teaser.
- **Gerar a voz limpa**, sem efeito de rádio: o jogo aplica o filtro de transmissão, a estática e as interferências em tempo real (bus `Radio`, TDD §10).
- Colar **apenas o texto da fala**. A coluna **Voz no app** indica qual dos 4 tons do gerador usar (Comando Firme, Urgência / Alerta, Soturno / Abissal, Tenso / Desconfiado); a coluna **Tom** descreve a intenção da cena.
- Reticências (`...`) marcam pausas e hesitações. Os **deslizes** (frases cortadas e corrigidas) devem soar como se escapassem, com uma pausa curta antes da correção.

## Falas

| # | Arquivo | Quando toca | Tom | Voz no app | Fala |
|---|---|---|---|---|---|
| 1 | `radio_intro` | ~3 s após o início da partida | Calmo, profissional, protocolo decorado (repete o teaser) | Comando Firme | Cápsula Dez, aqui é a Superfície. Está me ouvindo? Vocês estão a quatro mil metros. O cabo de reboque rompeu... não conseguimos puxar vocês daí. Sem janelas, sem câmeras. Daqui pra frente, você só tem o painel e o som. Marcamos um ponto de resgate no seu sonar. Traga essa cápsula até ele. |
| 2 | `radio_idle_seat` | 30 s após o fim da intro sem ter sentado no posto (uma vez) | Firme, um pouco impaciente | Comando Firme | Cápsula Dez, vá para o posto de comando. O ponto de resgate não vai até você. |
| 3 | `radio_first_seat` | Primeira vez que senta no posto | Didático, tranquilo | Comando Firme | Ótimo. Esse painel é tudo o que você tem. Frente e ré movem a cápsula uma seção. As setas giram noventa graus. Cada comando gasta oxigênio dos reguladores... e bater no casco gasta muito mais. Vá com calma. |
| 4 | `radio_first_collision` | Primeira colisão | Preocupado (eco do teaser: "cuidado com as paredes") | Urgência / Alerta | Cuidado com as paredes, Cápsula Dez! Cada batida compromete o casco e queima o seu ar. Se não sabe o que tem à frente, use o sonar. |
| 5 | `radio_first_sonar` | Primeiro pulso de sonar | Orientando; **deslize**: começa a frase do teaser e muda de ideia | Tenso / Desconfiado | O sonar mostra o caminho. Mas lá embaixo... ... o pulso viaja longe. Use só quando precisar. |
| 6 | `radio_first_alarm` | Primeira vez que qualquer alarme dispara (depois da fala 7, se coincidirem) | Rápido, prático | Comando Firme | Se a sirene atrapalhar, o botão vermelho acima do painel silencia o alarme. A luz continua acesa. |
| 7 | `radio_first_enemy` | Primeiro eco da criatura no sonar **ou** primeiro alarme de contato | Assustado; **deslize** ("de novo não") e a fala se desfaz em estática (eco do teaser) | Urgência / Alerta | Espera... o que foi isso no seu sonar? ... Não. De novo não... Cápsula, repita. Cápsula Dez, repita... sinal... perdendo... |
| 8 | `radio_low_oxygen` | Primeira vez com O₂ ≤ 25% | Tenso, mas controlado | Tenso / Desconfiado | Cápsula Dez, seus reguladores estão no limite. Não desperdice nenhum movimento. Pense antes de cada comando. |
| 9 | `radio_station` | Após a 20ª manobra (uma vez) | Baixo, cauteloso, como quem não devia dizer isso | Tenso / Desconfiado | Cápsula Dez... se o seu rádio captar qualquer chamado da Estação Tétis... não responda. Só nos informe. |
| 10 | `radio_near_exit` | Primeira vez a ≤ 3 passos da saída | Esperançoso; **deslize** ("ninguém chegou tão...") | Urgência / Alerta | Cápsula Dez, estamos captando vocês! Ninguém chegou tão... ... Vocês estão perto. Continue. Só mais um pouco. |
| 11 | `radio_win` | Vitória (chegou à saída) | Alívio que vira confissão | Comando Firme | Contato confirmado! Cabo travado... estamos trazendo vocês para cima. Cápsula Dez... você foi a primeira a voltar. |
| 12 | `radio_lost_oxygen` | Derrota por oxigênio | Chamando sem resposta; no fim, frio, falando com alguém na sala | Soturno / Abissal | Cápsula Dez? ... Cápsula Dez, responda. ... Registre. Cápsula Dez, sinal perdido. Preparem a Onze. |
| 13 | `radio_lost_caught` | Derrota por contato com a criatura | Alarmado, depois em choque, quase sussurrando | Soturno / Abissal | Cápsula Dez, perdemos sua telemetria! Dez? ... Responda... ... Igual às outras. |

## Falas novas — instrumentos e rebalanceamento (2026-11-16, gravadas e implementadas)

> Ensinam as regras novas (casco, sonar perto da criatura, recuo dela) e os instrumentos (monitor de suporte de vida, O₂, interferência) **no momento em que importam**. Seguem as mesmas diretrizes de gravação acima. **Critério:** o rádio explica os **instrumentos** e as **consequências** que o jogador sofreu. Ele **não** narra a IA da criatura durante o encontro (GDD §6.2: explicar demais mata a tensão). A hesitação e o mergulho dela continuam comunicados por som e interferência, não por voz.
>
> **Implementado (2026-11-16):** áudios em `assets/audio/radio/` e gatilhos no `RadioSystem`. Prioridade e espera: 14 e 15 são `NORMAL` (esperam até 40 s e 15 s); 16 e 17 são `URGENT` (15 s, tocam 1,5 s depois do tranco); 18 e 19 são `URGENT` com espera curta (4 s), porque só fazem sentido no momento. A 18 só dispara depois de a fala 7 ter terminado.
>
> **Legendas:** onde o roteiro tem reticências duplicadas (`... ...`, pausa longa na gravação), a legenda usa **um** `...` só (pedido do usuário, 2026-11-16). O roteiro mantém as duplas porque elas orientam o ritmo da voz.

| # | Arquivo | Quando toca | Tom | Voz no app | Fala |
|---|---|---|---|---|---|
| 14 | `radio_o2_monitor` | Após a 3ª manobra concluída (uma vez), depois da fala 3 | Didático, calmo, protocolo | Comando Firme | Cápsula Dez, à sua esquerda fica o monitor de suporte de vida. Ali está o seu oxigênio exato... e quanto cada comando custa. Andar e girar gastam pouco. O sonar gasta quatro vezes mais. Uma batida, oito. O relógio de cima, no painel, mostra o mesmo ar... Quando o ponteiro entrar no vermelho, você está no fim. |
| 15 | `radio_interference` | Primeira vez que o mostrador INTERF. sai do zero (criatura a ≤ 8 passos) | Tenso; **deslize**: inventa uma explicação e não acredita nela | Tenso / Desconfiado | Cápsula Dez, o relógio de baixo é o de interferência... e ele está subindo. Isso é... só uma corrente forte passando pelo casco. Provavelmente. ... Se o ponteiro continuar subindo, não use o sonar. Afaste-se devagar, até ele voltar a cair. |
| 16 | `radio_first_hit` | Primeiro golpe **não letal** (casco 3 → 2), ~1,5 s depois do tranco | Alarmado, tenta voltar ao protocolo; **deslize** ("elas sempre recuam") | Urgência / Alerta | Cápsula Dez! Registramos um impacto no casco... e não foi parede. Olhe o monitor da esquerda. O casco aguenta mais dois desses... no máximo. ... Ela recuou. Elas sempre recuam depois do primeiro... ... Saia daí. Agora. |
| 17 | `radio_hull_critical` | Casco chega a 1 (segundo golpe), ~1,5 s depois do tranco | Grave, baixo, quase sussurrado | Soturno / Abissal | Dez... o seu casco não aguenta outro golpe. Nada de sonar. Nada de pressa. ... Só ande. E torça para ela não ouvir você. |
| 18 | `radio_sonar_charge` | Primeira vez que a criatura vem em carga por causa do sonar (pulso com ela no raio). Só depois da fala 7 ter tocado | Desesperado, rápido | Urgência / Alerta | Não, não, não! Com ela tão perto, o pulso mostra pra ela onde você está! ... Perto dela... silêncio. Lembre disso. |
| 19 *(opcional)* | `radio_stalk` | Primeira vez que ela encosta e **hesita** (desde a rodada 2, a primeira encostada sempre hesita, então a fala sempre cabe) | Sussurro; a interferência vai engolir boa parte da fala (a legenda carrega a informação) | Soturno / Abissal | Ela está do seu lado... Não pare. Quando ela ronda, ela é lenta... você é mais rápido. Saia daí. |

**Notas de gravação:**
- **16 e 17** chegam logo depois de um golpe: gravar com a respiração um pouco acelerada, como quem viu a telemetria cair.
- **15** tem o deslize no "Provavelmente": pausa curta antes, dito mais baixo, como quem não acredita no que acabou de dizer.
- **18** pode ser cortada pelo golpe que vem logo em seguida, e isso é intencional.
- **19** é opcional e quebra a regra "sem voz nos encontros" (GDD §6.2). Gravar, testar e decidir no playtest.

**Fora do rádio, de propósito:** a hesitação da criatura (fora a fala 19) e o mergulho dela. Proposta sonora: **raspar de casco** enquanto ela hesita encostada e um **chamado que se afasta** quando ela mergulha (GDD §6.4).

## Regras de reprodução (para a implementação)

- Cada fala toca **uma vez por partida** (reinício zera). A intro sempre toca, e nenhuma fala começa antes dela.
- Uma fala por vez: se outra for disparada enquanto uma toca, entra numa fila curta (até 3). A fala 7 entra na frente e **interrompe** uma fala comum em andamento (o comandante se corta). As de fim de partida (11–13) cortam tudo e tocam após uma pausa (vitória 1,2 s, O₂ 2 s; contato 4 s, depois do ataque e do apagão da cabine).
- Cada fala tem um tempo máximo de espera na fila (`max_wait`). Passado isso ela é descartada sem contar como tocada, e o mesmo evento pode dispará-la de novo. Uma fala interrompida também volta a valer.
- A tela de vitória/derrota só aparece depois da fala final.
- Durante a fala 7, a interferência do rádio sobe até "engolir" o fim da frase. Nos encontros seguintes com a criatura **não há voz**: só a interferência aumentando (GDD §6.2).
- Legenda na base da tela enquanto a fala toca (o monitor superior só registra a transmissão).
- Implementação: `scenes/systems/radio_system.tscn` (textos, prioridades e esperas de cada fala) e `scripts/systems/radio_system.gd`. Se um arquivo de áudio faltar, a fala roda só com legenda.
