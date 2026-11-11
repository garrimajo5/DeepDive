from pathlib import Path
H=Path(__file__).resolve().parent
code=(H/'validate_skin.py').read_text().replace('from animate import','from build_v2 import').replace('original_payload_equal','approved_payload_equal')
exec(compile(code,str(H/'validate_skin.py'),'exec'))
