#!/usr/bin/env python3
"""Biblioteca -> PDF (tema escuro). Uso: python convert_to_pdf.py <arquivo.md> [saida.pdf]

Motor unico: Edge (Chromium) headless, --print-to-pdf. Trocado do
wkhtmltopdf em 2026-10-07: o WebKit de 2012 dele nao tem margem por pagina
com fundo escuro (a margem nativa sai branca, entao so' a pagina 1 tinha
respiro no topo), ignora break-after/orphans/widows e exigia medir o PDF
com poppler para pintar o fundo ate o fim da ultima pagina. O Chromium
resolve os tres com CSS (box-decoration-break: clone, break-*, :has).
weasyprint segue descartado (falha ao carregar libgobject no Windows).
"""
import sys, re, os, subprocess, html, shutil, tempfile
from pathlib import Path
import yaml

THEME = {
    "bg": "#1c1e21", "card": "#24262a", "card_alt": "#202226",
    "border": "#34363b", "text": "#eceeef", "muted": "#9a9da3", "dim": "#6f7278",
    "gold": "#d9b568", "gold_bright": "#d9b26a", "green": "#86b894", "teal": "#7cbfc4",
    "pink": "#c184a0", "purple": "#9a83c9", "blue": "#6f9bd1", "brown": "#a89484",
    "red": "#ef4444", "yellow": "#eab308",
    "code_bg": "#141517",
}

# Cores por tipo = MESMAS cores dos chips do dashboard real
# (_ferramenta/dashboard-visual/scripts/build-dashboard.ps1, .chip-*) -
# nao inventar paleta paralela. reqs/resumo nao tem chip no dashboard
# (resumo e' o doc "representante" do card, reqs nem entra no sync-all),
# cor propria so' pra dar uma identidade visual no PDF.
TYPE_ACCENT = {
    "task-code": THEME["gold"],
    "task-planning": THEME["teal"],
    "testes": THEME["green"],
    "handover-tecnico": THEME["pink"],
    "rules": THEME["brown"],
    "reqs": THEME["blue"],
    "resumo": THEME["purple"],
}
DEFAULT_ACCENT = THEME["gold_bright"]

# Vocabulario real de status da Biblioteca (01-regras-biblioteca.md /
# controle-documentacao) - "blocked" nao existe, nao inventar.
STATUS_LABEL = {
    "draft": "Rascunho", "in_progress": "Em andamento", "completed": "Concluído",
    "superseded": "Substituído", "archived": "Arquivado",
}


def split_frontmatter(text):
    m = re.match(r'^---\n(.*?)\n---\n(.*)$', text, re.DOTALL)
    if not m:
        return {}, text
    return yaml.safe_load(m.group(1)) or {}, m.group(2)


def build_pr_html(fm):
    """Junta pr_merged (sempre) + pr_pending (marcado como pendente) - um
    doc in_progress com PR aberto tambem deve aparecer no PDF, nao so
    o que ja foi mergeado."""
    parts = []
    for url in (fm.get("pr_merged") or "").split():
        parts.append(f'<a href="{html.escape(url)}">PR</a>')
    for url in (fm.get("pr_pending") or "").split():
        parts.append(f'<a href="{html.escape(url)}">PR (pendente)</a>')
    if not parts:
        return ""
    return f'<div class="pr-line"><span class="meta-label">PRs</span>&nbsp; {" &nbsp;•&nbsp; ".join(parts)}</div>'


def build_header(fm, doc_title):
    accent = TYPE_ACCENT.get(fm.get("type", ""), DEFAULT_ACCENT)
    # titulo_busca e' o titulo primario (convencao do dashboard, 2026-09-11
    # - card mostra titulo_busca em destaque, function vira subtitulo). Sem
    # titulo_busca, function vira o titulo sozinho (sem subtitulo).
    titulo_busca = fm.get("titulo_busca")
    function = fm.get("function")
    primary = titulo_busca or function or doc_title
    subtitle = function if (titulo_busca and function) else None

    status = fm.get("status", "")
    label = STATUS_LABEL.get(status, status)
    fields = [("task", "Task"), ("type", "Tipo"), ("repo", "Repositório"), ("author", "Autor"), ("updated", "Atualizado")]
    items = "".join(
        f'<span class="meta-item"><span class="meta-label">{html.escape(l)}</span>'
        f'<span class="meta-value">{html.escape(str(fm.get(k)))}</span></span>'
        for k, l in fields if fm.get(k)
    )
    subtitle_html = f'<div class="doc-subtitle">{html.escape(subtitle)}</div>' if subtitle else ""
    pr_html = build_pr_html(fm)
    return f'''
    <div class="doc-header" style="border-bottom:2px solid {accent}">
      <div class="doc-header-top">
        <span class="doc-number">#{fm.get("number", "")}</span>
        <span class="status-badge" style="color:{accent};background:{accent}22;border:1px solid {accent}55">{html.escape(label)}</span>
        <span class="type-tag" style="color:{accent}">{html.escape(fm.get("type", ""))}</span>
      </div>
      <h1 class="doc-title">{html.escape(primary)}</h1>
      {subtitle_html}
      <div class="meta-grid">{items}</div>
      {pr_html}
    </div>'''


def css(accent, landscape=False, chapters=False):
    # Margem de pagina 0 + padding do body com box-decoration-break: clone =
    # o padding se repete em CADA pagina e o fundo escuro do html cobre a
    # folha inteira, inclusive a "margem". @page margin daria margem branca.
    # Fontes alinhadas ao dashboard da Biblioteca (system-ui / Consolas).
    mono = 'Consolas, "Cascadia Code", "Courier New", monospace'
    size = "A4 landscape" if landscape else "A4"
    # Altura util em paisagem ~172mm: titulo + paragrafo + legenda + respiro
    # precisam caber junto com a imagem, senao o texto fica numa pagina e a
    # figura na outra.
    img_max_h = "112mm" if landscape else "150mm"
    # Capitulo (h2) em pagina nova, como secao primaria em ABNT. O primeiro
    # h2 nao quebra, senao o cabecalho do doc ficaria sozinho na pagina 1.
    chapter_rule = "h2 ~ h2 { break-before: page; }" if chapters else ""
    return f'''
    @page {{ size:{size}; margin:0; }}
    html {{ background:{THEME["bg"]}; -webkit-print-color-adjust:exact; print-color-adjust:exact; }}
    * {{ box-sizing:border-box; }}
    body {{ background:{THEME["bg"]}; color:{THEME["text"]}; font-family:system-ui, -apple-system, "Segoe UI", sans-serif;
            font-size:12pt; line-height:1.6; margin:0; padding:20mm 18mm 18mm 18mm;
            -webkit-box-decoration-break:clone; box-decoration-break:clone;
            counter-reset:figura; }}
    .doc-header {{ padding-bottom:20px; margin-bottom:28px; }}
    .doc-header-top {{ margin-bottom:10px; }}
    .doc-number {{ font-family:{mono}; color:{THEME["dim"]}; font-size:10.5pt; margin-right:12px; }}
    .status-badge {{ display:inline-block; padding:3px 12px; border-radius:14px; font-size:9.5pt; font-weight:600; margin-right:8px; }}
    .type-tag {{ font-family:{mono}; font-size:9.5pt; opacity:0.85; }}
    .doc-title {{ font-size:19pt; margin:10px 0 4px 0; color:#ffffff; line-height:1.35; }}
    .doc-subtitle {{ font-size:12pt; color:{THEME["muted"]}; margin:0 0 16px 0; }}
    .meta-grid {{ margin:0 0 8px 0; }}
    .meta-item {{ display:inline-block; margin:0 30px 6px 0; vertical-align:top; }}
    .meta-label {{ color:{THEME["dim"]}; font-size:8.5pt; text-transform:uppercase; letter-spacing:0.05em; display:block; }}
    .meta-value {{ color:{THEME["text"]}; font-weight:600; font-size:11pt; display:block; margin-top:2px; }}
    .pr-line {{ margin-top:10px; font-size:11pt; color:{THEME["muted"]}; }}
    .pr-line a {{ color:{accent}; text-decoration:none; }}
    /* Hierarquia de espaco: mais respiro ANTES do titulo que depois, para ele
       pertencer ao conteudo de baixo. No topo de pagina o Chromium descarta a
       margem de cima sozinho. */
    h1, h2, h3 {{ color:#ffffff; break-after:avoid; }}
    h2 {{ font-size:15pt; margin:36px 0 12px 0; padding-bottom:6px; border-bottom:1px solid {THEME["border"]}; }}
    h3 {{ font-size:13pt; color:{accent}; margin:28px 0 8px 0; }}
    {chapter_rule}
    p {{ margin:0 0 10px 0; orphans:3; widows:3; }}
    /* Paragrafo que apresenta a figura seguinte fica na mesma pagina dela. */
    p:has(+ figure) {{ break-after:avoid; }}
    ul, ol {{ margin:0 0 12px 0; padding-left:24px; }}
    li {{ margin:4px 0; }}
    table {{ border-collapse:collapse; width:100%; margin:14px 0 18px 0; font-size:10.5pt; }}
    thead {{ display:table-header-group; }}
    tr {{ break-inside:avoid; }}
    th, td {{ border:1px solid {THEME["border"]}; padding:7px 10px; text-align:left; vertical-align:top; }}
    th {{ background:{THEME["card_alt"]}; color:{accent}; font-weight:600; }}
    td {{ background:{THEME["card"]}; }}
    .page-break {{ break-before:page; }}
    code {{ font-family:{mono}; background:{THEME["code_bg"]}; color:{THEME["gold_bright"]};
            padding:2px 5px; border-radius:3px; font-size:10.5pt; }}
    pre {{ background:{THEME["code_bg"]}; color:#d8dadd; padding:14px 16px; border-radius:8px;
           font-size:10pt; margin:14px 0; border:1px solid {THEME["border"]}; break-inside:avoid; white-space:pre-wrap; }}
    pre code {{ background:none; color:inherit; padding:0; }}
    /* Figura no estilo ABNT: "Figura N - titulo" ACIMA da imagem, respiro em
       volta e nunca partida entre paginas. */
    figure {{ margin:6mm 0 8mm 0; break-inside:avoid; display:flex; flex-direction:column; align-items:center;
              counter-increment:figura; }}
    figcaption {{ order:-1; text-align:center; font-size:10pt; font-weight:600; color:{THEME["muted"]}; margin-bottom:3mm; }}
    figcaption::before {{ content:"Figura " counter(figura) " \\2014  "; color:{accent}; }}
    /* Paisagem: altura fixa = todas as capturas do mesmo tamanho, mesmo as de
       resolucao menor (senao saem no tamanho natural, menores que as outras).
       Retrato: largura total, com teto de altura. */
    img {{ {"height:" + img_max_h + "; width:auto;" if landscape else "width:100%; max-height:" + img_max_h + ";"}
           max-width:100%; object-fit:contain;
           border:1px solid {THEME["border"]}; border-radius:6px; }}
    blockquote {{ border-left:3px solid {accent}; margin:14px 0; padding:8px 16px; color:{THEME["muted"]};
                  background:{THEME["card"]}; border-radius:0 6px 6px 0; break-inside:avoid; }}
    details {{ border:1px solid {THEME["border"]}; border-radius:8px; padding:12px 16px; margin:20px 0;
               background:{THEME["card"]}; break-inside:avoid; }}
    summary {{ font-weight:600; color:{accent}; }}
    strong {{ color:#ffffff; }}
    hr {{ border:none; border-top:1px solid {THEME["border"]}; margin:26px 0; }}
    a {{ color:{THEME["teal"]}; }}
    .footer-note {{ margin-top:36px; padding-top:12px; border-top:1px solid {THEME["border"]};
                    font-size:8.5pt; color:{THEME["dim"]}; }}
    '''


def has_wide_image(body, md_dir):
    """Print de tela largo (>= 1000px e proporcao >= 1.3) em retrato fica
    pequeno demais para ler - nesse caso o doc vai para paisagem. Imagem
    remota ou ilegivel nao conta."""
    from PIL import Image
    for src in re.findall(r'!\[[^\]]*\]\(([^)\s]+)', body):
        path = Path(md_dir, src)
        if src.startswith(("http:", "https:")) or not path.is_file():
            continue
        try:
            with Image.open(path) as im:
                w, h = im.size
        except OSError:
            continue
        if w >= 1000 and w / h >= 1.3:
            return True
    return False


def convert(md_path, pdf_path):
    raw = open(md_path, encoding="utf-8").read()
    fm, body = split_frontmatter(raw)
    accent = TYPE_ACCENT.get(fm.get("type", ""), DEFAULT_ACCENT)
    # Padrao: retrato, sem capitulos. Paisagem vem sozinha quando o doc tem
    # print de tela largo; `pdf_orientation: portrait|landscape` no
    # frontmatter sempre vence. `pdf_chapters: true` = cada h2 em pagina nova.
    orientation = str(fm.get("pdf_orientation", "")).lower()
    md_dir = os.path.dirname(os.path.abspath(md_path))
    landscape = orientation == "landscape" or (
        orientation != "portrait" and has_wide_image(body, md_dir))
    chapters = fm.get("pdf_chapters") is True
    doc_title = os.path.basename(md_path).rsplit(".", 1)[0]

    body = body.replace("<details>", "<details open>")
    body = re.sub(r'<!-- badge:auto -->.*?<!-- /badge:auto -->\n?', '', body, flags=re.DOTALL)
    body = re.sub(r'<!-- related:auto -->.*?<!-- /related:auto -->\n?', '', body, flags=re.DOTALL)
    body = re.sub(r'<!-- meta:auto -->.*?<!-- /meta:auto -->\n?', '', body, flags=re.DOTALL)
    # Emoji que os templates usam em tabela (testes.md) - so os 3 usados.
    body = body.replace("✅", f'<span style="color:{THEME["green"]}">✔</span>')
    body = body.replace("❌", f'<span style="color:{THEME["red"]}">✘</span>')
    body = body.replace("⚠️", f'<span style="color:{THEME["yellow"]}">⚠</span>')

    body_html = subprocess.run(
        ["pandoc", "--from=markdown+pipe_tables+fenced_code_blocks", "--to=html5"],
        input=body, capture_output=True, text=True, encoding="utf-8").stdout
    # O HTML e' renderizado numa pasta temporaria: imagem com caminho relativo
    # ao .md vira file:/// absoluto, senao o navegador nao a encontra.
    body_html = re.sub(
        r'src="(?!https?:|file:|data:)([^"]+)"',
        lambda m: 'src="' + Path(md_dir, m.group(1)).resolve().as_uri() + '"',
        body_html)

    # <title> = nome do .md - metadado do PDF, separado do H1 visual.
    full_html = f'''<!DOCTYPE html><html><head><meta charset="utf-8"><title>{html.escape(doc_title)}</title>
    <style>{css(accent, landscape, chapters)}</style></head>
    <body>{build_header(fm, doc_title)}{body_html}
    <div class="footer-note">Convertido de {html.escape(os.path.basename(md_path))} — Biblioteca de documentação técnica</div>
    </body></html>'''

    with tempfile.TemporaryDirectory() as tmpdir:
        html_path = os.path.join(tmpdir, doc_title + ".html")
        with open(html_path, "w", encoding="utf-8") as f:
            f.write(full_html)
        render_pdf(html_path, pdf_path, tmpdir)
    print("OK:", pdf_path)


_BROWSER_PATHS = [
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
]


def find_browser():
    found = shutil.which("msedge") or shutil.which("chrome")
    return found or next((p for p in _BROWSER_PATHS if os.path.exists(p)), None)


def render_pdf(html_path, pdf_path, tmpdir):
    browser = find_browser()
    if not browser:
        raise RuntimeError("Edge/Chrome nao encontrado (procurado em: " + ", ".join(_BROWSER_PATHS) + ").")
    pdf_path = os.path.abspath(pdf_path)
    if os.path.exists(pdf_path):
        os.remove(pdf_path)
    # --user-data-dir proprio: sem ele o Edge headless se anexa a sessao do
    # navegador que o usuario ja tem aberta.
    result = subprocess.run(
        [browser, "--headless=new", "--disable-gpu", "--no-first-run", "--no-pdf-header-footer",
         "--user-data-dir=" + os.path.join(tmpdir, "profile"),
         "--print-to-pdf=" + pdf_path, Path(html_path).as_uri()],
        capture_output=True, text=True, timeout=180,
    )
    if not os.path.exists(pdf_path):
        raise RuntimeError(f"Edge headless falhou ({result.returncode}): {result.stderr[-500:]}")
    print("(motor: Edge headless)")


def default_output_path(md_path):
    """Sem saida explicita, o PDF vai pra Biblioteca/exportacoes/ (ver SKILL.md)
    - doc.md mora sempre em Biblioteca/{tipo}/doc.md (estrutura flat, sem
    frontend/backend), entao exportacoes/ e' irmã da pasta do tipo."""
    biblioteca_root = os.path.dirname(os.path.dirname(os.path.abspath(md_path)))
    basename = os.path.basename(md_path).rsplit(".", 1)[0]
    return os.path.join(biblioteca_root, "exportacoes", basename + ".pdf")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python convert_to_pdf.py <arquivo.md> [saida.pdf]")
        sys.exit(1)
    md = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else default_output_path(md)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    convert(md, out)
