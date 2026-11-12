class_name RadioLine
extends Resource
## Uma fala do rádio do comandante (dados; quem decide quando tocar é o RadioSystem).
## O áudio é achado pelo nome: res://assets/audio/radio/radio_<id>.wav (ou .ogg/.mp3).
## Sem arquivo, a fala roda só com legenda, com duração estimada pelo texto.
## Roteiro, gatilhos e tons: docs/roteiro-radio.md.

enum Priority {
	## Entra no fim da fila.
	NORMAL,
	## Entra na frente da fila (sem cortar a fala atual).
	URGENT,
	## Fim de partida: corta a fala atual e limpa a fila.
	FINAL,
}

## Identificador do gatilho e sufixo do arquivo de áudio (ex.: &"first_sonar").
@export var id: StringName
@export_multiline var subtitle: String
@export var priority: Priority = Priority.NORMAL
## Segundos que a fala pode esperar na fila. Passado isso ela é descartada SEM
## contar como tocada: o mesmo evento, se acontecer de novo, dispara a fala outra vez.
## Evita uma dica chegar muito depois do momento a que ela se refere.
@export var max_wait := 12.0
## Pausa antes de tocar (falas finais: deixa o som do fim de partida respirar).
@export var delay := 0.0
