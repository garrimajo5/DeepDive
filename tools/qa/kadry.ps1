# Худший кадр по шагам для правила трёх тихих прогонов (#1350, 11.11): run-qa.ps1 после прогона пишет kadry.txt
# (строка RUN и «шаг мс» по каждому снимку), publish-qa.ps1 кладёт его в qa/<папка>/ рядом с report.md, а сводка
# ПРОВЕРИТЬ в конце run-qa.ps1 по каждому шагу открытого «проверить»/«ждёт телефона» (и каждому провалу ≥ 100 мс сейчас)
# называет прошлые значения из папок qa/ клона и сколько тихих прогонов подряд он < 100 мс — без чтения трёх отчётов.
# Папка без kadry.txt (отчёты до него) — числа из раздела «## Частота кадров» report.md.
# Тихий прогон — помех 0 и ЦП < 50 % (по «остыванию», без -ColdBoot — по «до: ЦП»), как в docs/QA.md.
#   kadry.ps1 -SelfTest — проверка на выдуманных папках (её гоняет CI, job «Скрипты тестера»)
param([switch]$SelfTest)

$KadryLimit = 100     # провал кадра, мс
$KadryNeed = 3        # тихих прогонов подряд ниже предела, чтобы закрыть провал

# Строки log.txt → шаг → худший кадр, мс (строка «скриншот <шаг> | … · худший кадр N мс (…)», QaRunner)
function Read-Worst([string[]]$lines) {
  $out = [ordered]@{}
  foreach ($l in $lines) {
    if ($l -match '^скриншот (\S+) \|.* · худший кадр (\d+) мс') { $out[$Matches[1]] = [int]$Matches[2] }
  }
  return $out
}

function Test-Quiet([string]$runLine) {
  $noise = if ($runLine -match 'помехи: (\d+)') { [int]$Matches[1] } else { 0 }
  $cpu = 0
  if ($runLine -match 'остывание \d+ с \(ЦП (\d+)%\)') { $cpu = [int]$Matches[1] }
  elseif ($runLine -match 'до: ЦП (\d+)%') { $cpu = [int]$Matches[1] }
  return ($noise -eq 0 -and $cpu -lt 50)
}

function Write-Kadry([string]$path, [string]$runLine, $worst) {
  $lines = @($runLine) + @($worst.Keys | ForEach-Object { "$_ $($worst[$_])" })
  [IO.File]::WriteAllLines($path, [string[]]$lines, (New-Object Text.UTF8Encoding $false))
}

# Отчёты в qa/ клона, новые первыми: коммит, тихий ли, шаг → мс
function Read-Past([string]$qaDir, [int]$count = 8) {
  $runs = @()
  if (-not (Test-Path $qaDir)) { return ,$runs }
  $dirs = Get-ChildItem $qaDir -Directory | Where-Object Name -match '^\d{4}-\d\d-\d\d-\d{4}' | Sort-Object Name -Descending
  foreach ($d in $dirs) {
    $kadry = Join-Path $d.FullName 'kadry.txt'
    $report = Join-Path $d.FullName 'report.md'
    $worst = [ordered]@{}
    $run = ''
    if (Test-Path $kadry) {
      $lines = @(Get-Content $kadry -Encoding utf8)
      $run = "$($lines | Where-Object { $_ -match '^RUN ' } | Select-Object -First 1)"
      foreach ($l in $lines) { if ($l -match '^(\S+) (\d+)$') { $worst[$Matches[1]] = [int]$Matches[2] } }
    } elseif (Test-Path $report) {
      $text = (Get-Content $report -Raw -Encoding utf8) -replace "`r", ''
      if ($text -match '`(RUN [^`]+)`') { $run = $Matches[1] -replace '\s+', ' ' }
      $part = if ($text -match '(?s)\n## Частота кадров[^\n]*\n(.*?)(?=\n## |$)') { $Matches[1] } else { '' }
      # «`32o-mol-steklo` **144** (шаг …», «**`21a-vent` 81 мс**», «`22-itog` 100 (было 70)» — первое число у шага
      foreach ($m in [regex]::Matches($part, '`(\d[0-9a-z]*-[0-9a-z-]+)`\**\s+\**(\d+)\**(?=[\s,.;)]|$)')) {
        $s = $m.Groups[1].Value
        if (-not $worst.Contains($s)) { $worst[$s] = [int]$m.Groups[2].Value }
      }
    } else { continue }
    $commit = if ($run -match '^RUN (?:PR#\d+ )?([0-9a-f]{7})') { $Matches[1] }
      elseif ($d.Name -match '([0-9a-f]{7})$') { $Matches[1] } else { $d.Name }
    $runs += [pscustomobject]@{ Name = $d.Name; Commit = $commit; Quiet = (Test-Quiet $run); Worst = $worst }
    if ($runs.Count -ge $count) { break }
  }
  return ,$runs
}

# Шаг → «#519, #1665»: открытые issues «проверить» и «ждёт телефона», где шаг назван в заголовке или тексте.
# Метка — в адресе URL-кодом, jq без кавычек: Windows PowerShell 5.1 портит кириллицу и кавычки в аргументах gh.
function Get-IssueSteps([string[]]$steps) {
  $map = @{}
  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { return $map }
  foreach ($label in @('проверить', 'ждёт телефона')) {
    $q = [uri]::EscapeDataString($label)
    $rows = @(gh api "repos/garrimajo5/DeepDive/issues?state=open&per_page=100&labels=$q" --jq '.[] | select(.pull_request == null) | [.number, .title, .body] | @tsv' 2>$null)
    foreach ($r in $rows) {
      $n, $t = "$r" -split "`t", 2
      foreach ($s in $steps) {
        if ($t -match "(?<![0-9a-z-])$([regex]::Escape($s))(?![0-9a-z-])") {
          $map[$s] = @(@($map[$s]) + "#$n" | Where-Object { $_ } | Select-Object -Unique)
        }
      }
    }
  }
  return $map
}

# Строки сводки: «ПРОВЕРИТЬ 21a-vent 111 мс (#519) | раньше: 81 dc1a16c, 71 a27bd91, 87 219b2f1 шум | тихих < 100 подряд: 0 из 3»
function Get-WatchLines($now, [bool]$nowQuiet, $past, $issues) {
  $out = @()
  foreach ($s in @($now.Keys)) {
    $tag = if ($issues -and $issues.ContainsKey($s)) { " ($(@($issues[$s]) -join ', '))" } else { '' }
    if ($now[$s] -lt $KadryLimit -and -not $tag) { continue }
    $seq = @([pscustomobject]@{ Ms = $now[$s]; Quiet = $nowQuiet; Commit = '' })
    $seq += @($past | Where-Object { $_.Worst.Contains($s) } |
      ForEach-Object { [pscustomobject]@{ Ms = $_.Worst[$s]; Quiet = $_.Quiet; Commit = $_.Commit } })
    $streak = 0
    foreach ($e in $seq) {
      if (-not $e.Quiet) { continue }        # шумный прогон серию не продолжает и не рвёт
      if ($e.Ms -ge $KadryLimit) { break }
      $streak++
    }
    $before = @($seq | Select-Object -Skip 1 -First 4 | ForEach-Object { "$($_.Ms) $($_.Commit)$(if (-not $_.Quiet) { ' шум' })" })
    $was = if ($before) { $before -join ', ' } else { 'нет данных' }
    $now1 = if ($nowQuiet) { '' } else { ' шум' }
    $out += "ПРОВЕРИТЬ $s $($now[$s]) мс$now1$tag | раньше: $was | тихих < $KadryLimit подряд: $streak из $KadryNeed"
  }
  return ,$out
}

if ($SelfTest) {
  $bad = 0
  function Check([bool]$cond, [string]$what) { if (-not $cond) { Write-Output "FAIL $what"; $script:bad++ } else { Write-Output "ok $what" } }
  $root = Join-Path ([IO.Path]::GetTempPath()) ("kadry-" + [guid]::NewGuid().ToString('N'))
  $qa = Join-Path $root 'qa'
  New-Item -ItemType Directory -Force (Join-Path $qa '2026-11-11-1717-svezhaya-a27bd91') | Out-Null
  New-Item -ItemType Directory -Force (Join-Path $qa '2026-11-11-1921-svezhaya-dc1a16c') | Out-Null
  New-Item -ItemType Directory -Force (Join-Path $qa '2026-11-11-2018-svezhaya-b031182') | Out-Null
  New-Item -ItemType Directory -Force (Join-Path $qa 'archive') | Out-Null
  $utf8 = New-Object Text.UTF8Encoding $false
  # старый отчёт без kadry.txt — числа из «## Частота кадров», бюджет «199 / 340» в другом разделе не берётся
  [IO.File]::WriteAllText((Join-Path $qa '2026-11-11-1717-svezhaya-a27bd91/report.md'), (@(
    '# отчёт', '- Итог: `RUN a27bd91 done=True снимков 145 из 145 | помехи: 0 (свёрнута 0, чужих окон 0) | до: ЦП 12%, эмуляторов 1 |',
    '  после: ЦП 4%, эмуляторов 1 | остывание 10 с (ЦП 13%)`.', '## Что работает', '- Бюджет: `21a-vent` 199 / 340.',
    '## Частота кадров', '  `32o-mol-steklo` **102** (код 20 (мир 15; шаг 133 мс), отрисовка 80).',
    '- **`21a-vent` 71 мс** (шаг 341 hold) — второй (87 → 71).', '- `32o`: 103 → 124.', '## Ошибки', '- `21a-vent` 500') -join "`n"), $utf8)
  # шумный прогон (остывание 120 с, ЦП 64 %) — серию не рвёт
  [IO.File]::WriteAllText((Join-Path $qa '2026-11-11-1921-svezhaya-dc1a16c/kadry.txt'),
    "RUN dc1a16c done=True снимков 3 из 3 | помехи: 0 (свёрнута 0, чужих окон 0) | до: ЦП 70%, эмуляторов 1 | после: ЦП 3%, эмуляторов 1 | остывание 120 с (ЦП 64%)`n21a-vent 150`n32o-mol-steklo 151`n", $utf8)
  Write-Kadry (Join-Path $qa '2026-11-11-2018-svezhaya-b031182/kadry.txt') 'RUN b031182 done=True снимков 3 из 3 | помехи: 0 (свёрнута 0, чужих окон 0) | до: ЦП 9%, эмуляторов 1' ([ordered]@{ '21a-vent' = 81; '32o-mol-steklo' = 144 })

  $log = @('Сценарий: 3 шага, версия v0.1 · #1 c0ffee1, x',
    'скриншот 21a-vent | корабль (1, 2, 3) · худший кадр 62 мс (шаг 342 wait, код 29 мс)',
    'скриншот 32o-mol-steklo | x · худший кадр 120 мс (шаг 688 wait) · после прыжка 163 мс',
    'скриншот 01-start | x · худший кадр 49 мс (шаг 3)', 'скриншот 02-tiho | x')
  $now = Read-Worst $log
  Check ($now.Count -eq 3 -and $now['21a-vent'] -eq 62 -and $now['32o-mol-steklo'] -eq 120) 'Read-Worst: худший кадр, не «после прыжка»'
  Check (-not $now.Contains('02-tiho')) 'снимок без худшего кадра — без числа'
  Check (Test-Quiet 'RUN x | помехи: 0 (…) | до: ЦП 9%, эмуляторов 1') 'тихий: помех 0, ЦП 9 %'
  Check (-not (Test-Quiet 'RUN x | помехи: 2 (…) | до: ЦП 9%')) 'помехи — шумный'
  Check (-not (Test-Quiet 'RUN x | помехи: 0 | до: ЦП 9% | после: ЦП 3% | остывание 120 с (ЦП 64%)')) 'остывание важнее «до»'
  $past = Read-Past $qa
  Check ($past.Count -eq 3 -and $past[0].Commit -eq 'b031182' -and $past[2].Commit -eq 'a27bd91') 'Read-Past: новые первыми, без чужих папок'
  Check ($past[2].Worst['21a-vent'] -eq 71 -and $past[2].Worst['32o-mol-steklo'] -eq 102) 'report.md: числа из «Частоты кадров»'
  Check ($past[2].Quiet -and -not $past[1].Quiet) 'тихий по остыванию из отчёта, шумный — из kadry.txt'
  $w = Get-WatchLines $now $true $past @{ '21a-vent' = @('#519') }
  Check ($w.Count -eq 2) "две строки: шаг из issue и провал ≥ 100 ($($w -join ' / '))"
  Check ($w[0] -eq 'ПРОВЕРИТЬ 21a-vent 62 мс (#519) | раньше: 81 b031182, 150 dc1a16c шум, 71 a27bd91 | тихих < 100 подряд: 3 из 3') "21a-vent: $($w[0])"
  Check ($w[1] -eq 'ПРОВЕРИТЬ 32o-mol-steklo 120 мс | раньше: 144 b031182, 151 dc1a16c шум, 102 a27bd91 | тихих < 100 подряд: 0 из 3') "32o: $($w[1])"
  $w2 = Get-WatchLines ([ordered]@{ '21a-vent' = 70 }) $false $past @{ '21a-vent' = @('#519') }
  Check ($w2[0] -like 'ПРОВЕРИТЬ 21a-vent 70 мс шум (#519) |*подряд: 2 из 3') "шумный сейчас — не в счёт: $($w2[0])"
  Check ((Get-WatchLines ([ordered]@{ 'x-1' = 50 }) $true @() @{}).Count -eq 0) 'ниже предела и без issue — без строки'
  Check ((Get-WatchLines ([ordered]@{ '9-novyj' = 130 }) $true @() @{})[0] -like '*раньше: нет данных*') 'новый шаг — «нет данных»'
  Remove-Item -Recurse -Force $root
  if ($bad) { Write-Output "kadry.ps1: провалов $bad"; exit 1 }
  Write-Output 'kadry.ps1: всё верно'
}
