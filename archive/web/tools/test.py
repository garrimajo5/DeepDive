#!/usr/bin/env python3
"""Логические тесты игры: открывает index.html в headless Chromium,
подключает tests/framework.js и все tests/*.test.js, запускает T.run().
Запуск: python3 tools/test.py [фильтр по имени теста]
Код выхода 0 — все тесты прошли."""
import asyncio, functools, glob, http.server, os, socketserver, sys, threading
from playwright.async_api import async_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def serve():
    class Quiet(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *a): pass
    httpd = socketserver.TCPServer(("127.0.0.1", 0), functools.partial(Quiet, directory=ROOT))
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd

async def main(flt):
    httpd = serve(); port = httpd.server_address[1]
    errors = []
    async with async_playwright() as p:
        b = await p.chromium.launch(args=["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"])
        pg = await b.new_page(viewport={"width": 640, "height": 360})
        pg.on("pageerror", lambda e: errors.append(f"pageerror: {e}"))
        await pg.goto(f"http://127.0.0.1:{port}/index.html?test")
        await pg.wait_for_function("window.G && G.Game && G.Game.debug", timeout=90000)
        await pg.evaluate("document.getElementById('b-start').click()")
        await pg.add_script_tag(url=f"http://127.0.0.1:{port}/tests/framework.js")
        for f in sorted(glob.glob(os.path.join(ROOT, "tests", "*.test.js"))):
            await pg.add_script_tag(url=f"http://127.0.0.1:{port}/tests/{os.path.basename(f)}")
        res = await pg.evaluate("f => T.run(f)", flt or None)
        await b.close()
    httpd.shutdown()
    failed = [r for r in res if not r["ok"]]
    for r in res:
        mark = "✓" if r["ok"] else "✗"
        print(f"  {mark} {r['name']} ({r['ms']} мс)" + ("" if r["ok"] else f"\n      {r['err']}"))
    for e in errors: print("  !", e)
    print(f"\nТестов: {len(res)}, прошло: {len(res) - len(failed)}, упало: {len(failed)}")
    return 1 if failed or errors or not res else 0

if __name__ == "__main__":
    sys.exit(asyncio.run(main(sys.argv[1] if len(sys.argv) > 1 else None)))
