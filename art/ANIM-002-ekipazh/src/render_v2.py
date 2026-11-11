from pathlib import Path
H=Path(__file__).resolve().parent
code=(H/'render.py').read_text().replace("ROOT=Path(__file__).resolve().parents[1]","ROOT=Path(__file__).resolve().parents[1]/'v2'")
exec(compile(code,str(H/'render.py'),'exec'))
