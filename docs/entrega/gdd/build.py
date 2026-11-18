#!/usr/bin/env python3
"""Gera o PDF de entrega do GDD a partir de gdd.src.html.

- insere o histograma do percurso do labirinto (dados da simulação de 3.000
  labirintos, GDD cap. 6 e 10);
- monta o Apêndice A a partir de docs/roteiro-radio.md (fonte única das falas);
- imprime com o Chromium e preenche o sumário com as páginas reais (2 passadas).

Uso:  python3 docs/entrega/gdd/build.py
Saída: docs/entrega/GDD_Profundidade_Zero_v1.0.pdf
Requer: chromium (snap) e pdftotext (poppler-utils).
"""
import html
import re
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
DOCS = HERE.parent.parent
SRC = HERE / "gdd.src.html"
OUT_HTML = HERE / "gdd.html"
OUT_PDF = HERE.parent / "GDD_Profundidade_Zero_v1.0.pdf"
ROTEIRO = DOCS / "roteiro-radio.md"

# Distribuição do menor caminho até a saída (% de 3.000 labirintos 15x15, laços 8%).
BEFORE = {25: 7.7, 26: 13.2, 27: 10.5, 28: 8.9, 29: 7.7, 30: 6.1, 31: 5.3, 32: 4.2, 33: 3.5,
          34: 3.5, 35: 3.4, 36: 2.8, 37: 2.7, 38: 2.2, 39: 1.8, 40: 1.8, 41: 1.3, 42: 1.4,
          43: 1.4, 44: 1.3, 45: 1.1, 46: 1.1, 47: 1.0, 48: 1.0, 49: 0.9, 50: 0.8, "51+": 3.6}
AFTER = {28: 27.4, 29: 21.7, 30: 19.2, 31: 17.5, 32: 14.3}

ACCENT = "#c2611a"
MUTED = "#c5ccd2"
INK2 = "#4a545d"
GRID = "#e3e6e9"


def bar(x, y_base, w, h, color):
    """Barra com topo arredondado (4px) e base reta, ancorada na linha de base."""
    r = min(3.0, w / 2, h)
    top = y_base - h
    return (f'<path d="M{x:.1f},{y_base:.1f} L{x:.1f},{top + r:.1f} Q{x:.1f},{top:.1f} {x + r:.1f},{top:.1f} '
            f'L{x + w - r:.1f},{top:.1f} Q{x + w:.1f},{top:.1f} {x + w:.1f},{top + r:.1f} L{x + w:.1f},{y_base:.1f} Z" '
            f'fill="{color}"/>')


def histogram():
    keys = list(BEFORE.keys())
    width, height = 640, 230
    left, right, top, base = 34, 10, 26, 190
    ymax = 30.0
    panel_gap = 26
    # Painel esquerdo (antes) ocupa 70%; direito (depois) 30%.
    lw = (width - left - right - panel_gap) * 0.70
    rw = (width - left - right - panel_gap) * 0.30
    parts = [f'<svg viewBox="0 0 {width} {height}" width="100%" role="img" '
             f'aria-label="Distribuição do percurso antes e depois da faixa de 28 a 32 passos">']
    sy = lambda v: (base - top) * v / ymax
    # grade e eixo y (compartilhado)
    for v in (0, 10, 20, 30):
        y = base - sy(v)
        parts.append(f'<line x1="{left}" y1="{y:.1f}" x2="{width - right}" y2="{y:.1f}" stroke="{GRID}" stroke-width="1"/>')
        parts.append(f'<text x="{left - 6}" y="{y + 3.5:.1f}" font-size="9" fill="{INK2}" text-anchor="end">{v}%</text>')
    # painel antes
    n = len(keys)
    step = lw / n
    bw = step - 2
    parts.append(f'<text x="{left}" y="13" font-size="10" font-weight="700" fill="#1d2125">Antes: saída a pelo menos 1/4 das seções livres</text>')
    for i, k in enumerate(keys):
        x = left + i * step + 1
        in_band = isinstance(k, int) and 28 <= k <= 32
        parts.append(bar(x, base, bw, sy(BEFORE[k]), ACCENT if in_band else MUTED))
        if k in (25, 30, 35, 40, 45, "51+"):
            parts.append(f'<text x="{x + bw / 2:.1f}" y="{base + 13}" font-size="9" fill="{INK2}" text-anchor="middle">{k}</text>')
    # anotação da cauda
    x40 = left + keys.index(40) * step
    parts.append(f'<text x="{x40:.1f}" y="{base - sy(8.5):.1f}" font-size="9" fill="{INK2}">15% dos mapas com 40+ passos</text>')
    parts.append(f'<line x1="{x40 + 4:.1f}" y1="{base - sy(7.6):.1f}" x2="{x40 + 4:.1f}" y2="{base - sy(2.6):.1f}" stroke="{INK2}" stroke-width="1"/>')
    # painel depois
    rx = left + lw + panel_gap
    rstep = rw / len(AFTER)
    parts.append(f'<text x="{rx}" y="13" font-size="10" font-weight="700" fill="#1d2125">Depois: 28 a 32 passos</text>')
    for i, (k, v) in enumerate(AFTER.items()):
        x = rx + i * rstep + 1
        parts.append(bar(x, base, rstep - 2, sy(v), ACCENT))
        parts.append(f'<text x="{x + (rstep - 2) / 2:.1f}" y="{base + 13}" font-size="9" fill="{INK2}" text-anchor="middle">{k}</text>')
    parts.append(f'<line x1="{left}" y1="{base}" x2="{width - right}" y2="{base}" stroke="#9aa3ab" stroke-width="1"/>')
    parts.append(f'<text x="{(left + width - right) / 2:.0f}" y="{height - 4}" font-size="9" fill="{INK2}" text-anchor="middle">menor caminho da partida até o ponto de resgate (passos)</text>')
    parts.append("</svg>")
    head = ('<div class="t">Figura 13. Percurso dos labirintos gerados, antes e depois da faixa</div>'
            '<div class="s">Simulação de 3.000 labirintos 15 × 15 por configuração. Em destaque, a faixa adotada.</div>')
    return head + "".join(parts)


def radio_rows():
    rows = []
    for line in ROTEIRO.read_text(encoding="utf-8").splitlines():
        if not line.startswith("| "):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 6 or not re.match(r"^\d+", cells[0]):
            continue
        num = re.match(r"^\d+", cells[0]).group(0)
        when, speech = cells[2], cells[5]

        def clean(text):
            text = re.sub(r"\*\*(.+?)\*\*", r"\1", text)
            text = re.sub(r"\*(.+?)\*", r"\1", text)
            text = text.replace("`", "")
            text = re.sub(r"\.\.\.(\s*\.\.\.)+", "...", text)
            text = text.replace("...", "…")
            return html.escape(text)

        rows.append(f'      <tr><td class="c k">{num}</td><td>{clean(when)}</td><td>{clean(speech)}</td></tr>')
    assert len(rows) == 19, f"esperava 19 falas no roteiro, achei {len(rows)}"
    return "\n".join(rows)


def render(page_map=None):
    text = SRC.read_text(encoding="utf-8")
    text = text.replace("{{HIST_CHART}}", histogram()).replace("{{RADIO_ROWS}}", radio_rows())
    if page_map:
        for key, page in page_map.items():
            text = text.replace(f'data-toc="{key}"></span>', f'data-toc="{key}">{page}</span>')
    OUT_HTML.write_text(text, encoding="utf-8")
    subprocess.run(["chromium", "--headless=new", "--no-pdf-header-footer", "--disable-gpu",
                    f"--print-to-pdf={OUT_PDF}", OUT_HTML.as_uri()],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def find_pages():
    """Página de cada capítulo: procura o título no texto de cada página do PDF."""
    out = subprocess.run(["pdftotext", "-layout", str(OUT_PDF), "-"], capture_output=True, text=True, check=True).stdout
    pages = out.split("\f")
    marks = {"s1": "Capítulo 1", "s2": "Capítulo 2", "s3": "Capítulo 3", "s4": "Capítulo 4",
             "s5": "Capítulo 5", "s6": "Capítulo 6", "s7": "Capítulo 7", "s8": "Capítulo 8",
             "s9": "Capítulo 9", "s10": "Capítulo 10", "s11": "Capítulo 11",
             "sA": "Apêndice A", "sB": "Apêndice B"}
    found = {}
    for key, mark in marks.items():
        for i, page in enumerate(pages):
            # O "olho" do capítulo fica sozinho numa linha; menções no texto não contam.
            # pdftotext pode separar as letras do "olho" (letter-spacing): compara sem espaços.
            if any(line.replace(" ", "").upper() == mark.replace(" ", "").upper() for line in page.splitlines()):
                found[key] = i + 1
                break
    return found


if __name__ == "__main__":
    render()
    pages = find_pages()
    render(pages)
    print(f"PDF: {OUT_PDF}")
    print("Sumário:", pages)
