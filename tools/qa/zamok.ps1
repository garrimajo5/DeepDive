# Замок тестера (#1350, 12.11): две сессии одного часа запускали второй run-qa.ps1 на том же эмуляторе и второй
# publish-qa.ps1 в том же клоне — прогон шумел, ветки отчётов уходили пустыми. Скрипт берёт файл-замок с PID, временем
# запуска процесса и «с какого времени»; замок живого чужого процесса — строка BUSY и выход.
# Подключение: . (Join-Path $PSScriptRoot 'zamok.ps1'); $busy = Lock-Qa <файл> '<что>'; if ($busy) { $busy; exit 2 }
# Снимать руками не обязательно: умер процесс (или PID занял другой — время запуска не то) — замок ничей.
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
        return "BUSY $($held.since) — $($held.what) (PID $($held.pid), замок $path)"
      }
      Remove-Item $path -Force -ErrorAction SilentlyContinue   # хозяин умер — замок ничей
    }
  }
  return "BUSY ? — не удалось взять замок $path"
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
  Unlock-Qa $lock
  Check (Test-Path $lock) 'чужой замок Unlock-Qa не снимает'
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
