#!/usr/bin/env python3
"""Смоук-тест: поднимает локальный сервер, открывает игру в headless Chromium,
прогоняет симуляцию и проверяет, что нет ошибок JS.
Запуск: python3 tools/smoke.py [--shots DIR] [--steps N]
Код выхода 0 — всё хорошо, 1 — есть ошибки."""
import asyncio, argparse, functools, http.server, os, socketserver, sys, threading
from playwright.async_api import async_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def serve():
    class Quiet(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *a): pass
    h = functools.partial(Quiet, directory=ROOT)
    httpd = socketserver.TCPServer(("127.0.0.1", 0), h)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd

async def main(a):
    httpd = serve(); port = httpd.server_address[1]
    errors = []
    async with async_playwright() as p:
        b = await p.chromium.launch(args=["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"])
        for name, vp in [("desktop", {"width": 1280, "height": 720}), ("phone", {"width": 844, "height": 390})]:
            pg = await b.new_page(viewport=vp, has_touch=(name == "phone"), is_mobile=(name == "phone"))
            pg.on("pageerror", lambda e, n=name: errors.append(f"[{n}] pageerror: {e}"))
            pg.on("console", lambda m, n=name: errors.append(f"[{n}] console.error: {m.text}") if m.type == "error" and "fonts.g" not in m.text and "ERR_TUNNEL" not in m.text and "ERR_NAME" not in m.text else None)
            await pg.goto(f"http://127.0.0.1:{port}/index.html")
            await pg.wait_for_function("window.G && G.Game && G.Game.debug", timeout=60000)
            await pg.evaluate("document.getElementById('b-start').click()")
            await pg.wait_for_timeout(500)
            info = await pg.evaluate(f"""(() => {{
                const ev = {{}}; const em = G.Eco.emit; G.Eco.emit = (s,n,p,m) => {{ ev[s+':'+n]=(ev[s+':'+n]||0)+1; em(s,n,p,m); }};
                G.Game.toggleHelm(); G.Ctl.padMove.y = 1; G.Game.debug.step({a.steps}, 0.05); G.Ctl.padMove.y = 0;
                return {{ events: ev, ship: G.Ship.pos.toArray().map(v => +v.toFixed(1)), hull: Math.round(G.Ship.hull), render: G.Game.debug.info() }};
            }})()""")
            print(name, info)
            if a.shots:
                os.makedirs(a.shots, exist_ok=True)
                await pg.wait_for_timeout(1500)
                await pg.screenshot(path=os.path.join(a.shots, f"{name}.png"))
            await pg.close()  # первая вкладка продолжает рисовать и отнимает процессор у второй
        await b.close()
    httpd.shutdown()
    if errors:
        print("ОШИБКИ:"); [print(" ", e) for e in errors]; return 1
    print("OK"); return 0

if __name__ == "__main__":
    ap = argparse.ArgumentParser(); ap.add_argument("--shots"); ap.add_argument("--steps", type=int, default=1200)
    sys.exit(asyncio.run(main(ap.parse_args())))
