import json, sys, math
from PIL import Image, ImageDraw, ImageFont

d = json.load(open(sys.argv[1]))
out = sys.argv[2]
X0, X1, Z0, Z1 = -150.0, 170.0, -170.0, 150.0
K = 2.4
W, H = int((X1 - X0) * K), int((Z1 - Z0) * K) + 120
img = Image.new("RGB", (W, H), (14, 22, 32))
dr = ImageDraw.Draw(img, "RGBA")
f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
fb = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 16)


def P(x, z):
    return ((x - X0) * K, (z - Z0) * K)


# сетка 50 м
for x in range(-150, 171, 50):
    dr.line([P(x, Z0), P(x, Z1)], fill=(40, 55, 70), width=1)
    dr.text((P(x, Z1)[0] + 2, P(x, Z1)[1] - 18), f"x {x}", font=f, fill=(90, 110, 130))
for z in range(-150, 151, 50):
    dr.line([P(X0, z), P(X1, z)], fill=(40, 55, 70), width=1)
    dr.text((P(X0, z)[0] + 2, P(X0, z)[1] + 1), f"z {z}", font=f, fill=(90, 110, 130))

# тепловая карта патруля
C = 5.0
grid = {}
n = 0
for tr in d["patrol"]:
    for x, z, i, m in tr:
        k = (int(math.floor(x / C)), int(math.floor(z / C)))
        grid[k] = grid.get(k, 0) + 1
        n += 1
mx = max(grid.values())
for (gx, gz), c in grid.items():
    a = min(1.0, (c / mx) ** 0.5)
    x0, z0 = P(gx * C, gz * C)
    x1, z1 = P(gx * C + C, gz * C + C)
    dr.rectangle([x0, z0, x1, z1], fill=(230, 120, 40, int(40 + 190 * a)))


def circle(x, z, r, col, w=2, dash=False):
    cx, cz = P(x, z)
    rr = r * K
    if not dash:
        dr.ellipse([cx - rr, cz - rr, cx + rr, cz + rr], outline=col, width=w)
    else:
        for i in range(0, 360, 12):
            a0, a1 = math.radians(i), math.radians(i + 6)
            dr.arc([cx - rr, cz - rr, cx + rr, cz + rr], i, i + 6, fill=col, width=w)


# риф
rx, rz = d["reef"]
circle(rx, rz, 32, (120, 220, 255), 3)
circle(rx, rz, 42, (120, 220, 255), 1, True)
# места
for name, (x, z) in {"00 старт": (0, 95), "01 цветок": (40, -50)}.items():
    cx, cz = P(x, z)
    dr.ellipse([cx - 7, cz - 7, cx + 7, cz + 7], fill=(255, 255, 255))
    dr.text((cx + 10, cz - 8), name, font=fb, fill=(255, 255, 255))
# маршрут
route = [(0, 95)] + [tuple(s) for s in d["scena"]] + [(40, -50)]
dr.line([P(*p) for p in route], fill=(90, 255, 140), width=4)
for i, (x, z) in enumerate(d["scena"]):
    cx, cz = P(x, z)
    dr.ellipse([cx - 5, cz - 5, cx + 5, cz + 5], fill=(90, 255, 140))
    dr.text((cx - 70, cz - 8), f"scena={i+1}", font=f, fill=(150, 255, 180))
# радиусы у стоянки (scena=2)
sx, sz = d["scena"][1]
circle(sx, sz, 32, (255, 255, 120), 2)
circle(sx, sz, 24, (255, 255, 120), 1, True)
circle(sx, sz, 150, (255, 255, 120, 110), 1, True)
cx, cz = P(sx + 22.6, sz - 22.6)
dr.text((cx + 4, cz - 18), "32 м свет/сонар", font=f, fill=(255, 255, 140))
# места появления
for x, z in d["starts"]:
    cx, cz = P(x, z)
    dr.polygon([(cx, cz - 9), (cx - 8, cz + 6), (cx + 8, cz + 6)], fill=(255, 70, 70))
# броски на проходе
for r in d["routes"]:
    for e in r["events"]:
        kind, t, i, px, pz, shx, shz = e
        if kind == "charge":
            dr.line([P(px, pz), P(shx, shz)], fill=(255, 60, 60, 200), width=2)
            cx, cz = P(px, pz)
            dr.line([cx - 5, cz - 5, cx + 5, cz + 5], fill=(255, 60, 60), width=3)
            dr.line([cx - 5, cz + 5, cx + 5, cz - 5], fill=(255, 60, 60), width=3)
        else:
            cx, cz = P(shx, shz)
            dr.ellipse([cx - 6, cz - 6, cx + 6, cz + 6], outline=(255, 0, 0), width=3)

y = H - 112
leg = [
    ((230, 120, 40), "где бывают серпохвосты (патруль, корабль далеко)"),
    ((255, 70, 70), "▲ места появления EcoPred.STARTS;  ✕— начало броска → корабль;  ○ укус"),
    ((90, 255, 140), "штатный проход 00 → 01, 5 м/с, свет, стоянка 25 с у scena=2"),
    ((255, 255, 120), "у стоянки: 32 м — видит свет/сонар, пунктир 24 м — слышит ход >3 м/с, 150 м — зов сонара"),
    ((120, 220, 255), "риф 01: кольцо 32 м — хищник не заходит, корабль там не атакует; пунктир 42 м — край"),
]
for col, t in leg:
    dr.rectangle([10, y + 4, 24, y + 16], fill=col)
    dr.text((32, y), t, font=f, fill=(230, 230, 230))
    y += 21
dr.text((W - 120, 6), "↑ −Z (нос)", font=f, fill=(200, 200, 200))
img.save(out)
