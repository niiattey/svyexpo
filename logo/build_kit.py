"""Build the svyexpo logo kit from concept A (halftone buffer).

Outputs (in ./kit):
  symbol-black.svg / symbol-white.svg / symbol-colour.svg / symbol-small.svg
  sticker.svg        hex sticker with outlined wordmark (colour)
  sticker-mono.svg   one-colour sticker (black on transparent)
  wordmark-*.svg     horizontal lockup (symbol + outlined wordmark)

Palette
  teal  #0F3D4C   amber #F2B544 (on dark)   amber-dark #C47F00 (on light)
"""
import math
import os

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

OUT = "kit"
os.makedirs(OUT, exist_ok=True)

TEAL, AMBER, AMBER_DK, WHITE = "#0F3D4C", "#F2B544", "#C47F00", "#FFFFFF"
FONT = "/usr/share/fonts/opentype/inter/Inter-Bold.otf"
CX = CY = 128.0


# ------------------------------------------------------------------ cells
def cells(n, pitch, r, thresh, min_side, full_side, sub=24):
    """Grid cells scaled by the fraction of the buffer circle that covers them."""
    origin = CX - n * pitch / 2
    out = []
    for i in range(n):
        for j in range(n):
            x0, y0 = origin + i * pitch, origin + j * pitch
            inside = 0
            for a in range(sub):
                for b in range(sub):
                    px = x0 + (a + .5) * pitch / sub
                    py = y0 + (b + .5) * pitch / sub
                    if (px - CX) ** 2 + (py - CY) ** 2 <= r * r:
                        inside += 1
            cov = inside / sub ** 2
            if cov < thresh:
                continue
            side = max(full_side * math.sqrt(cov), min_side)
            cx, cy = x0 + pitch / 2, y0 + pitch / 2
            out.append((cx - side / 2, cy - side / 2, side, cov))
    return out


MAIN = cells(n=8, pitch=28.0, r=100.0, thresh=0.22, min_side=9.0, full_side=23.0)
# Small-size cut: fewer, larger cells so it survives 16-32 px.
SMALL = cells(n=6, pitch=40.0, r=108.0, thresh=0.5, min_side=30.0, full_side=35.0)


def rect(x, y, s, fill=None):
    f = f' fill="{fill}"' if fill else ""
    return f'<rect x="{x:.2f}" y="{y:.2f}" width="{s:.2f}" height="{s:.2f}"{f}/>'


def symbol_body(cs, full_fill, part_fill, full_cov=0.97):
    lines = []
    for x, y, s, cov in cs:
        lines.append(rect(x, y, s, full_fill if cov >= full_cov else part_fill))
    return "\n".join(lines)


def wrap(body, title, vb="0 0 256 256", extra=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}" role="img" '
            f'aria-label="{title}"{extra}>\n<title>{title}</title>\n{body}\n</svg>\n')


def write(name, text):
    with open(os.path.join(OUT, name), "w") as f:
        f.write(text)
    print("wrote", name)


# --------------------------------------------------------------- wordmark
def wordmark_path(text, target_width, baseline_y, cx, tracking=0.02):
    font = TTFont(FONT)
    gs, cmap, upm = font.getGlyphSet(), font.getBestCmap(), font["head"].unitsPerEm
    adv = [gs[cmap[ord(c)]].width for c in text]
    total = sum(adv) + tracking * upm * (len(text) - 1)
    s = target_width / total
    x = cx - target_width / 2
    ds = []
    for c, a in zip(text, adv):
        pen = SVGPathPen(gs, ntos=lambda v: f"{v:.2f}")
        gs[cmap[ord(c)]].draw(TransformPen(pen, (s, 0, 0, -s, x, baseline_y)))
        ds.append(pen.getCommands())
        x += a * s + tracking * upm * s
    cap = font["OS/2"].sCapHeight * s
    xh = font["OS/2"].sxHeight * s
    return " ".join(ds), xh, cap


# ------------------------------------------------------------------ hex
def hexagon(cx, cy, R):
    """Pointy-top regular hexagon path."""
    pts = [(cx + R * math.cos(math.radians(60 * k - 90)),
            cy + R * math.sin(math.radians(60 * k - 90))) for k in range(6)]
    return "M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in pts) + " Z"


def sticker(mono=False):
    W, H = 520.0, 600.0
    cx, cy = W / 2, H / 2
    Ro, Ri = 298.0, 281.0
    if mono:
        body = [f'<path fill="#000" fill-rule="evenodd" d="{hexagon(cx, cy, Ro)} {hexagon(cx, cy, Ri)}"/>']
        full, part, word = "#000", "#000", "#000"
    else:
        body = [f'<path fill="{AMBER}" d="{hexagon(cx, cy, Ro)}"/>',
                f'<path fill="{TEAL}" d="{hexagon(cx, cy, Ri)}"/>']
        full, part, word = WHITE, AMBER, WHITE
    # symbol, scaled into the upper part of the hex
    size = 280.0
    k = size / 256.0
    tx, ty = cx - size / 2, 100.0
    body.append(f'<g transform="translate({tx:.2f} {ty:.2f}) scale({k:.4f})">\n'
                f'{symbol_body(MAIN, full, part)}\n</g>')
    d, xh, cap = wordmark_path("svyexpo", 292.0, 478.0, cx)
    body.append(f'<path fill="{word}" d="{d}"/>')
    return wrap("\n".join(body), "svyexpo hex sticker", vb=f"0 0 {W:.0f} {H:.0f}")


def lockup(fill_full, fill_part, word_fill):
    """Horizontal: symbol left, outlined wordmark right. viewBox height 256."""
    d, xh, cap = wordmark_path("svyexpo", 520.0, 0, 0)
    # place wordmark with its x-height centred on the symbol's centre line
    off_x, off_y = 256 + 36 + 260, CY + xh / 2
    body = (f'<g>\n{symbol_body(MAIN, fill_full, fill_part)}\n</g>\n'
            f'<g transform="translate({off_x:.2f} {off_y:.2f})"><path fill="{word_fill}" d="{d}"/></g>')
    return wrap(body, "svyexpo logo", vb="0 0 840 256")


if __name__ == "__main__":
    write("symbol-black.svg", wrap(f'<g fill="#000">\n{symbol_body(MAIN, "#000", "#000")}\n</g>',
                                   "svyexpo symbol"))
    write("symbol-white.svg", wrap(symbol_body(MAIN, WHITE, WHITE), "svyexpo symbol"))
    write("symbol-colour.svg", wrap(symbol_body(MAIN, TEAL, AMBER_DK), "svyexpo symbol"))
    write("symbol-colour-on-dark.svg", wrap(symbol_body(MAIN, WHITE, AMBER), "svyexpo symbol"))
    write("symbol-small.svg", wrap(symbol_body(SMALL, "#000", "#000"), "svyexpo symbol, small-size cut"))
    write("sticker.svg", sticker())
    write("sticker-mono.svg", sticker(mono=True))
    write("lockup-colour.svg", lockup(TEAL, AMBER_DK, TEAL))
    write("lockup-black.svg", lockup("#000", "#000", "#000"))
    write("lockup-white.svg", lockup(WHITE, WHITE, WHITE))
