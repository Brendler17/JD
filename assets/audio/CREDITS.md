# Créditos de áudio

Os efeitos do Freesound são **CC0** (domínio público) e os do Pixabay seguem a **Pixabay Content License** (uso livre, inclusive comercial, sem atribuição obrigatória): o crédito fica registrado aqui mesmo assim. Para os arquivos do Pixabay, a origem está registrada pela busca usada (os arquivos foram renomeados e, fora a sirene, não guardam título). As falas do comandante são da equipe (Gustavo Brendler e Rafael Nunes Siqueira).

| Arquivo (`sfx/`) | Origem | Autor | Licença | Observações |
|---|---|---|---|---|
| `capsule_move.mp3` | [Submarine travel](https://freesound.org/people/Andreas.Mustola/sounds/255770/) | Andreas.Mustola (Freesound) | CC0 | Preview HQ do Freesound, sem edição |
| `capsule_rotate_a.wav`, `capsule_rotate_b.wav` | [metal locker creaks slow groan](https://freesound.org/people/kyles/sounds/454081/) | kyles (Freesound) | CC0 | Recortes de 1,4 s (0,2 s e 24,0 s), normalizados, com fade-out |
| `panel_click.wav`, `o2_beep.wav` | Gerados proceduralmente (síntese em Python) | Equipe | — | Clique mecânico das teclas e bipe duplo de O₂ baixo |
| `radio_static.wav`, `radio_squelch_open.wav`, `radio_squelch_close.wav` | Gerados proceduralmente (síntese em Python) | Equipe | — | Estática do rádio em laço (4 s) e chiado de abrir/fechar transmissão |
| `ambience.mp3`, `ambience2.mp3`, `ambience3.mp3`, `sonar.mp3` | Pixabay, busca [submarino](https://pixabay.com/pt/sound-effects/search/submarino/) | — | Pixabay Content License | Ambiente, camada de tensão e ping do sonar |
| `monster.mp3`, `monster2.mp3`, `monster3.mp3` | Pixabay, buscas [kraken](https://pixabay.com/pt/sound-effects/search/kraken/) e [sea monster](https://pixabay.com/pt/sound-effects/search/sea%20monster/) | — | Pixabay Content License | Eco, rugido e chamado distante da criatura |
| `crash.mp3`, `metal.mp3` | Pixabay, busca [metal](https://pixabay.com/pt/sound-effects/search/metal/) | — | Pixabay Content License | Impacto no casco e metal rangendo/esmagando |
| `siren.mp3` | Pixabay ("Alarm - Danger! Danger!", título nos metadados do arquivo) | — | Pixabay Content License | Sirene do alarme de contato |

| Arquivo (`radio/`) | Origem | Licença | Observações |
|---|---|---|---|
| `radio_*.wav` (19 falas) e o teaser | Geradas por IA no sintetizador próprio da equipe (desenvolvido com o Google AI Studio), com a mesma voz do teaser | Próprio | Gravadas limpas; o efeito de rádio é aplicado em tempo real (bus `Radio`) |
