# Прогон сборки на эмуляторе: скачать APK из релиза apk-latest, поставить, снять скриншоты и лог.
# Пишет результат в D:\AI\qa-build\run\ и печатает итог. Отчёт пишет Claude по docs/QA.md.
# Собирать APK локально не нужно: проверяем ровно тот файл, что собрал CI из main.
# Скрипт лежит в main (tools/qa/) и меняется вместе с игрой: перед запуском обнови клон — git -C D:\AI\DeepDive pull.
param([switch]$Force)
$ErrorActionPreference = 'Continue'
$repo  = 'garrimajo5/DeepDive'
$out   = 'D:\AI\qa-build'
$run   = "$out\run"
$sdk   = "$env:LOCALAPPDATA\Android\Sdk"
$adb   = "$sdk\platform-tools\adb.exe"
$app   = 'com.garrimajo5.deepdive'
$apk   = "$out\DeepDive.apk"

New-Item -ItemType Directory -Force $out | Out-Null

# Какой коммит в релизе: заметка релиза «APK из main, коммит abc1234: …»
$rel = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/tags/apk-latest" -Headers @{ 'User-Agent' = 'run-qa' }
$head = if ($rel.body -match 'коммит ([0-9a-f]{7})') { $Matches[1] } else { $rel.published_at }
$last = if (Test-Path "$out\last-commit.txt") { (Get-Content "$out\last-commit.txt").Trim() } else { '' }
if ($head -eq $last -and -not $Force) { Write-Output "NO_CHANGES $head"; exit 0 }
$asset = $rel.assets | Where-Object name -eq 'DeepDive.apk' | Select -First 1
Invoke-WebRequest $asset.browser_download_url -OutFile $apk -Headers @{ 'User-Agent' = 'run-qa' }
$range = if ($last) { "$last...$head" } else { '' }
$newCommits = if ($range) {
  (Invoke-RestMethod "https://api.github.com/repos/$repo/compare/$range" -Headers @{ 'User-Agent' = 'run-qa' }).commits |
    ForEach-Object { "$($_.sha.Substring(0,7)) $(($_.commit.message -split "`n")[0])" }
} else { $rel.body }

Remove-Item -Recurse -Force $run -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $run | Out-Null

# Эмулятор
if (-not ((& $adb devices) -match 'emulator-\d+\s+device')) {
  Start-Process "$sdk\emulator\emulator.exe" -ArgumentList '-avd','Pixel_8' -WindowStyle Minimized
  & $adb wait-for-device
  for ($i = 0; $i -lt 60; $i++) { if ((& $adb shell getprop sys.boot_completed).Trim() -eq '1') { break }; Start-Sleep 5 }
}

# Установка и запуск. Подпись отладочная и одна на все сборки (android/debug.keystore), -r ставит поверх.
$inst = ''
for ($i = 0; $i -lt 3; $i++) { $inst = (& $adb install -r $apk 2>&1 | Out-String); if ($inst -match 'Success') { break }; Start-Sleep 10 }
if ($inst -notmatch 'Success') { Write-Output "INSTALL_FAILED $head"; $inst; exit 1 }
& $adb shell am force-stop $app
& $adb logcat -c
& $adb shell monkey -p $app -c android.intent.category.LAUNCHER 1 | Out-Null
Start-Sleep 15

# Экран Pixel 8 в альбомной: 2400 × 1080. Крестовина — центр (270, 810), радиус 205; кнопка действия — (2181, 810).
function Shot($name) { cmd /c "`"$adb`" exec-out screencap -p > `"$run\$name.png`"" }
Shot '01-start'
& $adb shell input swipe 1200 500 1500 500 600; Start-Sleep 1; Shot '02-swipe-right'
& $adb shell input swipe 1500 500 1200 500 600; Start-Sleep 1
& $adb shell input tap 2181 810; Start-Sleep 2; Shot '03-action'
& $adb shell input swipe 270 670 270 670 4000; Start-Sleep 1; Shot '04-forward'
& $adb shell input tap 2181 810; Start-Sleep 2; Shot '05-action-again'
Start-Sleep 3
$appPid = (& $adb shell pidof $app).Trim()
$alive = [bool]$appPid
& $adb logcat -d | Set-Content "$run\logcat.txt" -Encoding utf8
if ($alive) { & $adb logcat -d --pid=$appPid | Set-Content "$run\app.txt" -Encoding utf8 } else { Copy-Item "$run\logcat.txt" "$run\app.txt" }
$errs = Select-String -Path "$run\app.txt" -Pattern ' E godot|SCRIPT ERROR|AndroidRuntime|FATAL' | ForEach-Object { ($_.Line -split ': ', 2)[1] } |
  Where-Object { $_ -and $_ -notmatch '^\s*$' } |
  Group-Object | Sort Count -Descending | ForEach-Object { "$($_.Count)x $($_.Name)" }

Set-Content "$out\last-commit.txt" $head
Write-Output "OK $head"
Write-Output "release: $($rel.body)"
Write-Output "previous tested: $last"
Write-Output "commits since previous:"; $newCommits
Write-Output "app alive after test: $alive"
Write-Output "errors:"; $errs | Select -First 30
Write-Output "files: $run"
