#!/usr/bin/env python3
"""Ключи командной строки движка в готовый APK — без пересборки (#1393, проба «QA на эмуляторе» в Compatibility).

Godot на Android читает ключи из `assets/_cl_` (пишет экспорт из `command_line/extra_args`; формат — u32 число
строк, затем у каждой u32 длина и байты UTF-8, little-endian; `CommandLineFileParser.kt`). Ключи из intent
движок берёт только у неэкспортированной активности — из `adb shell am start` их не передать. Поэтому CI
дописывает ключи в копию `DeepDive-emulator.apk` и переподписывает её отладочным ключом; пресет экспорта не
меняется — эмулятор тестера на компьютере владельца остаётся на Vulkan.

  python3 tools/apk_args.py <вход.apk> <выход.apk> --rendering-method gl_compatibility

Выход не выровнен и не подписан: дальше `zipalign -p -f 4` и `apksigner sign` (так делает qa-emulator.yml).
Старая подпись v1 (META-INF/*.SF, *.RSA, MANIFEST.MF) выбрасывается — apksigner ставит новую.
"""
import struct
import sys
import zipfile

CL = "assets/_cl_"


def parse(data):
    """Строки из `_cl_`; битый файл — пустой список (как CommandLineFileParser)."""
    if len(data) < 4:
        return []
    n = struct.unpack_from("<I", data, 0)[0]
    out, at = [], 4
    for _ in range(n):
        if at + 4 > len(data):
            return []
        ln = struct.unpack_from("<I", data, at)[0]
        at += 4
        if at + ln > len(data):
            return []
        out.append(data[at:at + ln].decode("utf-8"))
        at += ln
    return out


def encode(args):
    out = bytearray(struct.pack("<I", len(args)))
    for a in args:
        b = a.encode("utf-8")
        out += struct.pack("<I", len(b)) + b
    return bytes(out)


def is_v1_signature(name):
    if not name.startswith("META-INF/"):
        return False
    up = name.upper()
    return up == "META-INF/MANIFEST.MF" or up.endswith((".SF", ".RSA", ".DSA", ".EC"))


def patch(src, dst, extra):
    """Копия APK с ключами `extra` впереди прежних в `_cl_`. Возвращает итоговый список ключей."""
    with zipfile.ZipFile(src) as zin:
        names = zin.namelist()
        old = parse(zin.read(CL)) if CL in names else []
        args = list(extra) + [a for a in old if a not in extra]
        with zipfile.ZipFile(dst, "w") as zout:
            for info in zin.infolist():
                if info.filename == CL or is_v1_signature(info.filename):
                    continue
                zout.writestr(info, zin.read(info.filename), compress_type=info.compress_type)
            cl = zipfile.ZipInfo(CL, date_time=(1980, 1, 1, 0, 0, 0))
            cl.compress_type = zipfile.ZIP_STORED  # как у экспорта: без сжатия
            zout.writestr(cl, encode(args))
    return args


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(2)
    got = patch(sys.argv[1], sys.argv[2], sys.argv[3:])
    print("ключи движка:", " ".join(got))
