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
param([switch]$Pc, [switch]$Force, [string]$Scenario, [int]$Pr)
$ErrorActionPreference = 'Continue'
$repo  = 'D:\AI\DeepDive'
$out   = 'D:\AI\qa-build'
$run   = "$out\run"
$app   = 'com.garrimajo5.deepdive'
$apk   = "$out\DeepDive-emulator.apk"   # эмулятору — x86_64-сборка (#844); телефону — DeepDive.apk
if (-not $Scenario) { $Scenario = "$repo\tools\qa\scenario.json" }
New-Item -ItemType Directory -Force $out | Out-Null
Remove-Item -Recurse -Force $run -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $run | Out-Null

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

# ---- Эмулятор; APK из релиза apk-latest, с -Pr — из артефакта прогона PR ----
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
$adb = "$sdk\platform-tools\adb.exe"
if ($Pr) {
  # APK из артефакта deepdive-apk последнего прогона CI этой PR (REST, чтобы не зависеть от GraphQL)
  $sha = (gh api "repos/garrimajo5/DeepDive/pulls/$Pr" --jq '.head.sha').Trim()
  if (-not $sha) { Write-Output "NO_PR #$Pr"; exit 1 }
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
  Invoke-WebRequest $asset.browser_download_url -OutFile $apk -Headers @{ 'User-Agent' = 'run-qa' }
}

if (-not ((& $adb devices) -match 'emulator-\d+\s+device')) {
  Start-Process "$sdk\emulator\emulator.exe" -ArgumentList '-avd', 'Pixel_8' -WindowStyle Minimized
  & $adb wait-for-device
  for ($i = 0; $i -lt 60; $i++) { if ((& $adb shell getprop sys.boot_completed).Trim() -eq '1') { break }; Start-Sleep 5 }
}
$inst = ''
for ($i = 0; $i -lt 3; $i++) { $inst = (& $adb install -r $apk 2>&1 | Out-String); if ($inst -match 'Success') { break }; Start-Sleep 10 }
if ($inst -notmatch 'Success') { Write-Output "INSTALL_FAILED $head"; $inst; exit 1 }

# Сценарий — в user:// игры (files/qa/). APK отладочный, поэтому run-as работает.
& $adb shell am force-stop $app
& $adb push $tmp /data/local/tmp/qa-scenario.json | Out-Null
& $adb shell "run-as $app sh -c 'mkdir -p files/qa && rm -rf files/qa/out && cp /data/local/tmp/qa-scenario.json files/qa/scenario.json'"
& $adb logcat -c
& $adb shell monkey -p $app -c android.intent.category.LAUNCHER 1 | Out-Null
$done = $false
for ($i = 0; $i -lt 150; $i++) {
  Start-Sleep 2
  if ((& $adb shell "run-as $app ls files/qa/out/done.txt" 2>&1) -match 'done.txt$') { $done = $true; break }
}
Start-Sleep 2
$names = (& $adb shell "run-as $app ls files/qa/out") -split "`r?`n" | Where-Object { $_ -match '\.(png|txt)$' }
foreach ($n in $names) { cmd /c "`"$adb`" exec-out run-as $app cat files/qa/out/$n > `"$run\$n`"" }
& $adb logcat -d | Set-Content "$run\logcat.txt" -Encoding utf8
$errs = Select-String -Path "$run\logcat.txt" -Pattern ' E godot|SCRIPT ERROR|AndroidRuntime|FATAL' |
  ForEach-Object { ($_.Line -split ': ', 2)[1] } | Where-Object { $_ -and $_ -notmatch '^\s*$' } |
  Group-Object | Sort Count -Descending | ForEach-Object { "$($_.Count)x $($_.Name)" }

if (-not $Pr) { Set-Content "$out\last-commit.txt" $head }
Write-Output "OK $head done=$done"
if ($Pr) { Write-Output "PR: #$Pr (артефакт прогона CI, не релиз)" }
else {
  Write-Output "release: $($rel.body)"
  Write-Output "previous tested: $last"
}
Write-Output 'log:'; if (Test-Path "$run\log.txt") { Get-Content "$run\log.txt" -Encoding utf8 }
Write-Output 'errors:'; $errs | Select -First 30
Write-Output "files: $run"
