# Прогон сценария тестера (tools/qa/scenario.json): игра сама проходит шаги, снимает скриншоты и пишет лог.
# Результат — в D:\AI\qa-build\run\ (скриншоты *.png, log.txt, logcat.txt), итог печатается в конце.
# Отчёт по результату пишет Claude по docs/QA.md. Перед запуском обнови клон: git -C D:\AI\DeepDive pull.
#
#   run-qa.ps1          — APK из релиза apk-latest на эмуляторе Pixel_8 (ровно то, что собрал CI из main)
#   run-qa.ps1 -Pc      — та же игра из клона в Godot на этом компьютере (D:\Godot), без эмулятора: быстро
#                         проверить сценарий и картинку; телефонное (касания, частоту кадров) смотреть на эмуляторе
#   -Pr <номер>         — проверить фикс из открытой PR ДО слияния: берёт APK из артефакта deepdive-apk
#                         последнего прогона CI этой PR (нужен gh), ставит на эмулятор и гоняет сценарий
#   -Force              — прогнать APK, даже если коммит тот же; -Scenario <файл> — свой сценарий
#                         (с -Pr — путь в ветке PR, напр. tools/qa/scenario.json; без -Scenario с -Pr — сценарий ветки PR)
#   -ColdBoot           — перед прогоном закрыть эмулятор (adb emu kill) и запустить заново без снимка состояния:
#                         после чужих окон поверх игры, «помех» или растущих заминок от прогона к прогону
#   -Phone              — только скачать DeepDive.apk (arm64, телефон) из apk-latest со сверкой длины
#                         в D:\AI\qa-build\DeepDive.apk и выйти; на телефон ставить вручную
#   Эмулятор после прогона не закрывается (запущен отдельно от скрипта): ручная проверка — adb, закрыть — adb emu kill
param([switch]$Pc, [switch]$Force, [string]$Scenario, [int]$Pr, [switch]$Phone, [switch]$ColdBoot)
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'   # полоса прогресса в PS 5.1 тормозит скачивание в разы

# Скачать файл релиза и сверить длину с размером в релизе ($size). Invoke-WebRequest может молча оборвать
# поток: APK эмулятора приходил ровно 110 МиБ из 114 и не ставился (INSTALL_PARSE_FAILED_NOT_APK, #1504).
# Обрыв — докачка с места обрыва (curl.exe -C -, есть в Windows 10+), иначе заново; до 3 попыток.
# Возвращает '' при успехе или текст ошибки (попытки — в Write-Host, чтобы не смешаться с ответом).
function Get-Asset([string]$url, [string]$path, [long]$size) {
  $why = ''; $err = ''
  $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
  for ($try = 1; $try -le 3; $try++) {
    $have = if (Test-Path $path) { (Get-Item $path).Length } else { 0 }
    if ($have -gt $size) { Remove-Item $path -Force; $have = 0 }
    try {
      if ($curl -and $have -gt 0) {
        & $curl.Source -sSL -C - -A 'run-qa' -o $path $url
      } else {
        Invoke-WebRequest $url -OutFile $path -Headers @{ 'User-Agent' = 'run-qa' } -ErrorAction Stop
      }
    } catch { $err = $_.Exception.Message }
    $got = if (Test-Path $path) { (Get-Item $path).Length } else { 0 }
    if ($got -eq $size) { return '' }
    $why = "скачано $got байт из $size"
    if ($err) { $why += " ($err)"; $err = '' }
    Write-Host "  попытка ${try}: $why"
    if (-not $curl) { Remove-Item $path -Force -ErrorAction SilentlyContinue }
    Start-Sleep 5
  }
  return $why
}
# Шум хоста (#1350): загрузка ЦП и сколько процессов эмулятора (qemu) запущено — до и после прогона, в итоговой
# строке и в log.txt, чтобы шумный прогон отличался от регрессии фактом
function Get-Load {
  $cpu = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Measure-Object LoadPercentage -Average).Average
  $emu = @(Get-Process -Name 'qemu-system-*' -ErrorAction SilentlyContinue).Count
  return "ЦП $([int]$cpu)%, эмуляторов $emu"
}
$repo  = 'D:\AI\DeepDive'
$out   = 'D:\AI\qa-build'
$run   = "$out\run"
$app   = 'com.garrimajo5.deepdive'
$apk   = "$out\DeepDive-emulator.apk"   # эмулятору — x86_64-сборка (#844); телефону — DeepDive.apk
New-Item -ItemType Directory -Force $out | Out-Null
Remove-Item -Recurse -Force $run -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $run | Out-Null
$prSha = ''
if ($Pr) {
  $prSha = (gh api "repos/garrimajo5/DeepDive/pulls/$Pr" --jq '.head.sha').Trim()
  if (-not $prSha) { Write-Output "NO_PR #$Pr"; exit 1 }
}
# -Pr: сценарий — из ветки PR, без git show руками (#1592). -Scenario — путь в ветке (по умолчанию сценарий тестера);
# существующий локальный файл берётся как есть. Скачивание — через cmd: редирект PowerShell 5.1 портит UTF-8.
if ($Pr -and -not ($Scenario -and (Test-Path $Scenario))) {
  $inBranch = if ($Scenario) { $Scenario -replace '\\', '/' } else { 'tools/qa/scenario.json' }
  $prScen = "$out\scenario-pr$Pr.json"
  Remove-Item $prScen -Force -ErrorAction SilentlyContinue
  cmd /c "gh api `"repos/garrimajo5/DeepDive/contents/${inBranch}?ref=$prSha`" -H `"Accept: application/vnd.github.raw`" > `"$prScen`""
  if (-not (Test-Path $prScen) -or (Get-Item $prScen).Length -eq 0) {
    Write-Output "NO_SCENARIO: в ветке PR #$Pr ($($prSha.Substring(0,7))) нет $inBranch"; exit 1
  }
  Write-Output "сценарий: $inBranch из ветки PR #$Pr ($($prSha.Substring(0,7)))"
  $Scenario = $prScen
}
if (-not $Scenario) { $Scenario = "$repo\tools\qa\scenario.json" }

# Сценарий + шаг «закрыть игру» в конце
$steps = Get-Content $Scenario -Raw -Encoding utf8 | ConvertFrom-Json
$steps = @($steps) + [pscustomobject]@{ do = 'quit' }
$tmp = "$out\scenario.json"
[IO.File]::WriteAllText($tmp, ($steps | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding $false))

if ($Pc) {
  # ---- Godot на этом компьютере ----
  $godot = Get-ChildItem 'D:\Godot' -Recurse -Filter 'Godot*.exe' | Where-Object Name -notmatch 'console' | Select -First 1
  if (-not $godot) { Write-Output 'NO_GODOT: не нашёл Godot*.exe в D:\Godot'; exit 1 }
  $user = "$env:APPDATA\Godot\app_userdata\Погружение\qa"
  New-Item -ItemType Directory -Force $user | Out-Null
  Copy-Item $tmp "$user\scenario.json" -Force
  $head = (git -C $repo rev-parse --short HEAD).Trim()
  & $godot.FullName --path $repo --import --headless | Out-Null
  $p = Start-Process $godot.FullName -ArgumentList '--path', $repo, '--resolution', '2400x1080' -PassThru
  if (-not $p.WaitForExit(300000)) { $p.Kill(); Write-Output 'TIMEOUT: сценарий не закончился за 5 минут' }
  Copy-Item "$user\out\*" $run -Force
  $done = Test-Path "$run\done.txt"
  Write-Output "PC $head $($godot.Name) done=$done"
  Write-Output 'log:'; Get-Content "$run\log.txt" -Encoding utf8
  Write-Output "files: $run"
  exit 0
}

if ($Phone) {
  # ---- только APK телефона (arm64), со сверкой длины ----
  $rel = Invoke-RestMethod 'https://api.github.com/repos/garrimajo5/DeepDive/releases/tags/apk-latest' -Headers @{ 'User-Agent' = 'run-qa' }
  $asset = $rel.assets | Where-Object name -eq 'DeepDive.apk' | Select -First 1
  if (-not $asset) { Write-Output 'NO_ASSET: в релизе apk-latest нет DeepDive.apk — повторите позже'; exit 1 }
  $file = "$out\DeepDive.apk"
  Remove-Item $file -Force -ErrorAction SilentlyContinue
  $why = Get-Asset $asset.browser_download_url $file $asset.size
  if ($why) { Write-Output "DOWNLOAD_FAILED DeepDive.apk: $why — повторите позже"; exit 1 }
  Write-Output "OK $file ($($asset.size) байт) — $($rel.body)"
  exit 0
}

# ---- Эмулятор; APK из релиза apk-latest, с -Pr — из артефакта прогона PR ----
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
$adb = "$sdk\platform-tools\adb.exe"
if ($Pr) {
  # APK из артефакта deepdive-apk последнего прогона CI этой PR (REST, чтобы не зависеть от GraphQL)
  $sha = $prSha
  $rid = (gh api "repos/garrimajo5/DeepDive/actions/runs?head_sha=$sha&per_page=1" --jq '.workflow_runs[0].id').Trim()
  if (-not $rid) { Write-Output "NO_RUN: для PR #$Pr ($($sha.Substring(0,7))) прогона CI ещё нет"; exit 1 }
  $dir = "$out\pr$Pr"
  Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
  gh run download $rid -n deepdive-apk -D $dir
  # эмулятору — x86_64-сборка; в артефактах до #844 был один общий DeepDive.apk
  $apk = @("$dir\DeepDive-emulator.apk", "$dir\DeepDive.apk") | Where-Object { Test-Path $_ } | Select -First 1
  if (-not $apk) { Write-Output "NO_ARTIFACT: в прогоне PR #$Pr нет deepdive-apk (сборка APK не шла — в PR нет кода?)"; exit 1 }
  $head = "PR#$Pr $($sha.Substring(0,7))"
} else {
  # APK из релиза apk-latest (то, что собрал CI из main)
  $rel = Invoke-RestMethod 'https://api.github.com/repos/garrimajo5/DeepDive/releases/tags/apk-latest' -Headers @{ 'User-Agent' = 'run-qa' }
  $head = if ($rel.body -match 'коммит ([0-9a-f]{7})') { $Matches[1] } else { $rel.published_at }
  $last = if (Test-Path "$out\last-commit.txt") { (Get-Content "$out\last-commit.txt").Trim() } else { '' }
  if ($head -eq $last -and -not $Force) { Write-Output "NO_CHANGES $head"; exit 0 }
  # эмулятору — x86_64-сборка (#844); в релизах до неё — один общий DeepDive.apk
  $asset = $rel.assets | Where-Object name -eq 'DeepDive-emulator.apk' | Select -First 1
  if (-not $asset) { $asset = $rel.assets | Where-Object name -eq 'DeepDive.apk' | Select -First 1 }
  if (-not $asset) { Write-Output "NO_ASSET ${head}: в релизе apk-latest нет APK (перезаливается?) — повторите позже"; exit 1 }
  # Старый APK не ставим: релиз мог перезаливаться, и скачивание упадёт (BlobNotFound, #1125)
  Remove-Item $apk -Force -ErrorAction SilentlyContinue
  $why = Get-Asset $asset.browser_download_url $apk $asset.size
  if ($why) { Write-Output "DOWNLOAD_FAILED ${head}: $why — повторите позже"; exit 1 }
}

# -ColdBoot (#1592): эмулятор, на котором долго жили чужие окна и прогоны, шумит — закрыть и поднять заново
# без снимка состояния (-no-snapshot-load), прежде чем считать заминки регрессией
if ($ColdBoot -and ((& $adb devices) -match 'emulator-\d+')) {
  & $adb emu kill | Out-Null
  for ($i = 0; $i -lt 30; $i++) { Start-Sleep 2; if (-not ((& $adb devices) -match 'emulator-\d+')) { break } }
}
$cold = if ($ColdBoot) { ' -no-snapshot-load' } else { '' }
if (-not ((& $adb devices) -match 'emulator-\d+\s+device')) {
  # Эмулятор — отвязанным процессом (WMI, не потомок скрипта): живёт после прогона, даже если фоновый
  # run-qa.ps1 закрыли вместе с деревом процессов, — можно досматривать руками через adb (#1350)
  Invoke-CimMethod Win32_Process -MethodName Create -Arguments @{
    CommandLine = "`"$sdk\emulator\emulator.exe`" -avd Pixel_8$cold" } | Out-Null
  & $adb wait-for-device
  for ($i = 0; $i -lt 60; $i++) { if ((& $adb shell getprop sys.boot_completed).Trim() -eq '1') { break }; Start-Sleep 5 }
}
$inst = ''
for ($i = 0; $i -lt 3; $i++) { $inst = (& $adb install -r $apk 2>&1 | Out-String); if ($inst -match 'Success') { break }; Start-Sleep 10 }
if ($inst -notmatch 'Success') { Write-Output "INSTALL_FAILED $head"; $inst; exit 1 }

$loadBefore = Get-Load
# Сценарий — в user:// игры (files/qa/). APK отладочный, поэтому run-as работает.
& $adb shell am force-stop $app
& $adb push $tmp /data/local/tmp/qa-scenario.json | Out-Null
& $adb shell "run-as $app sh -c 'mkdir -p files/qa && rm -rf files/qa/out && cp /data/local/tmp/qa-scenario.json files/qa/scenario.json'"
& $adb logcat -c
& $adb shell monkey -p $app -c android.intent.category.LAUNCHER 1 | Out-Null
$done = $false
# 300 × 2 с: прогон 800+ шагов с прогревом и установкой не укладывался в 195 × 2 с (#1533)
for ($i = 0; $i -lt 300; $i++) {
  Start-Sleep 2
  if ((& $adb shell "run-as $app ls files/qa/out/done.txt" 2>&1) -match 'done.txt$') { $done = $true; break }
}
# Забрать files/qa/out. Снимок пишется после строки «скриншот» в логе: пока снимков меньше строк или нет
# done.txt — ещё до 4 попыток через 15 с (#1533: последние 2 снимка и done.txt добирались руками).
function Get-Out {
  $names = (& $adb shell "run-as $app ls files/qa/out") -split "`r?`n" | Where-Object { $_ -match '\.(png|txt)$' }
  foreach ($n in $names) { cmd /c "`"$adb`" exec-out run-as $app cat files/qa/out/$n > `"$run\$n`"" }
}
$miss = @()
for ($try = 0; $try -lt 5; $try++) {
  Start-Sleep $(if ($try -eq 0) { 2 } else { 15 })
  Get-Out
  $done = Test-Path "$run\done.txt"
  $want = if (Test-Path "$run\log.txt") {
    @(Get-Content "$run\log.txt" -Encoding utf8 | ForEach-Object { if ($_ -match '^скриншот (\S+) \|') { $Matches[1] } })
  } else { @() }
  $have = @(Get-ChildItem "$run\*.png" | ForEach-Object BaseName)
  $miss = @($want | Where-Object { $_ -notin $have })
  if ($done -and -not $miss) { break }
}
$loadAfter = Get-Load
& $adb logcat -d | Set-Content "$run\logcat.txt" -Encoding utf8
$errs = Select-String -Path "$run\logcat.txt" -Pattern ' E godot|SCRIPT ERROR|AndroidRuntime|FATAL' |
  ForEach-Object { ($_.Line -split ': ', 2)[1] } | Where-Object { $_ -and $_ -notmatch '^\s*$' } |
  Group-Object | Sort Count -Descending | ForEach-Object { "$($_.Count)x $($_.Name)" }

# STALE_APK (#1592): первая строка лога — версия как на плашке (`v… · #сборка коммит`); скачался не тот APK
# (релиз перезаливался) — коммит не совпадёт с заметкой релиза. PR-сборка несёт коммит слияния — её не сверяем.
$built = ''
if (Test-Path "$run\log.txt") {
  $first = Get-Content "$run\log.txt" -Encoding utf8 -TotalCount 1
  if ($first -match ' · #\d+ ([0-9a-f]{7})') { $built = $Matches[1] }
}
$stale = (-not $Pr) -and $built -and ($head -match '^[0-9a-f]{7}$') -and ($built -ne $head)
# Помехи (#1592): игра свёрнута посреди прогона (строка QaRunner.PAUSED_LINE) и чужие окна поверх неё
# (запуск активности другого приложения в logcat: браузер, am start другого инструмента)
$paused = if (Test-Path "$run\log.txt") { @(Select-String -Path "$run\log.txt" -Pattern '^игра свёрнута' -Encoding utf8).Count } else { 0 }
$foreign = @(Select-String -Path "$run\logcat.txt" -Pattern 'START u0 \{' -Encoding utf8 |
  Where-Object { $_.Line -notmatch [regex]::Escape($app) }).Count
$noise = $paused + $foreign
if (-not $Pr -and -not $stale) { Set-Content "$out\last-commit.txt" $head }
Write-Output "OK $head done=$done"
if ($Pr) { Write-Output "PR: #$Pr (артефакт прогона CI, не релиз)" }
else {
  Write-Output "release: $($rel.body)"
  Write-Output "previous tested: $last"
}
Write-Output 'log:'; if (Test-Path "$run\log.txt") { Get-Content "$run\log.txt" -Encoding utf8 }
Write-Output 'errors:'; $errs | Select -First 30
Write-Output "files: $run"
# Итог одной строкой — и в конец log.txt: лог из отчёта сам называет сборку, снимки и шум хоста (#1350)
$result = "RUN $head done=$done снимков $($have.Count) из $($want.Count) | помехи: $noise (свёрнута $paused, чужих окон $foreign) | до: $loadBefore | после: $loadAfter"
if ($stale) { $result += " | STALE_APK $head $built" }
if ($stale) { Write-Output "STALE_APK $head $built — скачался другой APK (релиз перезаливался?): повторите с -Force" }
Write-Output $result
Add-Content "$run\log.txt" "run-qa: $result" -Encoding utf8
# Заметная строка в самом конце: прогон не дошёл до конца или не все снимки забраны (#1533)
if (-not $done -or $miss) {
  $why = @()
  if (-not $done) { $why += 'нет done.txt' }
  if ($miss) { $why += "нет снимков ($($miss.Count)): $($miss -join ', ')" }
  Write-Output "NOT_DONE $head — $($why -join '; ')"
}
