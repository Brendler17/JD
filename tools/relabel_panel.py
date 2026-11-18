#!/usr/bin/env python3
"""Regrava os rótulos da placa cinza do painel SM_Devices01 (sob o monitor superior).

Gera `T_Devices01_BC_1004_rotulos.png` a partir da textura original
`T_Devices01_BC_1004.png` (que não é alterada), usada pelo M_Devices01_1004.tres:
- apaga "BCN", "PULSE", "CAMERA" e "L/R VT" (knobs sem função no jogo), cobrindo
  cada rótulo com um pedaço liso da própria placa, logo à direita, com borda suave
  e tom corrigido pela moldura do rótulo (a luz está pintada na textura);
- escreve "MUTE" sob o knob do alarme (o antigo "BCN") com as letras originais da
  placa: M de CAMERA, U e E de PULSE, T de L/R VT. Mesma fonte, tinta e desgaste.

Só a cor (BC) tem os rótulos; normal e ORM são lisos nessa região.
Se o painel for reexportado da Unreal, rode de novo:
    python3 tools/relabel_panel.py
Requer Pillow.

As coordenadas são do recorte girado (placa na horizontal, como o jogador a vê):
recorte (0, 880)–(410, 3140) da textura de 4096², girado 90º anti-horário.
Medidas em 2026-11-17 (UV da placa a partir da malha, ver TDD §7.1).
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

Image.MAX_IMAGE_PIXELS = None

TEX_DIR = Path(__file__).resolve().parent.parent / "assets/imports/sm_devices01/textures"
SOURCE = TEX_DIR / "T_Devices01_BC_1004.png"
OUTPUT = TEX_DIR / "T_Devices01_BC_1004_rotulos.png"

# Região da placa na textura original (x0, y0, x1, y1).
PLATE_BOX = (0, 880, 410, 3140)

# Rótulos a apagar no recorte girado: (x0, y0, x1, y1) e deslocamento horizontal
# até um trecho liso da placa na mesma altura (mesma luz e sujeira).
ERASE = [
    ((176, 224, 276, 295), 170),   # BCN
    ((595, 224, 737, 292), 150),   # PULSE
    ((1006, 222, 1183, 290), 170),  # CAMERA
    ((1464, 222, 1615, 286), 200),  # L/R VT
]
FEATHER = 8

# Letras originais (x0, x1, y0, y1) no recorte girado, antes de apagar.
GLYPHS = {
    "M": (1070, 1096, 235, 277),  # CAMERA
    "U": (634, 655, 239, 280),    # PULSE
    "T": (1581, 1601, 233, 273),  # L/R VT
    "E": (706, 723, 238, 279),    # PULSE
}
WORD = "MUTE"
# Centro horizontal e base do "BCN" (onde o MUTE entra) e espaço entre letras.
WORD_CENTER_X = 226
WORD_BASELINE = 283
LETTER_GAP = 4


def luminance(rgb):
    r, g, b = rgb[:3]
    return 0.299 * r + 0.587 * g + 0.114 * b


def glyph_layer(plate, box):
    """Recorta uma letra como cor de tinta + alfa (pela escuridão em relação ao fundo)."""
    x0, x1, y0, y1 = box
    pad = 1
    crop = plate.crop((x0 - pad, y0 - pad, x1 + pad, y1 + pad + 1)).convert("RGB")
    pixels = list(crop.getdata())
    lums = sorted(luminance(p) for p in pixels)
    ink_l = sum(lums[: max(1, len(lums) // 10)]) / max(1, len(lums) // 10)
    bg_l = lums[int(len(lums) * 0.9)]
    dark = [p for p in pixels if luminance(p) <= ink_l + 8]
    ink = tuple(int(sum(c[i] for c in dark) / len(dark)) for i in range(3))
    alpha = Image.new("L", crop.size)
    alpha.putdata([
        int(max(0.0, min(1.0, (bg_l - luminance(p)) / max(1.0, bg_l - ink_l))) * 255)
        for p in pixels
    ])
    color = Image.new("RGB", crop.size, ink)
    return color, alpha, pad


def ring_mean(img, box, band=6):
    """Cor média da moldura em volta de `box` (fora dele), para casar o tom do remendo."""
    x0, y0, x1, y1 = box
    sums = [0, 0, 0]
    count = 0
    px = img.load()
    for y in range(y0 - band, y1 + band):
        for x in range(x0 - band, x1 + band):
            if x0 <= x < x1 and y0 <= y < y1:
                continue
            p = px[x, y]
            for i in range(3):
                sums[i] += p[i]
            count += 1
    return [v / count for v in sums]


def main():
    source = Image.open(SOURCE)
    plate = source.crop(PLATE_BOX).rotate(90, expand=True)
    original = plate.copy()

    # 1) Apagar os rótulos.
    for (x0, y0, x1, y1), dx in ERASE:
        patch = original.crop((x0 + dx, y0, x1 + dx, y1))
        # A luz está "pintada" na textura: o trecho da direita pode ser mais claro.
        # Desloca cada canal para a cor média da moldura do rótulo apagado.
        target = ring_mean(original, (x0, y0, x1, y1))
        source_mean = ring_mean(original, (x0 + dx, y0, x1 + dx, y1))
        bands = list(patch.split())
        for i in range(3):
            offset = round(target[i] - source_mean[i])
            bands[i] = bands[i].point(lambda v, o=offset: max(0, min(255, v + o)))
        patch = Image.merge(patch.mode, bands)
        mask = Image.new("L", patch.size, 0)
        # Opaco a partir de ~FEATHER px da borda; as margens dos retângulos (≥ 12 px)
        # garantem que o texto antigo fica todo na parte opaca.
        ImageDraw.Draw(mask).rectangle((2, 2, patch.size[0] - 3, patch.size[1] - 3), fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(FEATHER / 2))
        plate.paste(patch, (x0, y0), mask)

    # 2) Escrever MUTE com as letras originais, alinhadas pela base.
    layers = [glyph_layer(original, GLYPHS[ch]) for ch in WORD]
    width = sum(GLYPHS[ch][1] - GLYPHS[ch][0] for ch in WORD) + LETTER_GAP * (len(WORD) - 1)
    x = WORD_CENTER_X - width // 2
    for ch, (color, alpha, pad) in zip(WORD, layers):
        x0, x1, y0, y1 = GLYPHS[ch]
        top = WORD_BASELINE - (y1 - y0) - pad
        plate.paste(color, (x - pad, top), alpha)
        x += (x1 - x0) + LETTER_GAP

    result = source.copy()
    result.paste(plate.rotate(-90, expand=True), PLATE_BOX[:2])
    result.save(OUTPUT)
    print(f"Gerado: {OUTPUT}")


if __name__ == "__main__":
    main()
