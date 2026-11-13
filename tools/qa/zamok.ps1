# Замок тестера (#1350, 12.11): две сессии одного часа запускали второй run-qa.ps1 на том же эмуляторе и второй
# publish-qa.ps1 в том же клоне — прогон шумел, ветки отчётов уходили пустыми. Скрипт берёт файл-замок с PID, временем
# запуска процесса и «с какого времени»; замок живого чужого процесса — строка BUSY и выход.
# Подключение: . (Join-Path $PSScriptRoot 'zamok.ps1'); $busy = Lock-Qa <файл> '<что>'; if ($busy) { $busy; exit 2 }
# Снимать руками не обязательно: умер процесс (или PID занял другой — время запуска не то) — замок ничей.
# Замок живого, но зависшего процесса (#1746: adb shell getprop висел 3 ч) сам не снимается: в BUSY — возраст замка,
# старше HUNG_MIN минут — «похоже, завис» и как снять. Чтобы не зависать, внешние вызовы — через Invoke-Timed
# (предел на вызов, затем kill), ожидание загрузки эмулятора — Wait-Boot (общий предел).
#   zamok.ps1 -SelfTest — проверка на временных файлах (её гоняет CI, job «Скрипты тестера»)
param([switch]$SelfTest)

# Время запуска процесса $id (ticks, UTC) или 0, если процесса нет
function Get-ProcStart([int]$id) {
  $p = Get-Process -Id $id -ErrorAction SilentlyContinue
  if (-not $p) { return [long]0 }
  try { return [long]$p.StartTime.ToUniversalTime().Ticks } catch { return [long]1 }
}

# Взять замок $path для «$what». Возвращает '' — замок наш, иначе строку BUSY <с какого времени> …
# $procId/$start — для проверки (по умолчанию — этот процесс).
function Lock-Qa([string]$path, [string]$what, [int]$procId = $PID, [long]$start = -1) {
  if ($start -lt 0) { $start = Get-ProcStart $procId }
  $dir = Split-Path $path -Parent
  if ($dir) { New-Item -ItemType Directory -Force $dir | Out-Null }
  for ($try = 0; $try -lt 3; $try++) {
    try {
      # CreateNew — атомарно: из двух одновременных запусков файл создаст только один
      $fs = [IO.File]::Open($path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
      $since = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
      $bytes = (New-Object Text.UTF8Encoding $false).GetBytes("pid=$procId`nstart=$start`nsince=$since`nwhat=$what`n")
      $fs.Write($bytes, 0, $bytes.Length); $fs.Close()
      return ''
    } catch [IO.IOException] {
      $held = Read-QaLock $path
      if (-not $held) { Start-Sleep -Milliseconds 200; continue }   # файл пишет другой — перечитать
      if ($held.pid -eq $procId -and $held.start -eq $start) { return '' }   # уже наш
      if ((Get-ProcStart $held.pid) -eq $held.start -and $held.start -ne 0) {
        $age = Get-LockAge $held.since
        $tail = if ($age -lt 0) { '' } else { "; держит $age мин" }
        if ($age -ge $HUNG_MIN) { $tail += "; похоже, завис — снять: Stop-Process -Id $($held.pid) (и его adb), затем повторить" }
        return "BUSY $($held.since) — $($held.what) (PID $($held.pid), замок $path$tail)"
      }
      Remove-Item $path -Force -ErrorAction SilentlyContinue   # хозяин умер — замок ничей
    }
  }
  return "BUSY ? — не удалось взять замок $path"
}

# Замок старше стольких минут при живом хозяине — «похоже, завис» (плановый прогон с -ColdBoot — до ~20 мин)
$HUNG_MIN = 30

# Сколько минут держится замок с «since» (локальное время 'yyyy-MM-dd HH:mm:ss'); -1 — не разобрать
function Get-LockAge([string]$since, [datetime]$now = (Get-Date)) {
  $t = [datetime]::MinValue
  if (-not [datetime]::TryParseExact($since, 'yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture,
      [Globalization.DateTimeStyles]::None, [ref]$t)) { return -1 }
  return [int][math]::Floor(($now - $t).TotalMinutes)
}

# Запустить $exe с аргументами $argv и ждать не дольше $ms. Возвращает вывод (stdout) или $null — не уложился,
# процесс убит (#1746: один зависший `adb shell` держал замок тестера часами). Поток читается асинхронно, а не
# WaitForExit() без предела: сервер adb, запущенный этим вызовом, может держать трубу открытой.
function Invoke-Timed([string]$exe, [string[]]$argv, [int]$ms = 10000) {
  $psi = New-Object Diagnostics.ProcessStartInfo
  $psi.FileName = $exe
  $psi.Arguments = (@($argv) | ForEach-Object { if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join ' '
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.CreateNoWindow = $true
  try { $p = [Diagnostics.Process]::Start($psi) } catch { return $null }
  $out = $p.StandardOutput.ReadToEndAsync()
  $null = $p.StandardError.ReadToEndAsync()
  if (-not $p.WaitForExit($ms)) {
    try { $p.Kill() } catch { }
    return $null
  }
  if ($out.Wait(2000)) { return [string]$out.Result }
  return ''
}

# Ждать, пока $probe вернёт «1» (sys.boot_completed), не дольше $limitSec всего; $true — дождались, $false — предел.
# $probe — блок, обычно { Invoke-Timed $adb @('shell','getprop','sys.boot_completed') 10000 }: «нет устройства» и
# зависший вызов ($null) — просто ещё не загрузился.
function Wait-Boot([scriptblock]$probe, [int]$limitSec = 300, [int]$stepSec = 5) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($true) {
    $r = & $probe
    if ($null -ne $r -and "$r".Trim() -eq '1') { return $true }
    if ($sw.Elapsed.TotalSeconds + $stepSec -gt $limitSec) { return $false }
    Start-Sleep -Seconds $stepSec
  }
}

# Нагрузка Android (#1350, 12.11 21:30): после -ColdBoot хост остыл, а внутри эмулятора ещё идёт загрузка служб —
# первые шаги сценария шумные. Read-LoadAvg — первое число /proc/loadavg (средняя за минуту) или $null, если вывод
# не разобрать; Read-Cores — число ядер из `nproc` (не разобрать — 4).
function Read-LoadAvg($text) {
  if ($null -eq $text) { return $null }
  $m = [regex]::Match("$text", '^\s*(\d+(?:\.\d+)?)\s+\d')
  if (-not $m.Success) { return $null }
  return [double]::Parse($m.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
}
function Read-Cores($text) {
  $n = 0
  if ($null -ne $text -and [int]::TryParse("$text".Trim(), [ref]$n) -and $n -gt 0) { return $n }
  return 4
}

# Ждать, пока $probe (нагрузка числом или $null) $need раз подряд через $stepSec не окажется ниже $below, не дольше
# $limitSec. Проба не разобралась ни разу за первые $need попыток — замера нет: пауза $pauseSec и выход.
# Возвращает @{ waited = секунд; load = последняя нагрузка или $null; calm = дождались ли; how = 'замер'|'пауза'|'предел' }.
function Wait-Calm([scriptblock]$probe, [double]$below, [int]$limitSec = 120, [int]$stepSec = 5, [int]$need = 3,
    [int]$pauseSec = 30) {
  $waited = 0; $calm = 0; $tries = 0; $seen = $false; $load = $null
  while ($true) {
    $r = & $probe
    $tries++
    if ($null -ne $r) { $seen = $true; $load = [double]$r }
    if ($null -ne $r -and [double]$r -lt $below) { $calm++ } else { $calm = 0 }
    if ($calm -ge $need) { return @{ waited = $waited; load = $load; calm = $true; how = 'замер' } }
    if (-not $seen -and $tries -ge $need) {
      if ($pauseSec -gt 0) { Start-Sleep -Seconds $pauseSec }
      return @{ waited = $waited + $pauseSec; load = $null; calm = $false; how = 'пауза' }
    }
    if ($waited + $stepSec -gt $limitSec) { return @{ waited = $waited; load = $load; calm = $false; how = 'предел' } }
    if ($stepSec -gt 0) { Start-Sleep -Seconds $stepSec }
    $waited += $stepSec
  }
}

# Строка итога RUN про ожидание Android: «Android тихо за 25 с (load 1.20 < 2.0)» / «Android не остыл за 120 с: три
# замера подряд < 2.0 не набралось, последний 1.40» (выход по времени — последний замер бывает и ниже порога:
# не набралось трёх подряд, #1350, 13.11) / «… нет /proc/loadavg, пауза 30 с»
function Format-Calm($res, [double]$below) {
  $inv = [Globalization.CultureInfo]::InvariantCulture
  $lim = $below.ToString('0.0', $inv)
  if ($res.how -eq 'пауза') { return "Android: нет /proc/loadavg, пауза $($res.waited) с" }
  $l = if ($null -eq $res.load) { '?' } else { ([double]$res.load).ToString('0.00', $inv) }
  if ($res.calm) { return "Android тихо за $($res.waited) с (load $l < $lim)" }
  return "Android не остыл за $($res.waited) с: три замера подряд < $lim не набралось, последний $l"
}

# Содержимое замка: pid, start, since, what — или $null, если файла нет или он ещё пишется
function Read-QaLock([string]$path) {
  if (-not (Test-Path $path)) { return $null }
  $lines = @(Get-Content $path -Encoding utf8 -ErrorAction SilentlyContinue)
  $h = @{}
  foreach ($l in $lines) { if ($l -match '^(\w+)=(.*)$') { $h[$Matches[1]] = $Matches[2] } }
  if (-not $h.ContainsKey('pid') -or -not $h.ContainsKey('start')) { return $null }
  return [pscustomobject]@{ pid = [int]$h['pid']; start = [long]$h['start']; since = "$($h['since'])"; what = "$($h['what'])" }
}

# Снять свой замок (чужой не трогает)
function Unlock-Qa([string]$path, [int]$procId = $PID) {
  $held = Read-QaLock $path
  if ($held -and $held.pid -eq $procId) { Remove-Item $path -Force -ErrorAction SilentlyContinue }
}

if ($SelfTest) {
  $bad = 0
  function Check([bool]$cond, [string]$what) { if (-not $cond) { Write-Output "FAIL $what"; $script:bad++ } else { Write-Output "ok $what" } }
  $root = Join-Path ([IO.Path]::GetTempPath()) ("zamok-" + [guid]::NewGuid().ToString('N'))
  $lock = Join-Path $root 'run.lock'
  $me = Get-ProcStart $PID
  Check ($me -gt 0) 'время запуска своего процесса'
  Check ((Lock-Qa $lock 'прогон 1') -eq '') 'свободный замок берётся'
  Check ((Read-QaLock $lock).what -eq 'прогон 1') 'в замке — что и PID'
  Check ((Lock-Qa $lock 'прогон 1') -eq '') 'свой замок — повторно наш'
  # живой чужой: этот же процесс под видом другого вызова — PID и время совпадают с живым, но «вызов» другой.
  # Чужой PID с тем же временем запуска подделать нельзя, поэтому пишем замок «от» родительского процесса.
  $parent = 0
  if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
    $parent = [int](Get-CimInstance Win32_Process -Filter "ProcessId = $PID" -ErrorAction SilentlyContinue).ParentProcessId
  }
  if (-not $parent) { $parent = (Get-Process -Id $PID).Parent.Id }   # pwsh 7 (CI на ubuntu)
  Remove-Item $lock -Force
  Check ((Lock-Qa $lock 'чужой прогон' $parent) -eq '') 'замок «от» живого родителя'
  $busy = Lock-Qa $lock 'прогон 2'
  Check ($busy -match '^BUSY \d{4}-\d\d-\d\d \d\d:\d\d:\d\d — чужой прогон') "живой чужой — BUSY с временем: $busy"
  Check ($busy -match '; держит 0 мин\)$') "свежий замок — возраст без «завис»: $busy"
  Unlock-Qa $lock
  Check (Test-Path $lock) 'чужой замок Unlock-Qa не снимает'
  # #1746: живой хозяин держит замок 45 мин — в BUSY возраст и как снять
  $old = (Get-Date).AddMinutes(-45).ToString('yyyy-MM-dd HH:mm:ss')
  [IO.File]::WriteAllText($lock, "pid=$parent`nstart=$(Get-ProcStart $parent)`nsince=$old`nwhat=висит`n")
  $busy = Lock-Qa $lock 'прогон 2б'
  Check ($busy -match "^BUSY $old — висит .*держит 4[56] мин; похоже, завис — снять: Stop-Process -Id $parent") "зависший — возраст и как снять: $busy"
  Check ((Read-QaLock $lock).what -eq 'висит') 'зависший замок сам не снимается'
  Check ((Get-LockAge '2026-11-12 18:09:45' ([datetime]'2026-11-12 21:10:00')) -eq 180) 'возраст замка в минутах'
  Check ((Get-LockAge 'вчера') -eq -1) 'возраст без даты — -1'
  # #1746: зависший вызов — $null за предел и убит; быстрый — его вывод
  $sh = (Get-Process -Id $PID).Path
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $r = Invoke-Timed $sh @('-NoProfile', '-Command', 'Start-Sleep 60') 3000
  Check ($null -eq $r -and $sw.Elapsed.TotalSeconds -lt 15) "зависший вызов обрывается по пределу ($([int]$sw.Elapsed.TotalSeconds) с)"
  $r = Invoke-Timed $sh @('-NoProfile', '-Command', 'Write-Output 1') 60000
  Check ("$r".Trim() -eq '1') "быстрый вызов — его вывод: '$r'"
  # Wait-Boot: «1» на третьей пробе — дождались; вечно $null (висит) — $false по общему пределу
  $script:probes = 0
  Check (Wait-Boot { $script:probes++; if ($script:probes -ge 3) { "1`r`n" } else { '0' } } 30 0) 'загрузка — на третьей пробе'
  Check ($script:probes -eq 3) "проб до загрузки: $script:probes"
  $sw = [Diagnostics.Stopwatch]::StartNew()
  Check (-not (Wait-Boot { $null } 3 1)) 'не загрузился — $false'
  Check ($sw.Elapsed.TotalSeconds -lt 6) "общий предел ожидания держится ($([int]$sw.Elapsed.TotalSeconds) с)"
  # Нагрузка Android (#1350, 12.11 21:30): разбор /proc/loadavg и nproc, ожидание тишины
  Check ((Read-LoadAvg "3.41 2.10 1.05 5/812 4321`n") -eq 3.41) 'loadavg — первое число'
  Check ($null -eq (Read-LoadAvg 'error: no devices/emulators found')) 'loadavg без числа — $null'
  Check ($null -eq (Read-LoadAvg $null)) 'loadavg без вывода (завис) — $null'
  Check ((Read-Cores "8`r`n") -eq 8) 'ядра из nproc'
  Check ((Read-Cores 'nproc: not found') -eq 4) 'ядра не разобрать — 4'
  # пробы 5,0 4,0 1,5 3,0 1,2 1,0 0,9 при пороге 2: тишина — три подряд ниже (пробы 5…7), ждали 6 шагов
  $script:seq = @(5.0, 4.0, 1.5, 3.0, 1.2, 1.0, 0.9); $script:at = 0
  $res = Wait-Calm { $v = $script:seq[$script:at]; $script:at++; $v } 2.0 120 0 3 0
  Check ($res.calm -and $res.how -eq 'замер' -and $script:at -eq 7) "тишина на седьмой пробе: проб $script:at, $($res.how)"
  Check ((Format-Calm @{ waited = 30; load = 0.9; calm = $true; how = 'замер' } 2.0) -eq 'Android тихо за 30 с (load 0.90 < 2.0)') 'строка RUN — тихо'
  # одна низкая проба среди высоких — не тишина; предел 10 с шагом 5 — три пробы (0, 5, 10 с) и выход
  $script:seq = @(6.0, 1.0, 6.0, 1.0); $script:at = 0
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $res = Wait-Calm { $v = $script:seq[$script:at]; $script:at++; $v } 2.0 10 5 3 0
  Check (-not $res.calm -and $res.how -eq 'предел' -and $res.waited -eq 10 -and $res.load -eq 6.0) "не остыл — предел: ждали $($res.waited) с, load $($res.load)"
  Check ((Format-Calm $res 2.0) -eq 'Android не остыл за 10 с: три замера подряд < 2.0 не набралось, последний 6.00') "строка RUN — не остыл: $(Format-Calm $res 2.0)"
  # выход по времени с последним замером ниже порога (1,4 < 2,0): строка не спорит сама с собой
  Check ((Format-Calm @{ waited = 120; load = 1.4; calm = $false; how = 'предел' } 2.0) -eq 'Android не остыл за 120 с: три замера подряд < 2.0 не набралось, последний 1.40') 'строка RUN — предел при низком последнем замере'
  Check ($sw.Elapsed.TotalSeconds -lt 15) "предел держится ($([int]$sw.Elapsed.TotalSeconds) с)"
  # /proc/loadavg не читается (три $null подряд) — пауза и выход, без ожидания предела
  $script:at = 0
  $res = Wait-Calm { $script:at++; $null } 2.0 120 0 3 0
  Check ($res.how -eq 'пауза' -and $script:at -eq 3) "нет замера — пауза после трёх проб: проб $script:at"
  Check ((Format-Calm @{ waited = 30; load = $null; calm = $false; how = 'пауза' } 2.0) -eq 'Android: нет /proc/loadavg, пауза 30 с') 'строка RUN — пауза'
  # мёртвый хозяин: PID, которого нет
  Remove-Item $lock -Force
  [IO.File]::WriteAllText($lock, "pid=999999`nstart=12345`nsince=2026-11-12 01:00:00`nwhat=старый`n")
  Check ((Lock-Qa $lock 'прогон 3') -eq '') 'замок умершего процесса снимается'
  # PID занят другим процессом: время запуска не то
  Remove-Item $lock -Force
  [IO.File]::WriteAllText($lock, "pid=$PID`nstart=$($me - 10)`nsince=2026-11-12 01:00:00`nwhat=старый`n")
  Check ((Lock-Qa $lock 'прогон 4') -eq '') 'PID занят другим процессом — замок ничей'
  Check ((Read-QaLock $lock).what -eq 'прогон 4') 'новый хозяин записан'
  Unlock-Qa $lock
  Check (-not (Test-Path $lock)) 'свой замок снимается'
  Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
  if ($bad) { Write-Output "zamok.ps1 -SelfTest: ошибок $bad"; exit 1 }
  Write-Output 'zamok.ps1 -SelfTest: ок'
}
