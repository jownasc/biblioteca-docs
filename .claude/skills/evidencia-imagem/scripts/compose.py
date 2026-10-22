"""Monta uma imagem de evidência (prints + tabelas + quadrados vermelhos + texto).

Uso:
  python compose.py spec.json          -> Biblioteca/exportacoes/<task>-<slug>.png
                                          (se já existir: -v2, -v3... nunca sobrescreve)
  python compose.py --grid print.png   -> print-grid.png ao lado do original, com régua
                                          a cada 50px pra achar as coordenadas dos quadrados

spec.json:
{
  "task": "104500",
  "slug": "relatorio-coluna-corrigida",
  "title": "Relatório de pedidos — coluna Responsável corrigida",
  "subtitle": "Bug 104500 · Vendas > Pedidos > Exportar",
  "sections": [
    {"title": "1. Lançamento", "text": "…", "image": "C:/caminho/print.png",
     "boxes": [[x0, y0, x1, y1], {"box": [x0, y0, x1, y1], "n": 1}],
     "blur": [[x0, y0, x1, y1]],
     "alert": false},
    {"row": [ {seção A}, {seção B} ]},
    {"title": "3. Depois", "text": "…",
     "table": {"header": {"label": "Filial:", "value": "SP-01"},
               "columns": [["Pedido", 80], ["Responsável", 260]],
               "rows": [["1", "Equipe Norte"]],
               "highlight": [[0, 1], [0, 1, 2]]}}
  ],
  "notes_title": "Regras",
  "notes": ["texto com marcador", {"n": 1, "text": "texto ligado ao quadrado ①"}]
}

- Coordenadas de "boxes"/"blur" em pixels da imagem ORIGINAL (use --grid pra achar).
- "blur": pixela a área (nome/e-mail de usuário, dado pessoal) antes de qualquer quadrado.
- "n" (em box, highlight [linha, coluna, n] ou nota): selo vermelho numerado, pra ligar
  o destaque à regra correspondente.
- {"row": [A, B]}: duas seções lado a lado (ex.: Antes | Depois com prints estreitos).
- "header" da tabela é opcional; "fill" troca a cor de fundo do valor (padrão amarelo,
  null = sem fundo).
"""
import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# <Biblioteca>/.claude/skills/evidencia-imagem/scripts/compose.py - resolve()
# segue a junction de ~/.claude/skills ate a pasta real dentro da Biblioteca.
OUT_DIR = Path(__file__).resolve().parents[4] / "exportacoes"
FONTS = Path("C:/Windows/Fonts")
RED = (220, 30, 30)
BG = (248, 248, 250)
W = 1340
PAD = 40
GAP = 30


def font(size, bold=False):
    return ImageFont.truetype(str(FONTS / ("segoeuib.ttf" if bold else "segoeui.ttf")), size)


def wrap(text, fnt, max_w):
    measure = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    lines = []
    for paragraph in str(text).split("\n"):
        line = ""
        for word in paragraph.split(" "):
            candidate = f"{line} {word}".strip()
            if line and measure.textlength(candidate, font=fnt) > max_w:
                lines.append(line)
                line = word
            else:
                line = candidate
        lines.append(line)
    return lines


def badge(draw, x, y, n):
    r = 14
    draw.ellipse([x - r, y - r, x + r, y + r], fill=RED)
    draw.text((x, y), str(n), font=font(16, True), fill="white", anchor="mm")


def as_box(item):
    return (item["box"], item.get("n")) if isinstance(item, dict) else (item, None)


def pixelate(img, box, block=12):
    x0, y0, x1, y1 = box
    area = img.crop(box)
    small = area.resize((max(1, (x1 - x0) // block), max(1, (y1 - y0) // block)), Image.BILINEAR)
    img.paste(small.resize(area.size, Image.NEAREST), (x0, y0))


def check_inside(img, box, what, section):
    x0, y0, x1, y1 = box
    if x0 < 0 or y0 < 0 or x1 > img.width or y1 > img.height or x0 >= x1 or y0 >= y1:
        print(f"AVISO: {what} {box} fora da imagem {img.size} em '{section.get('title', '')}'"
              " — confira com --grid", file=sys.stderr)


def boxed_image(section):
    img = Image.open(section["image"]).convert("RGB")
    for area in section.get("blur", []) + [as_box(b)[0] for b in section.get("boxes", [])]:
        check_inside(img, area, "área", section)
    for area in section.get("blur", []):
        pixelate(img, area)
    draw = ImageDraw.Draw(img)
    for item in section.get("boxes", []):
        box, n = as_box(item)
        draw.rectangle(box, outline=RED, width=4)
        if n is not None:
            badge(draw, box[0], box[1], n)
    return img


def table_image(table):
    columns = table["columns"]
    rows = table["rows"]
    marks = {(h[0], h[1]): (h[2] if len(h) > 2 else None) for h in table.get("highlight", [])}
    row_h = 34
    header = table.get("header")
    top = row_h + 4 if header else 0
    width = sum(w for _, w in columns)
    img = Image.new("RGB", (width + 20, top + row_h * (len(rows) + 1) + 20), "white")
    draw = ImageDraw.Draw(img)
    ox, oy = 14, 14  # respiro pro selo numerado no canto da célula
    if header:
        label_w = draw.textlength(header["label"], font=font(15, True))
        value = str(header["value"])
        vx = ox + label_w + 20
        fill = header.get("fill", (255, 255, 0))
        if fill:
            fill = tuple(fill)
            draw.rectangle([vx, oy, vx + max(200, draw.textlength(value, font=font(15)) + 16), oy + 26], fill=fill)
        draw.text((ox + 6, oy + 2), header["label"], font=font(15, True), fill="black")
        draw.text((vx + 6, oy + 2), value, font=font(15), fill="black")
    x = ox
    for name, w in columns:
        draw.rectangle([x, oy + top, x + w, oy + top + row_h], outline=(200, 200, 200))
        draw.text((x + 6, oy + top + 7), name, font=font(14, True), fill="black")
        x += w
    badges = []
    for r, row in enumerate(rows):
        y = oy + top + row_h * (r + 1)
        x = ox
        for c, ((_, w), value) in enumerate(zip(columns, row)):
            hot = (r, c) in marks
            draw.rectangle([x, y, x + w, y + row_h], outline=(220, 220, 220))
            draw.text((x + 6, y + 7), str(value), font=font(14, hot), fill="black")
            if hot:
                draw.rectangle([x - 1, y - 1, x + w + 1, y + row_h + 1], outline=RED, width=4)
                if marks[(r, c)] is not None:
                    badges.append((x, y, marks[(r, c)]))
            x += w
    for bx, by, n in badges:
        badge(draw, bx, by, n)
    return img


def fit(img, max_w):
    if img.width <= max_w:
        return img
    return img.resize((max_w, int(img.height * max_w / img.width)), Image.LANCZOS)


def render_section(section, width):
    content = boxed_image(section) if "image" in section else table_image(section["table"])
    if content.width * 0.7 > width:
        print(f"AVISO: '{section.get('title', '')}' reduzida a {width * 100 // content.width}% "
              f"({content.width}px -> {width}px), texto do print pode ficar ilegível — "
              "recorte o print ou não use 'row'", file=sys.stderr)
    content = fit(content, width)
    title_lines = wrap(section.get("title", ""), font(22, True), width) if section.get("title") else []
    text_lines = wrap(section["text"], font(17), width) if section.get("text") else []
    head = 32 * len(title_lines) + 26 * len(text_lines) + (12 if title_lines or text_lines else 0)
    block = Image.new("RGB", (width, head + content.height + 2), BG)
    draw = ImageDraw.Draw(block)
    y = 0
    color = RED if section.get("alert") else (20, 20, 20)
    for line in title_lines:
        draw.text((0, y), line, font=font(22, True), fill=color)
        y += 32
    for line in text_lines:
        draw.text((0, y), line, font=font(17), fill=(50, 50, 50))
        y += 26
    y = head
    block.paste(content, (1, y + 1))
    draw.rectangle([0, y, content.width + 1, y + content.height + 1], outline=(210, 210, 210))
    return block


def render_block(section, width):
    if "row" not in section:
        return render_section(section, width)
    parts = section["row"]
    col_w = (width - GAP * (len(parts) - 1)) // len(parts)
    rendered = [render_section(p, col_w) for p in parts]
    block = Image.new("RGB", (width, max(r.height for r in rendered)), BG)
    for i, r in enumerate(rendered):
        block.paste(r, (i * (col_w + GAP), 0))
    return block


def free_path(task, slug):
    base = OUT_DIR / f"{task}-{slug}.png"
    if not base.exists():
        return base
    v = 2
    while (OUT_DIR / f"{task}-{slug}-v{v}.png").exists():
        v += 1
    return OUT_DIR / f"{task}-{slug}-v{v}.png"


def grid(path):
    img = Image.open(path).convert("RGB")
    draw = ImageDraw.Draw(img, "RGBA")
    small = font(11)
    for x in range(0, img.width, 50):
        draw.line([(x, 0), (x, img.height)], fill=(0, 120, 255, 90 if x % 100 else 160), width=1)
        draw.text((x + 2, 2), str(x), font=small, fill=(0, 80, 220))
    for y in range(0, img.height, 50):
        draw.line([(0, y), (img.width, y)], fill=(0, 120, 255, 90 if y % 100 else 160), width=1)
        draw.text((2, y + 2), str(y), font=small, fill=(0, 80, 220))
    out = Path(path).with_name(Path(path).stem + "-grid.png")
    img.save(out)
    print(out, img.size)


def main(spec_path):
    spec = json.loads(Path(spec_path).read_text(encoding="utf-8"))
    inner = W - 2 * PAD
    title_lines = wrap(spec["title"], font(30, True), inner)
    sub_lines = wrap(spec["subtitle"], font(17), inner) if spec.get("subtitle") else []
    blocks = [render_block(s, inner) for s in spec["sections"]]
    note_font = font(16)
    notes = []
    for note in spec.get("notes", []):
        n, text = (note.get("n"), note["text"]) if isinstance(note, dict) else (None, note)
        notes.append((n, wrap(text, note_font, inner - 50)))

    height = (30 + 44 * len(title_lines) + 26 * len(sub_lines) + 30
              + sum(b.height + 40 for b in blocks) + 60
              + sum(26 * len(lines) + 10 for _, lines in notes) + 40)
    canvas = Image.new("RGB", (W, height), BG)
    draw = ImageDraw.Draw(canvas)
    y = 30
    for line in title_lines:
        draw.text((PAD, y), line, font=font(30, True), fill=(20, 20, 20))
        y += 44
    for line in sub_lines:
        draw.text((PAD, y), line, font=font(17), fill=(90, 90, 90))
        y += 26
    y += 30
    for b in blocks:
        canvas.paste(b, (PAD, y))
        y += b.height + 40
    if notes:
        draw.text((PAD, y), spec.get("notes_title", "Observações"), font=font(22, True), fill=(20, 20, 20))
        y += 40
        for n, lines in notes:
            if n is None:
                draw.text((PAD + 10, y), "•", font=note_font, fill=(40, 40, 40))
            else:
                badge(draw, PAD + 16, y + 12, n)
            for line in lines:
                draw.text((PAD + 40, y), line, font=note_font, fill=(40, 40, 40))
                y += 26
            y += 10
    canvas = canvas.crop((0, 0, W, y + 30))

    slug = re.sub(r"[^a-z0-9-]+", "-", spec["slug"].lower()).strip("-")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = free_path(spec["task"], slug)
    canvas.save(out)
    print(out, canvas.size)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    if len(sys.argv) == 3 and sys.argv[1] == "--grid":
        grid(sys.argv[2])
    else:
        main(sys.argv[1])
