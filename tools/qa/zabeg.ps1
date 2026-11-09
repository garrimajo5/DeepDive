# Хронометраж забегов с телефона (эпик #633): игра пишет ленту и сводку каждого забега в user://zabegi.txt —
# последние 20, новый сверху (`scripts/core/run_timeline.gd`). Скрипт забирает файл с подключённого телефона
# или эмулятора в D:\AI\qa-build\zabegi.txt и печатает. APK отладочный, поэтому run-as работает.
#
#   zabeg.ps1           — забрать и напечатать
#   zabeg.ps1 -Clear    — забрать, затем стереть файл на телефоне (следующий прогон — с чистого листа)
param([switch]$Clear)
$ErrorActionPreference = 'Continue'
$out = 'D:\AI\qa-build'
$app = 'com.garrimajo5.deepdive'
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
$adb = "$sdk\platform-tools\adb.exe"
New-Item -ItemType Directory -Force $out | Out-Null
if (-not ((& $adb devices) -match '\sdevice\b')) { Write-Output 'NO_DEVICE: телефон или эмулятор не подключён (adb devices)'; exit 1 }
if (-not ((& $adb shell "run-as $app ls files/zabegi.txt" 2>&1) -match 'zabegi.txt$')) {
  Write-Output 'NO_FILE: забегов ещё нет — сыграйте забег до итога или до «Корпус разрушен» (или сверните игру посреди забега)'
  exit 1
}
cmd /c "`"$adb`" exec-out run-as $app cat files/zabegi.txt > `"$out\zabegi.txt`""
if ($Clear) { & $adb shell "run-as $app rm files/zabegi.txt" | Out-Null }
Get-Content "$out\zabegi.txt" -Encoding utf8
Write-Output "file: $out\zabegi.txt"
