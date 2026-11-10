#!/usr/bin/env bash
# Прогон сценария тестера на эмуляторе Android в CI (#1393) — те же шаги, что в tools/qa/run-qa.ps1, на bash.
# Запускает workflow «QA на эмуляторе» (.github/workflows/qa-emulator.yml) внутри android-emulator-runner,
# когда эмулятор уже загружен. Отдельный файл: runner выполняет свой `script:` построчно через sh.
#
#   tools/qa/emulator.sh <apk> <сценарий.json> <папка-выхода> [предел ожидания, с]
#
# В папку: *.png и *.txt из user://qa/out игры, logcat.txt, screencap-*.png (кадры экрана самим adb —
# видно, рисует ли игра, даже если до своих снимков не дошла), itog.txt (одна строка для issue).
set -u
APK="$1"; SCENARIO="$2"; OUT="$3"; LIMIT="${4:-3000}"
# FIRST_SHOT=<с>: нет ни одного снимка игры к этому сроку — остановиться (предел пробы #1393 — 30 мин)
FIRST_SHOT="${FIRST_SHOT:-0}"
APP=com.garrimajo5.deepdive
mkdir -p "$OUT"
log() { echo "$*" | tee -a "$OUT/itog.txt"; }

# Сценарий + шаг «закрыть игру» в конце (как run-qa.ps1)
python3 - "$SCENARIO" "$OUT/scenario.json" <<'EOF'
import json, sys
steps = json.load(open(sys.argv[1], encoding="utf-8"))
steps.append({"do": "quit"})
json.dump(steps, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False)
EOF

adb shell getprop ro.build.version.sdk > "$OUT/device.txt" 2>&1
adb shell wm size >> "$OUT/device.txt" 2>&1
ok=""
for i in 1 2 3; do
  if adb install -r "$APK" > "$OUT/install.txt" 2>&1 && grep -q Success "$OUT/install.txt"; then ok=1; break; fi
  sleep 10
done
if [ -z "$ok" ]; then log "INSTALL_FAILED"; cat "$OUT/install.txt"; exit 1; fi

adb shell am force-stop "$APP"
adb push "$OUT/scenario.json" /data/local/tmp/qa-scenario.json > /dev/null
adb shell "run-as $APP sh -c 'mkdir -p files/qa && rm -rf files/qa/out && cp /data/local/tmp/qa-scenario.json files/qa/scenario.json'"
adb logcat -c
start=$(date +%s)
adb shell monkey -p "$APP" -c android.intent.category.LAUNCHER 1 > /dev/null

done=false
shot=0
next_shot=$((start + 30))
while :; do
  sleep 5
  now=$(date +%s)
  if adb shell "run-as $APP ls files/qa/out/done.txt" 2>&1 | grep -q 'done.txt$'; then done=true; break; fi
  # Кадр экрана раз в 5 минут (первый — через 30 с): рисует ли игра и где застряла
  if [ "$now" -ge "$next_shot" ]; then
    adb exec-out screencap -p > "$OUT/screencap-$(printf %02d $shot).png" 2>/dev/null
    shot=$((shot + 1)); next_shot=$((now + 300))
    n=$(adb shell "run-as $APP ls files/qa/out" 2>/dev/null | grep -c '\.png' || true)
    echo "$((now - start)) с: снимков игры $n"
    if [ "$FIRST_SHOT" -gt 0 ] && [ "$n" -eq 0 ] && [ $((now - start)) -ge "$FIRST_SHOT" ]; then
      log "NO_FIRST_SHOT: нет снимка игры за $FIRST_SHOT с"; break
    fi
  fi
  if ! adb shell pidof "$APP" > /dev/null 2>&1; then echo "процесс игры пропал"; break; fi
  if [ $((now - start)) -ge "$LIMIT" ]; then echo "предел ожидания $LIMIT с"; break; fi
done
took=$(( $(date +%s) - start ))
sleep 2
adb exec-out screencap -p > "$OUT/screencap-end.png" 2>/dev/null
for n in $(adb shell "run-as $APP ls files/qa/out" 2>/dev/null | tr -d '\r' | grep -E '\.(png|txt)$'); do
  adb exec-out run-as "$APP" cat "files/qa/out/$n" > "$OUT/$n"
done
adb logcat -d > "$OUT/logcat.txt"
grep -E ' E godot|SCRIPT ERROR|AndroidRuntime|FATAL|Vulkan|vulkan|OpenGL|Project command line' "$OUT/logcat.txt" | head -60 > "$OUT/errors.txt"
pngs=$(ls "$OUT"/*.png 2>/dev/null | grep -vc screencap || true)
log "done=$done время=${took} с снимков игры=$pngs"
exit 0
