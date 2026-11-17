#!/usr/bin/env python3
"""Relatório de balanceamento a partir da telemetria de playtest (GDD §4.6.1).

Uso:
    python3 tools/telemetry_report.py               # lê telemetry/runs.csv
    python3 tools/telemetry_report.py outro.csv     # outro arquivo
    python3 tools/telemetry_report.py --ultimas 10  # só as N partidas mais recentes

Lê o resumo gravado pelo RunTelemetry (uma linha por partida, separador ";",
vírgula decimal) e mostra taxa de vitória, causas de derrota, médias de vitórias
x derrotas e uma leitura de balanceamento com as alavancas a mexer.
"""
import csv
import sys
from pathlib import Path
from statistics import mean

DEFAULT = Path(__file__).resolve().parent.parent / "telemetry" / "runs.csv"
TARGET_LOW, TARGET_HIGH = 0.40, 0.60

COLUMNS = [
    ("duracao_s", "duração (s)"),
    ("acoes", "ações"),
    ("sonares", "sonares"),
    ("colisoes", "colisões"),
    ("o2_final", "O₂ final"),
    ("golpes", "golpes recebidos"),
    ("cargas", "cargas (sonar perto)"),
    ("hesitacoes", "hesitações"),
    ("acoes_com_criatura_a_4", "ações com ela a ≤4"),
    ("menor_dist_criatura", "menor dist. da criatura"),
    ("dist_saida_final", "dist. da saída no fim"),
    ("caminho_otimo", "caminho ótimo"),
]


def num(value: str) -> float:
    try:
        return float(value.replace(",", "."))
    except ValueError:
        return float("nan")


def avg(rows, key):
    values = [num(r[key]) for r in rows if r.get(key) not in (None, "")]
    values = [v for v in values if v == v and v >= 0]
    return mean(values) if values else None


def fmt(value):
    return "  —  " if value is None else f"{value:6.1f}"


def main() -> None:
    args = sys.argv[1:]
    last = None
    if "--ultimas" in args:
        i = args.index("--ultimas")
        last = int(args[i + 1])
        del args[i:i + 2]
    path = Path(args[0]) if args else DEFAULT
    if not path.exists():
        sys.exit(f"Arquivo não encontrado: {path}\nJogue uma partida pelo editor para gerar a telemetria.")

    with path.open(encoding="utf-8") as f:
        rows = list(csv.DictReader(f, delimiter=";"))
    if last:
        rows = rows[-last:]
    finished = [r for r in rows if r["resultado"] != "ABANDONO"]
    if not finished:
        sys.exit("Nenhuma partida terminada ainda.")

    wins = [r for r in finished if r["resultado"] == "VITORIA"]
    by_creature = [r for r in finished if r["resultado"] == "CRIATURA"]
    by_oxygen = [r for r in finished if r["resultado"] == "OXIGENIO"]
    n = len(finished)
    rate = len(wins) / n

    print(f"\n=== Telemetria: {path} ===")
    print(f"Partidas terminadas: {n}  (abandonadas: {len(rows) - n})")
    print(f"Vitórias: {len(wins)} ({rate:.0%})  |  morte pela criatura: {len(by_creature)}  |  por O₂: {len(by_oxygen)}")
    print("Sequência:", " ".join({"VITORIA": "V", "CRIATURA": "C", "OXIGENIO": "O"}[r["resultado"]] for r in finished))

    print(f"\n{'média':28} {'todas':>7} {'vitória':>8} {'derrota':>8}")
    losses = by_creature + by_oxygen
    for key, label in COLUMNS:
        print(f"{label:28} {fmt(avg(finished, key))} {fmt(avg(wins, key)):>8} {fmt(avg(losses, key)):>8}")

    print("\n--- Leitura ---")
    if n < 5:
        print(f"• Só {n} partida(s): pouco para concluir. Jogue pelo menos 5 antes de mexer em valores.")
    if rate < TARGET_LOW:
        if len(by_creature) >= len(by_oxygen):
            print("• Difícil, e a criatura é a causa principal.")
            if (avg(losses, "cargas") or 0) >= 1:
                print("  - Muitas cargas: o jogador usa o sonar com ela perto. Reduzir CHARGE_RADIUS ou reforçar o aviso (interferência/rádio).")
            if (avg(losses, "acoes_com_criatura_a_4") or 0) > 15:
                print("  - Muito tempo com ela perto: STALK_LOSE_RANGE 4 → 3 ou STALK_INTERVAL 2 → 3.")
            print("  - Alavancas gerais: ATTACK_CHANCE ↓, MAX_HULL 3 → 4, CALM_TURNS ↑.")
        else:
            print("• Difícil, e o oxigênio é a causa principal.")
            print("  - MAX_OXYGEN ↑ (+20), OXYGEN_COST_SONAR 4 → 3 ou labirinto menor.")
            if (avg(by_oxygen, "colisoes") or 0) > 5:
                print("  - Muitas colisões: o mapa do sonar está mostrando pouco? Ver legibilidade do CRT.")
    elif rate > TARGET_HIGH + 0.2:
        print("• Fácil demais. Desfazer a rodada 2 pela metade, nesta ordem: O₂ 220, carga a 3,5, ataque 35%, calma de 10.")
        if (avg(wins, "golpes") or 0) < 0.5:
            print("  - Vitórias sem nenhum golpe: a criatura quase não pressiona.")
    else:
        print(f"• Dentro da faixa-alvo ({TARGET_LOW:.0%}–{TARGET_HIGH:.0%}, com folga até {TARGET_HIGH + 0.2:.0%}). Ajustar só por sensação/tensão.")
    if wins and (avg(wins, "o2_final") or 0) > 80:
        print("• Vitórias sobrando muito O₂ (> 80): o oxigênio não está criando tensão. Considerar MAX_OXYGEN ↓.")
    print("• Para rever uma partida: abra o run_<data>.csv dela, e use a coluna 'seed' em LevelSetup.fixed_seed para repetir o labirinto.\n")


if __name__ == "__main__":
    main()
