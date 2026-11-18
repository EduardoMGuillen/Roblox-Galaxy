#!/usr/bin/env python3
"""Vista previa aproximada de la interfaz (sin Roblox Studio).
Lee tools/sim/data/ui_dump.json (tools/sim/tools/dump_ui.lua) y dibuja cada captura con PIL,
aplicando el layout de Roblox de forma simplificada (UDim2, AnchorPoint, UIListLayout, UIGridLayout,
UIPadding y UIScale en la ScreenGui). Sirve para detectar solapamientos, recortes y elementos fuera
de pantalla; no reproduce fuentes, emoji ni efectos.

  python3 tools/sim/preview_ui.py carpeta_salida [ancho alto]
"""
import json
import os
import sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONT_PATHS = ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"]
_fonts = {}


def font(size):
    size = max(6, int(size))
    if size not in _fonts:
        f = None
        for p in FONT_PATHS:
            if os.path.exists(p):
                f = ImageFont.truetype(p, size)
                break
        _fonts[size] = f or ImageFont.load_default()
    return _fonts[size]


def clean(text):
    # los emoji no existen en la fuente de vista previa: se sustituyen por un marcador
    return "".join(ch if ord(ch) < 0x2190 else "□" for ch in text)


class Ctx:
    def __init__(self, img, scale):
        self.img = img
        self.draw = ImageDraw.Draw(img, "RGBA")
        self.scale = scale
        self.items = []


def layout(node, px, py, pw, ph, ctx, clip, z_base, visible=True):
    """Calcula el rectangulo absoluto (en unidades sin escalar) y acumula elementos a dibujar."""
    if not visible or node.get("visible") is False:
        return None
    sx, so, sy, so2 = node["size"]
    w, h = sx * pw + so, sy * ph + so2
    x = px + node["pos"][0] * pw + node["pos"][1] - node["anchor"][0] * w
    y = py + node["pos"][2] * ph + node["pos"][3] - node["anchor"][1] * h
    return x, y, w, h


def walk(node, rect, ctx, clip, depth):
    x, y, w, h = rect
    kids = node.get("children") or []
    corner = next((k["radius"] for k in kids if k["class"] == "UICorner"), 0)
    stroke = next((k for k in kids if k["class"] == "UIStroke" and k.get("border", True)), None)
    grad = next((k for k in kids if k["class"] == "UIGradient"), None)
    pad = next((k["pad"] for k in kids if k["class"] == "UIPadding"), [0, 0, 0, 0])
    ctx.items.append((depth, node, (x, y, w, h), clip, corner, stroke, grad))
    inner = (x + pad[0], y + pad[1], w - pad[0] - pad[2], h - pad[1] - pad[3])
    child_clip = clip
    if node.get("clip"):
        child_clip = intersect(clip, (x, y, x + w, y + h))
    gui_kids = [k for k in kids if "size" in k and k.get("visible") is not False]
    lst = next((k for k in kids if k["class"] == "UIListLayout"), None)
    grid = next((k for k in kids if k["class"] == "UIGridLayout"), None)
    if lst or grid:
        gui_kids.sort(key=lambda k: k.get("order", 0))
    if lst:
        horizontal = lst["dir"] == "Horizontal"
        sizes = []
        for k in gui_kids:
            kw = k["size"][0] * inner[2] + k["size"][1]
            kh = k["size"][2] * inner[3] + k["size"][3]
            sizes.append((kw, kh))
        total = sum(s[0] if horizontal else s[1] for s in sizes) + lst["padding"] * max(0, len(sizes) - 1)
        cur = 0
        if horizontal:
            if lst["ha"] == "Center":
                cur = (inner[2] - total) / 2
            elif lst["ha"] == "Right":
                cur = inner[2] - total
        else:
            if lst["va"] == "Center":
                cur = (inner[3] - total) / 2
            elif lst["va"] == "Bottom":
                cur = inner[3] - total
        for k, (kw, kh) in zip(gui_kids, sizes):
            if horizontal:
                ky = inner[1] + ((inner[3] - kh) / 2 if lst["va"] == "Center" else 0)
                walk(k, (inner[0] + cur, ky, kw, kh), ctx, child_clip, depth + 1)
                cur += kw + lst["padding"]
            else:
                kx = inner[0] + ((inner[2] - kw) / 2 if lst["ha"] == "Center" else 0)
                walk(k, (kx, inner[1] + cur, kw, kh), ctx, child_clip, depth + 1)
                cur += kh + lst["padding"]
    elif grid:
        cw = grid["cell"][0] * inner[2] + grid["cell"][1]
        ch = grid["cell"][2] * inner[3] + grid["cell"][3]
        gx, gy = grid["cellPad"][1], grid["cellPad"][3]
        cols = max(1, int((inner[2] + gx) // (cw + gx)))
        for i, k in enumerate(gui_kids):
            r, c = divmod(i, cols)
            walk(k, (inner[0] + c * (cw + gx), inner[1] + r * (ch + gy), cw, ch), ctx, child_clip, depth + 1)
    else:
        for k in gui_kids:
            r = layout(k, inner[0], inner[1], inner[2], inner[3], ctx, child_clip, depth)
            if r:
                walk(k, r, ctx, child_clip, depth + 1)


def intersect(a, b):
    if a is None:
        return b
    return (max(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), min(a[3], b[3]))


def paint(ctx, item, origin_y):
    depth, node, (x, y, w, h), clip, corner, stroke, grad = item
    s = ctx.scale
    X0, Y0, X1, Y1 = x * s, y * s + origin_y, (x + w) * s, (y + h) * s + origin_y
    if X1 <= X0 or Y1 <= Y0:
        return
    if clip is not None:
        cx0, cy0, cx1, cy1 = clip[0] * s, clip[1] * s + origin_y, clip[2] * s, clip[3] * s + origin_y
        if X1 < cx0 or X0 > cx1 or Y1 < cy0 or Y0 > cy1:
            return
        if Y0 < cy0 - 2 or Y1 > cy1 + 2:  # recortado por un ScrollingFrame: se omite lo que queda fuera
            if Y0 > cy1 or Y1 < cy0:
                return
            Y0, Y1 = max(Y0, cy0), min(Y1, cy1)
            if Y1 - Y0 < 4:
                return
    d = ctx.draw
    alpha = int(255 * (1 - node.get("bgT", 1)))
    if alpha > 0:
        col = node["bg"]
        if grad:
            col = [int((grad["g0"][i] + grad["g1"][i]) / 2 * node["bg"][i] / 255) for i in range(3)]
        d.rounded_rectangle([X0, Y0, X1, Y1], radius=min(corner * s, (X1 - X0) / 2, (Y1 - Y0) / 2), fill=(col[0], col[1], col[2], alpha))
    if stroke and stroke.get("strokeT", 0) < 0.95:
        c = stroke["strokeColor"]
        d.rounded_rectangle([X0, Y0, X1, Y1], radius=min(corner * s, (X1 - X0) / 2, (Y1 - Y0) / 2),
                            outline=(c[0], c[1], c[2], int(255 * (1 - stroke.get("strokeT", 0)))), width=max(1, int(stroke["thickness"] * s)))
    if node.get("viewport"):
        r = min(X1 - X0, Y1 - Y0) * 0.36
        cx, cy = (X0 + X1) / 2, (Y0 + Y1) / 2
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(90, 130, 220, 255), outline=(190, 220, 255, 255))
    text = node.get("text")
    if text and node.get("textT", 0) < 0.95:
        text = clean(text)
        size = node["textSize"] * s
        if node.get("scaled"):
            size = min((Y1 - Y0) * 0.6, 60)
        f = font(size)
        lines = []
        for raw in text.split("\n"):
            if node.get("wrap"):
                words, cur = raw.split(" "), ""
                for wd in words:
                    t = (cur + " " + wd).strip()
                    if d.textlength(t, font=f) <= (X1 - X0) or not cur:
                        cur = t
                    else:
                        lines.append(cur)
                        cur = wd
                lines.append(cur)
            else:
                lines.append(raw)
        lh = size * 1.18
        total = lh * len(lines)
        ay = node.get("ay", "Center")
        ty = Y0 if ay == "Top" else (Y1 - total if ay == "Bottom" else (Y0 + Y1 - total) / 2)
        col = tuple(node["textColor"]) + (255,)
        overflow = False
        for ln in lines:
            tw = d.textlength(ln, font=f)
            if tw > (X1 - X0) + 2:
                overflow = True
            ax = node.get("ax", "Center")
            tx = X0 if ax == "Left" else (X1 - tw if ax == "Right" else (X0 + X1 - tw) / 2)
            d.text((tx, ty), ln, font=f, fill=col)
            ty += lh
        if overflow or total > (Y1 - Y0) + 4:
            # marca roja: el texto no cabe en su caja (en Roblox se truncaria o se saldria)
            d.rectangle([X0, Y0, X1, Y1], outline=(255, 0, 0, 255), width=1)


def render(shot, W, H, out):
    img = Image.new("RGB", (W, H), (14, 18, 40))
    ctx = Ctx(img, 1)
    ImageDraw.Draw(img).rectangle([0, 0, W, 58], fill=(8, 10, 22))
    screens = sorted(shot["screens"], key=lambda s: s.get("displayOrder", 0))
    for sg in screens:
        if not sg.get("enabled", True):
            continue
        kids = sg.get("children") or []
        scale = next((k["scale"] for k in kids if k["class"] == "UIScale"), 1)
        # marco raiz con UIScale (patron usado por UIController): sus hijos se dibujan escalados
        root = next((k for k in kids if k.get("name") == "Root" and any(c["class"] == "UIScale" for c in (k.get("children") or []))), None)
        if root:
            scale = next(c["scale"] for c in root["children"] if c["class"] == "UIScale")
            kids = root.get("children") or []

        inset = 58 if sg.get("inset") else 0
        ctx.scale = scale
        ctx.items = []
        aw, ah = W / scale, (H - inset) / scale
        for k in kids:
            if "size" in k:
                r = layout(k, 0, 0, aw, ah, ctx, None, 0)
                if r:
                    walk(k, r, ctx, None, 0)
        for item in ctx.items:
            paint(ctx, item, inset)
    img.save(out)


def main():
    outdir = sys.argv[1]
    W = int(sys.argv[2]) if len(sys.argv) > 2 else 1920
    H = int(sys.argv[3]) if len(sys.argv) > 3 else 1080
    os.makedirs(outdir, exist_ok=True)
    shots = json.load(open(os.path.join(HERE, "data", "ui_dump.json"), encoding="utf-8"))
    for shot in shots:
        render(shot, W, H, os.path.join(outdir, "%s_%dx%d.png" % (shot["name"], W, H)))
    print(len(shots), "capturas en", outdir)


if __name__ == "__main__":
    main()
