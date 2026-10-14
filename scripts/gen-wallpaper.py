#!/usr/bin/env python3
"""Génère un fond Catppuccin Mocha discret (dégradé + halos), PNG sans dépendance."""
import math, struct, sys, zlib

W, H = 1920, 1080
BASE, CRUST = (0x1e, 0x1e, 0x2e), (0x11, 0x11, 0x1b)
GLOWS = [  # (cx, cy, rayon, couleur, intensité)
    (0.20, 0.25, 0.55, (0xcb, 0xa6, 0xf7), 0.10),  # mauve
    (0.82, 0.78, 0.60, (0x89, 0xb4, 0xfa), 0.09),  # blue
]

def pixel(x, y):
    t = y / (H - 1)
    r, g, b = (CRUST[i] + (BASE[i] - CRUST[i]) * (1 - t) for i in range(3))
    for cx, cy, rad, col, k in GLOWS:
        d = math.hypot((x / W - cx) * (W / H), y / H - cy) / rad
        a = k * max(0.0, 1 - d) ** 2
        r, g, b = (c + (col[i] - c) * a for i, c in enumerate((r, g, b)))
    return int(r + .5), int(g + .5), int(b + .5)

rows = bytearray()
for y in range(H):
    rows.append(0)
    for x in range(W):
        rows += bytes(pixel(x, y))

def chunk(tag, data):
    c = struct.pack(">I", len(data)) + tag + data
    return c + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)

png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b""))
open(sys.argv[1] if len(sys.argv) > 1 else "mocha.png", "wb").write(png)
