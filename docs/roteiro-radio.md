# Roteiro do Rádio — Profundidade Zero

> Falas do comandante ("Superfície") para a Cápsula Dez. Implementa GDD §6.1–6.2 (introdução curta + falas disparadas **na primeira vez** que algo acontece; cada fala toca no máximo uma vez por partida) e a lore do GDD §2.3: o comandante **esconde** que a Estação Tétis parou de responder, que dez cápsulas desceram antes e que existe uma criatura. Ele se revela só em deslizes. As legendas usam o mesmo texto.
>
> O teaser (`Teaser - Diálogo.wav`) é a última transmissão da **Cápsula Zero**. Várias falas reaproveitam frases dele, de propósito: o comandante repete o mesmo protocolo para cada cápsula.

## Diretrizes para gerar os áudios

- **Uma fala por arquivo**, com o nome indicado (`radio_<id>.mp3` ou `.wav`), em `assets/audio/radio/`. Mesma voz do teaser.
- **Gerar a voz limpa**, sem efeito de rádio: o jogo aplica o filtro de transmissão, a estática e as interferências em tempo real (bus `Radio`, TDD §10).
- Colar **apenas o texto da fala**. O tom serve para escolher a configuração da voz.
- Reticências (`...`) marcam pausas e hesitações. Os **deslizes** (frases cortadas e corrigidas) devem soar como se escapassem, com uma pausa curta antes da correção.

## Falas

| # | Arquivo | Quando toca | Tom | Fala |
|---|---|---|---|---|
| 1 | `radio_intro` | ~3 s após o início da partida | Calmo, profissional, protocolo decorado (repete o teaser) | Cápsula Dez, aqui é a Superfície. Está me ouvindo? Vocês estão a quatro mil metros. O cabo de reboque rompeu... não conseguimos puxar vocês daí. Sem janelas, sem câmeras. Daqui pra frente, você só tem o painel e o som. Marcamos um ponto de resgate no seu sonar. Traga essa cápsula até ele. |
| 2 | `radio_idle_seat` | 30 s sem sentar no posto (uma vez) | Firme, um pouco impaciente | Cápsula Dez, vá para o posto de comando. O ponto de resgate não vai até você. |
| 3 | `radio_first_seat` | Primeira vez que senta no posto | Didático, tranquilo | Ótimo. Esse painel é tudo o que você tem. Frente e ré movem a cápsula uma seção. As setas giram noventa graus. Cada comando gasta oxigênio dos reguladores... e bater no casco gasta muito mais. Vá com calma. |
| 4 | `radio_first_collision` | Primeira colisão | Preocupado (eco do teaser: "cuidado com as paredes") | Cuidado com as paredes, Cápsula Dez! Cada batida compromete o casco e queima o seu ar. Se não sabe o que tem à frente, use o sonar. |
| 5 | `radio_first_sonar` | Primeiro pulso de sonar | Orientando; **deslize**: começa a frase do teaser e muda de ideia | O sonar mostra o caminho. Mas lá embaixo... ... o pulso viaja longe. Use só quando precisar. |
| 6 | `radio_first_alarm` | Primeira vez que qualquer alarme dispara (depois da fala 7, se coincidirem) | Rápido, prático | Se a sirene atrapalhar, o botão vermelho acima do painel silencia o alarme. A luz continua acesa. |
| 7 | `radio_first_enemy` | Primeiro eco da criatura no sonar **ou** primeiro alarme de contato | Assustado; **deslize** ("de novo não") e a fala se desfaz em estática (eco do teaser) | Espera... o que foi isso no seu sonar? ... Não. De novo não... Cápsula, repita. Cápsula Dez, repita... sinal... perdendo... |
| 8 | `radio_low_oxygen` | Primeira vez com O₂ ≤ 25% | Tenso, mas controlado | Cápsula Dez, seus reguladores estão no limite. Não desperdice nenhum movimento. Pense antes de cada comando. |
| 9 | `radio_station` | Após a 20ª manobra (uma vez) | Baixo, cauteloso, como quem não devia dizer isso | Cápsula Dez... se o seu rádio captar qualquer chamado da Estação Tétis... não responda. Só nos informe. |
| 10 | `radio_near_exit` | Primeira vez a ≤ 3 passos da saída | Esperançoso; **deslize** ("ninguém chegou tão...") | Cápsula Dez, estamos captando vocês! Ninguém chegou tão... ... Vocês estão perto. Continue. Só mais um pouco. |
| 11 | `radio_win` | Vitória (chegou à saída) | Alívio que vira confissão | Contato confirmado! Cabo travado... estamos trazendo vocês para cima. Cápsula Dez... você foi a primeira a voltar. |
| 12 | `radio_lost_oxygen` | Derrota por oxigênio | Chamando sem resposta; no fim, frio, falando com alguém na sala | Cápsula Dez? ... Cápsula Dez, responda. ... Registre. Cápsula Dez, sinal perdido. Preparem a Onze. |
| 13 | `radio_lost_caught` | Derrota por contato com a criatura | Alarmado, depois em choque, quase sussurrando | Cápsula Dez, perdemos sua telemetria! Dez? ... Responda... ... Igual às outras. |

## Regras de reprodução (para a implementação)

- Cada fala toca **uma vez por partida** (reinício zera). A intro sempre toca.
- Uma fala por vez: se outra for disparada enquanto uma toca, entra numa fila curta. As de fim de partida (11–13) furam a fila.
- Durante a fala 7, a interferência do rádio sobe até "engolir" o fim da frase. Nos encontros seguintes com a criatura **não há voz**: só a interferência aumentando (GDD §6.2).
- Legenda no monitor superior do painel enquanto a fala toca.
