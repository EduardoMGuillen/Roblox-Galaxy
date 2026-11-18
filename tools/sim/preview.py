#!/usr/bin/env python3
"""Vista previa aproximada del mundo construido por codigo (sin Roblox Studio).
Lee tools/sim/data/world_dump.txt (generado por tools/sim/tools/dump_world.lua) y dibuja las piezas
con un rasterizador simple (z-buffer, sombreado plano). No muestra texturas ni texto: sirve para
revisar distribucion, escala y orientacion.

  python3 tools/sim/preview.py salida.png  camX camY camZ  miraX miraY miraZ  [fov] [maxdist]
"""
import math
import sys
import numpy as np
from PIL import Image

W, H = 1280, 720


def load(path):
    parts = []
    for line in open(path):
        t = line.split()
        shape = t[0]
        v = [float(x) for x in t[1:]]
        parts.append(dict(shape=shape, size=np.array(v[0:3]), pos=np.array(v[3:6]),
                          rot=np.array(v[6:15]).reshape(3, 3), color=np.array(v[15:18]),
                          alpha=1 - v[18], neon=v[19] > 0, gui=v[20] > 0))
    return parts


def box_tris(sz):
    x, y, z = sz / 2
    c = np.array([[-x, -y, -z], [x, -y, -z], [x, y, -z], [-x, y, -z], [-x, -y, z], [x, -y, z], [x, y, z], [-x, y, z]])
    faces = [(0, 1, 2, 3, 'front'), (5, 4, 7, 6, 'back'), (4, 0, 3, 7, 'l'), (1, 5, 6, 2, 'r'), (3, 2, 6, 7, 't'), (4, 5, 1, 0, 'b')]
    tris, tags = [], []
    for a, b, cc, d, tag in faces:
        tris += [[c[a], c[b], c[cc]], [c[a], c[cc], c[d]]]
        tags += [tag, tag]
    return np.array(tris), tags


def cyl_tris(sz, n=20):
    h, r = sz[0] / 2, sz[1] / 2
    tris = []
    for i in range(n):
        a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
        p0 = (r * math.cos(a0), r * math.sin(a0))
        p1 = (r * math.cos(a1), r * math.sin(a1))
        tris += [[[-h, p0[0], p0[1]], [h, p0[0], p0[1]], [h, p1[0], p1[1]]],
                 [[-h, p0[0], p0[1]], [h, p1[0], p1[1]], [-h, p1[0], p1[1]]],
                 [[h, 0, 0], [h, p1[0], p1[1]], [h, p0[0], p0[1]]],
                 [[-h, 0, 0], [-h, p0[0], p0[1]], [-h, p1[0], p1[1]]]]
    return np.array(tris), ['s'] * len(tris)


def ball_tris(sz, n=10, m=14):
    r = sz[0] / 2
    tris = []
    for i in range(n):
        t0, t1 = math.pi * i / n, math.pi * (i + 1) / n
        for j in range(m):
            p0, p1 = 2 * math.pi * j / m, 2 * math.pi * (j + 1) / m
            def pt(t, p):
                return [r * math.sin(t) * math.cos(p), r * math.cos(t), r * math.sin(t) * math.sin(p)]
            a, b, c, d = pt(t0, p0), pt(t0, p1), pt(t1, p1), pt(t1, p0)
            tris += [[a, b, c], [a, c, d]]
    return np.array(tris), ['s'] * len(tris)


def render(parts, eye, target, fov=70, maxdist=3000, out="preview.png"):
    eye, target = np.array(eye, float), np.array(target, float)
    fwd = target - eye
    fwd /= np.linalg.norm(fwd)
    right = np.cross(fwd, [0, 1, 0])
    right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    f = (H / 2) / math.tan(math.radians(fov) / 2)
    color = np.zeros((H, W, 3))
    color[:] = [0.02, 0.025, 0.06]
    depth = np.full((H, W), np.inf)
    light = np.array([0.4, 0.8, 0.45])
    light /= np.linalg.norm(light)
    opaque, translucent = [], []
    for p in parts:
        if p['alpha'] < 0.06:
            continue
        d = np.linalg.norm(p['pos'] - eye)
        if d - np.linalg.norm(p['size']) > maxdist:
            continue
        (translucent if p['alpha'] < 0.75 else opaque).append((d, p))
    translucent.sort(key=lambda x: -x[0])
    for group, blend in ((opaque, False), (translucent, True)):
        for _, p in group:
            if p['shape'] == 'Ball':
                tris, tags = ball_tris(p['size'])
            elif p['shape'] == 'Cylinder':
                tris, tags = cyl_tris(p['size'])
            else:
                tris, tags = box_tris(p['size'])
            world = tris @ p['rot'].T + p['pos']
            rel = world - eye
            cx, cy, cz = rel @ right, rel @ up, rel @ fwd
            for k in range(len(tris)):
                z = cz[k]
                if z.min() < 0.5:
                    continue
                sx = W / 2 + cx[k] / z * f
                sy = H / 2 - cy[k] / z * f
                minx, maxx = int(max(0, math.floor(sx.min()))), int(min(W - 1, math.ceil(sx.max())))
                miny, maxy = int(max(0, math.floor(sy.min()))), int(min(H - 1, math.ceil(sy.max())))
                if minx > maxx or miny > maxy:
                    continue
                nrm = np.cross(world[k][1] - world[k][0], world[k][2] - world[k][0])
                ln = np.linalg.norm(nrm)
                if ln == 0:
                    continue
                nrm /= ln
                base = p['color']
                if p['gui'] and tags[k] == 'front':
                    base = np.array([1.0, 0.2, 0.8])
                if p['neon']:
                    col = np.minimum(1, base * 1.25 + 0.1)
                else:
                    col = base * (0.35 + 0.65 * abs(float(nrm @ light)))
                xs = np.arange(minx, maxx + 1) + 0.5
                ys = np.arange(miny, maxy + 1) + 0.5
                gx, gy = np.meshgrid(xs, ys)
                x0, y0, x1, y1, x2, y2 = sx[0], sy[0], sx[1], sy[1], sx[2], sy[2]
                den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
                if abs(den) < 1e-9:
                    continue
                w0 = ((y1 - y2) * (gx - x2) + (x2 - x1) * (gy - y2)) / den
                w1 = ((y2 - y0) * (gx - x2) + (x0 - x2) * (gy - y2)) / den
                w2 = 1 - w0 - w1
                inside = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
                if not inside.any():
                    continue
                zz = 1 / (w0 / z[0] + w1 / z[1] + w2 / z[2])
                sub_d = depth[miny:maxy + 1, minx:maxx + 1]
                sub_c = color[miny:maxy + 1, minx:maxx + 1]
                mask = inside & (zz < sub_d)
                if blend:
                    a = p['alpha']
                    sub_c[mask] = sub_c[mask] * (1 - a) + col * a
                else:
                    sub_c[mask] = col
                    sub_d[mask] = zz[mask]
    Image.fromarray((np.clip(color, 0, 1) * 255).astype(np.uint8)).save(out)
    print("guardado", out)


if __name__ == "__main__":
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    a = sys.argv[1:]
    out = a[0]
    eye = [float(x) for x in a[1:4]]
    tgt = [float(x) for x in a[4:7]]
    fov = float(a[7]) if len(a) > 7 else 70
    md = float(a[8]) if len(a) > 8 else 3000
    render(load(os.path.join(here, "data", "world_dump.txt")), eye, tgt, fov, md, out)
