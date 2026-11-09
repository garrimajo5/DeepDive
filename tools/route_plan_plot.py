# Картинки к tools/route_plan.gd (#1374): план слоя с маршрутом и профили отрезков.
#   python3 tools/route_plan_plot.py <route.json> <папка>  →  plan.png, profili.png
import json, sys
import numpy as np, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
d = json.load(open(sys.argv[1])); outdir = sys.argv[2]
x0, z0, st, nx, nz, h = d["grid"]
H = np.array([np.nan if v is None else -v for v in h], float).reshape(nz, nx)
fig, ax = plt.subplots(figsize=(14, 8.5), dpi=110)
ext = [x0 - st/2, x0 + (nx-1)*st + st/2, z0 + (nz-1)*st + st/2, z0 - st/2]
im = ax.imshow(H, extent=ext, cmap="viridis_r", vmin=20, vmax=310, origin="upper")
cs = ax.contour(np.arange(nx)*st + x0, np.arange(nz)*st + z0, H, levels=[40, 50, 60, 80, 120, 200, 280], colors="w", linewidths=0.4, alpha=0.6)
ax.clabel(cs, fontsize=7, fmt="%d м")
plt.colorbar(im, ax=ax, label="глубина дна, м", shrink=0.8)
for leg in d["legs"]:
    S = leg["stations"]; xs = [s["x"] for s in S]; zs = [s["z"] for s in S]
    ax.plot(xs, zs, "--" if leg.get("detour") else "-", color="#ffd34d" if leg.get("detour") else "w", lw=2.2)
    for s in S:
        if s["wall"]:
            ax.plot(s["x"], s["z"], "X", color="k", ms=8, mec="w", mew=0.6); continue
        if s["arch"]:
            ax.plot(s["x"], s["z"], "^", color="#c04dff", ms=8, mec="w", mew=0.6); continue
        elif s["dig7"] > 5: c = "#e01b1b"
        elif s["dig7"] > 0.5: c = "#ff8c1a"
        else: continue
        ax.plot(s["x"], s["z"], "o", color=c, ms=6, mec="k", mew=0.4)
    for f in leg["flora"]:
        if not f["end"]:
            ax.plot(f["x"], f["z"], ".", color="#00e5ff", ms=3)
for rid, x, z, depth, g in d["route"]:
    ax.plot(x, z, "s", color="k", ms=8, mec="w")
    ax.annotate(f"{rid}\n{depth:.0f} м", (x, z), textcoords="offset points", xytext=(8, 6), color="w", fontsize=10, weight="bold")
from matplotlib.lines import Line2D
L = [Line2D([], [], color="w", lw=2, label="прямая между местами"), Line2D([], [], color="#ffd34d", ls="--", lw=2, label="сравнение: через проход склона"),
     Line2D([], [], marker="X", ls="", color="k", mec="w", label="стена за краем отмели — не пройти"),
     Line2D([], [], marker="^", ls="", color="#c04dff", mec="w", label="корпус в опорах арки 07"),
     Line2D([], [], marker="o", ls="", color="#e01b1b", label="корпус в грунте на 7 м над дном: > 5 м"),
     Line2D([], [], marker="o", ls="", color="#ff8c1a", label="то же: 0,5–5 м"),
     Line2D([], [], marker=".", ls="", color="#00e5ff", label="высокая флора в объёме 60×30 (не у места)")]
ax.legend(handles=L, loc="lower left", fontsize=8, facecolor="#222", labelcolor="w")
ax.set_xlabel("x, м (восток →)"); ax.set_ylabel("z, м (юг ↓, нос корабля в −Z)")
ax.set_title(("Полный обход" if d.get("full") else "Основной маршрут") + " слоя 1 — план (облачный расчёт tools/route_plan.gd, не телефон)")
ax.set_facecolor("#333"); fig.tight_layout(); fig.savefig(f"{outdir}/plan.png")
legs = [l for l in d["legs"]]
fig, axs = plt.subplots(len(legs), 1, figsize=(12, 2.6*len(legs)), dpi=100)
for a, leg in zip(axs, legs):
    S = leg["stations"]; s = [q["s"] for q in S]
    gc = [-q["gc"] for q in S]; foot = [-q["foot"] for q in S]
    a.fill_between(s, gc, 320, color="#6b5a45", alpha=0.8, label="дно по оси")
    a.plot(s, foot, color="#c0392b", lw=1, label="выше всего под корпусом")
    ride = [-(q["gc"] + 7) for q in S]
    a.plot(s, ride, color="#2e86de", lw=1.4, label="ход на 7 м над дном")
    need = [-(q["gc"] + q["need"]) for q in S]
    a.plot(s, need, color="#2e86de", ls=":", lw=1.2, label="ход, чтобы корпус не входил в грунт")
    for q in S:
        if q["wall"]: a.axvspan(q["s"]-2.5, q["s"]+2.5, color="r", alpha=0.25, lw=0)
        if q["arch"]: a.axvspan(q["s"]-2.5, q["s"]+2.5, color="#c04dff", alpha=0.25, lw=0)
    a.axhline(5, color="#9ad9e8", lw=1); a.text(0, 4, "предел хода подо льдом", fontsize=7, color="#3a8fa0", va="bottom")
    lo = max(gc) + 10; hi = min(min(need), 0)
    a.set_ylim(lo, max(hi - 5, 0)); a.set_xlim(0, leg["length"])
    a.set_title(f'{leg["from"]} → {leg["to"]}, {leg["length"]:.0f} м' + (" (сравнение)" if leg.get("detour") else "") + (" (транзит)" if leg.get("transit") else ""), fontsize=10, loc="left")
    a.set_ylabel("глубина, м")
axs[0].legend(fontsize=7, loc="lower right", ncol=4); axs[-1].set_xlabel("м от начала отрезка")
fig.tight_layout(); fig.savefig(f"{outdir}/profili.png")
