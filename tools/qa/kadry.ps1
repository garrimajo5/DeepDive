# Худший кадр по шагам для правила трёх тихих прогонов (#1350, 11.11): run-qa.ps1 после прогона пишет kadry.txt
# (строка RUN и «шаг мс» по каждому снимку), publish-qa.ps1 кладёт его в qa/<папка>/ рядом с report.md, а сводка
# ПРОВЕРИТЬ в конце run-qa.ps1 по каждому шагу открытого «проверить»/«ждёт телефона» (и каждому провалу ≥ 100 мс сейчас)
# называет прошлые значения из папок qa/ клона и сколько тихих прогонов подряд он < 100 мс — без чтения трёх отчётов.
# Папка без kadry.txt (отчёты до него) — числа из раздела «## Частота кадров» report.md. kadry-2.txt — второй прогон
# того же отчёта (publish-qa.ps1 -Also). Отчёты ещё не слитых PR (ветки qa/*) — тоже в счёт: Export-QaBranches.
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

# Чужие окна поверх игры (#1350, 12.11): запуски чужой активности в logcat («START u0 {» не нашего пакета) — до конца
# сценария и после него. Конец — строка «Готово» QaRunner (он печатает строки лога в logcat: «I godot : QA …»; порядок
# строк logcat — время); её нет (игра упала, не дошла) — последняя строка «QA …», нет и их — все окна в счёт сценария.
# В помехи идут только окна сценария: Chrome от com.android.shell через 0,5–2 мин после него прогон шумом не делает.
function Split-Foreign([string[]]$logcat, [string]$app) {
  $last = -1
  for ($i = 0; $i -lt $logcat.Count; $i++) {
    if ($logcat[$i] -match ' godot\s*: QA Готово') { $last = $i; break }
    if ($logcat[$i] -match ' godot\s*: QA ') { $last = $i }
  }
  $during = 0; $after = 0
  for ($i = 0; $i -lt $logcat.Count; $i++) {
    $l = $logcat[$i]
    if ($l -notmatch 'START u0 \{' -or $l.Contains($app)) { continue }
    if ($last -ge 0 -and $i -gt $last) { $after++ } else { $during++ }
  }
  return [pscustomobject]@{ During = $during; After = $after }
}

# Сколько раз игру свернули посреди сценария (строка QaRunner.PAUSED_LINE в log.txt) — до строки «Готово»: свернули
# после неё (чужое окно после сценария) — не помеха (#1350, 12.11)
function Count-Paused([string[]]$log) {
  $n = 0
  foreach ($l in $log) {
    if ($l -match '^Готово') { break }
    if ($l -match '^игра свёрнута') { $n++ }
  }
  return $n
}

function Write-Kadry([string]$path, [string]$runLine, $worst) {
  $lines = @($runLine) + @($worst.Keys | ForEach-Object { "$_ $($worst[$_])" })
  [IO.File]::WriteAllLines($path, [string[]]$lines, (New-Object Text.UTF8Encoding $false))
}

# kadry.txt → строка RUN и шаг → мс
function Read-KadryFile([string]$path) {
  $lines = @(Get-Content $path -Encoding utf8)
  $worst = [ordered]@{}
  foreach ($l in $lines) { if ($l -match '^(\S+) (\d+)$') { $worst[$Matches[1]] = [int]$Matches[2] } }
  return [pscustomobject]@{ Run = "$($lines | Where-Object { $_ -match '^RUN ' } | Select-Object -First 1)"; Worst = $worst }
}

# Отчёты в папках qa/ (клон и отчёты открытых PR — Export-QaBranches), новые первыми: коммит, тихий ли, шаг → мс.
# Папка с тем же именем в нескольких местах берётся один раз — из первого. kadry-2.txt (второй прогон того же
# отчёта, publish-qa.ps1 -Also) — отдельным прогоном сразу за kadry.txt.
function Read-Past([string[]]$qaDirs, [int]$count = 8) {
  $runs = @()
  $seen = @{}
  $dirs = @()
  foreach ($q in $qaDirs) {
    if (-not $q -or -not (Test-Path $q)) { continue }
    foreach ($d in @(Get-ChildItem $q -Directory | Where-Object Name -match '^\d{4}-\d\d-\d\d-\d{4}')) {
      if ($seen.ContainsKey($d.Name)) { continue }
      $seen[$d.Name] = $true
      $dirs += $d
    }
  }
  $dirs = @($dirs | Sort-Object Name -Descending)
  foreach ($d in $dirs) {
    $kadry = Join-Path $d.FullName 'kadry.txt'
    $kadry2 = Join-Path $d.FullName 'kadry-2.txt'
    $report = Join-Path $d.FullName 'report.md'
    $found = @()
    if (Test-Path $kadry) {
      $found += Read-KadryFile $kadry
      if (Test-Path $kadry2) { $found += Read-KadryFile $kadry2 }
    } elseif (Test-Path $report) {
      $worst = [ordered]@{}
      $run = ''
      $text = (Get-Content $report -Raw -Encoding utf8) -replace "`r", ''
      if ($text -match '`(RUN [^`]+)`') { $run = $Matches[1] -replace '\s+', ' ' }
      $part = if ($text -match '(?s)\n## Частота кадров[^\n]*\n(.*?)(?=\n## |$)') { $Matches[1] } else { '' }
      # «`32o-mol-steklo` **144** (шаг …», «**`21a-vent` 81 мс**», «`22-itog` 100 (было 70)» — первое число у шага
      foreach ($m in [regex]::Matches($part, '`(\d[0-9a-z]*-[0-9a-z-]+)`\**\s+\**(\d+)\**(?=[\s,.;)]|$)')) {
        $s = $m.Groups[1].Value
        if (-not $worst.Contains($s)) { $worst[$s] = [int]$m.Groups[2].Value }
      }
      $found += [pscustomobject]@{ Run = $run; Worst = $worst }
    } else { continue }
    foreach ($f in $found) {
      $commit = if ($f.Run -match '^RUN (?:PR#\d+ )?([0-9a-f]{7})') { $Matches[1] }
        elseif ($d.Name -match '([0-9a-f]{7})$') { $Matches[1] } else { $d.Name }
      $runs += [pscustomobject]@{ Name = $d.Name; Commit = $commit; Quiet = (Test-Quiet $f.Run); Worst = $f.Worst }
      if ($runs.Count -ge $count) { return ,$runs }
    }
  }
  return ,$runs
}

# Отчёты, ещё не слитые в main (ветки qa/* открытых PR), — в $dest/<папка>/: только report.md и kadry*.txt.
# Без этого сводка сразу после сдачи прошлого отчёта не видела его чисел (#1350, 11.11). Возвращает $dest.
# Файлы — через `git archive -o` (zip пишет сам git): вывод git show в Windows PowerShell 5.1 портит кириллицу.
function Export-QaBranches([string]$repo, [string]$dest) {
  if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
  New-Item -ItemType Directory -Force $dest | Out-Null
  git -C $repo fetch -q origin '+refs/heads/qa/*:refs/remotes/origin/qa/*' 2>$null
  $refs = @(git -C $repo for-each-ref --format='%(refname:short)' refs/remotes/origin/qa/ 2>$null)
  foreach ($r in $refs) {
    $name = "$r" -replace '^origin/qa/', ''
    if ($name -notmatch '^\d{4}-\d\d-\d\d-\d{4}[^/]*$') { continue }
    $paths = @(git -C $repo ls-tree -r --name-only $r "qa/$name/" 2>$null |
      Where-Object { $_ -match '/(report\.md|kadry(-\d)?\.txt)$' })
    if (-not $paths) { continue }
    $zip = Join-Path $dest "$name.zip"
    git -C $repo archive --format=zip -o $zip $r @paths 2>$null
    if ($LASTEXITCODE -or -not (Test-Path $zip)) { continue }
    $tmp = Join-Path $dest "$name.tmp"
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    Move-Item (Join-Path $tmp "qa/$name") (Join-Path $dest $name)
    Remove-Item -Recurse -Force $tmp, $zip
  }
  return $dest
}

# Шаг → «#519, #1665»: открытые issues «проверить» и «ждёт телефона», где шаг назван в заголовке, тексте или
# комментариях (у #1709 шаги были только в комментарии — сводка их не увидела, #1350, 13.11); комментарии читаются
# отдельным запросом и только у issues, где они есть; не прочитались — шаги берутся из заголовка и текста.
# Метка — в адресе URL-кодом, jq без кавычек: Windows PowerShell 5.1 портит кириллицу и кавычки в аргументах gh.
# Что прочитано — строкой $script:IssueNote («ISSUES «проверить» 12, «ждёт телефона» 4 | шаги: 32o-mol-steklo #1665»),
# run-qa.ps1 печатает её под сводкой: сводка без строк ПРОВЕРИТЬ при открытых issues (#1350, 12.11, отчёт ea2758d)
# сама говорит, gh не нашёлся, упал или шаги не совпали.
$script:IssueNote = ''
function Get-IssueSteps([string[]]$steps) {
  $map = @{}
  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    $script:IssueNote = 'ISSUES gh не найден — шаги открытых «проверить»/«ждёт телефона» не сопоставлены'
    return $map
  }
  $notes = @()
  foreach ($label in @('проверить', 'ждёт телефона')) {
    $q = [uri]::EscapeDataString($label)
    $global:LASTEXITCODE = 0
    $all = @(gh api "repos/garrimajo5/DeepDive/issues?state=open&per_page=100&labels=$q" --jq '.[] | select(.pull_request == null) | [.number, .comments, .title, .body] | @tsv' 2>&1)
    $code = $LASTEXITCODE
    $errs = @($all | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
    $rows = @($all | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] -and "$_" -match '^\d+\t\d+\t' })
    if ($code -or ($errs -and -not $rows)) {
      $why = if ($errs) { ("$($errs[0])" -split "`n")[0].Trim() } else { '' }
      $notes += "«$label» ошибка gh (код $code) $why".TrimEnd()
      continue
    }
    $notes += "«$label» $($rows.Count)"
    foreach ($r in $rows) {
      $n, $c, $t = "$r" -split "`t", 3
      if ([int]$c -gt 0) {
        $cm = @(gh api "repos/garrimajo5/DeepDive/issues/$n/comments?per_page=100" --jq '.[].body' 2>&1 |
          Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })
        $t = "$t`t$($cm -join ' ')"
      }
      foreach ($s in $steps) {
        if ($t -match "(?<![0-9a-z-])$([regex]::Escape($s))(?![0-9a-z-])") {
          $map[$s] = @(@($map[$s]) + "#$n" | Where-Object { $_ } | Select-Object -Unique)
        }
      }
    }
  }
  $hit = @($map.Keys | Sort-Object | ForEach-Object { "$_ $(@($map[$_]) -join ',')" })
  $script:IssueNote = "ISSUES $($notes -join ', ') | шаги: $(if ($hit) { $hit -join '; ' } else { 'ни один шаг прогона не назван' })"
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
  $app = 'com.garrimajo5.deepdive'
  $cat = @('11-12 02:28:00.100 500 500 I ActivityManager: START u0 {act=android.intent.action.MAIN cmp=com.garrimajo5.deepdive/.Main}',
    '11-12 02:28:05.000 600 600 I godot   : QA скриншот 01-start | x',
    '11-12 02:29:00.000 500 500 I ActivityManager: START u0 {act=android.intent.action.VIEW dat=http://127.0.0.1:4200/... cmp=com.android.chrome/...} from uid 2000',
    '11-12 02:31:00.000 600 600 I godot   : QA скриншот 99-konec | x',
    '11-12 02:31:01.000 600 600 I godot   : QA Готово | x',
    '11-12 02:32:10.000 500 500 I ActivityManager: START u0 {act=android.intent.action.VIEW dat=http://127.0.0.1:4211/#play cmp=com.android.chrome/...} from uid 2000',
    '11-12 02:33:00.000 500 500 I ActivityManager: START u0 {cmp=com.android.chrome/...}')
  $sf = Split-Foreign $cat $app
  Check ($sf.During -eq 1 -and $sf.After -eq 2) "Split-Foreign: окно в сценарии 1, после последней строки 2 ($($sf.During)/$($sf.After))"
  $sf1 = Split-Foreign ($cat + @('11-12 02:32:11.000 600 600 I godot   : QA игра свёрнута (OnPause)')) $app
  Check ($sf1.During -eq 1 -and $sf1.After -eq 2) 'Split-Foreign: «свёрнута» после «Готово» конец не сдвигает'
  $sf2 = Split-Foreign @($cat[0], $cat[1], $cat[2], $cat[3], $cat[5]) $app
  Check ($sf2.During -eq 1 -and $sf2.After -eq 1) 'Split-Foreign: нет «Готово» — конец по последней строке QA'
  Check ((Count-Paused @('a', 'игра свёрнута (OnPause)', 'игра снова на экране', 'Готово | x', 'игра свёрнута (OnPause)')) -eq 1) 'Count-Paused: после «Готово» не в счёт'
  $sf0 = Split-Foreign @($cat[0], $cat[2]) $app
  Check ($sf0.During -eq 1 -and $sf0.After -eq 0) 'Split-Foreign: строк сценария нет — все окна в сценарии'
  Check (Test-Quiet 'RUN x | помехи: 0 (свёрнута 0, чужих окон 0) | после сценария: 2 | до: ЦП 9% | остывание 0 с (ЦП 12%)') 'окна после сценария — тихий'
  Check (-not (Test-Quiet 'RUN x | помехи: 0 | до: ЦП 9% | остывание 0 с (ЦП 71%)')) 'без -ColdBoot: ЦП к началу сценария ≥ 50 % — шумный'
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
  # Get-IssueSteps на подставном gh (функция перекрывает gh.exe): шаг из заголовка и тела, строка ISSUES (#1350, 12.11)
  # Строки подставного: номер, число комментариев, заголовок, тело. У #1709 шаг 33-tablo-il назван только в комментарии
  # (их два, #1350, 13.11); у #519 комментариев нет — запроса комментариев к нему быть не должно.
  # Метка в адресе URL-кодом: «проверить» начинается с %D0%BF, «ждёт телефона» — с %D0%B6.
  # Ошибку gh подставной отдаёт объектом ErrorRecord в вывод, не Write-Error: pwsh в Actions — $ErrorActionPreference stop.
  function gh {
    $global:LASTEXITCODE = 0
    if ("$($args[1])" -match '/issues/(\d+)/comments') {
      $script:asked += $Matches[1]
      if ($Matches[1] -eq '1709') { 'приёмка UX'; 'смотреть шаг 33-tablo-il на устройстве' }
      return
    }
    if ("$($args[1])" -match 'labels=%D0%BF') {
      "1665`t0`tПровал кадра у колодца (32o-mol-steklo)`tтело"
      "519`t0`tПровал`tшаги 21a-vent и 32o-mol-steklo"
      "1709`t2`tТревоги ила`tбез шагов"
    } else { "803`t0`tПровал на 31b-kod-net`t" }
  }
  $script:asked = @()
  $im = Get-IssueSteps @('32o-mol-steklo', '21a-vent', '31b-kod-net', '01-start', '32o', '33-tablo-il')
  # ждём: 32o-mol-steklo → #1665 и #519, 21a-vent → #519, 31b-kod-net → #803, 33-tablo-il → #1709 (из комментария);
  # 01-start и «32o» (часть имени) — нет; комментарии спрошены только у #1709
  Check ((@($im['32o-mol-steklo']) -join ',') -eq '#1665,#519' -and (@($im['21a-vent']) -join ',') -eq '#519' -and (@($im['31b-kod-net']) -join ',') -eq '#803') "Get-IssueSteps: шаги из заголовка и тела ($(@($im.Keys | ForEach-Object { "$_=$(@($im[$_]) -join ',')" }) -join ' '))"
  Check ((@($im['33-tablo-il']) -join ',') -eq '#1709') "Get-IssueSteps: шаг из комментария ($(@($im['33-tablo-il']) -join ','))"
  Check (($script:asked -join ',') -eq '1709') "комментарии — только у issues, где они есть: $($script:asked -join ',')"
  Check (-not $im.ContainsKey('01-start') -and -not $im.ContainsKey('32o')) 'Get-IssueSteps: шаг без issue и часть имени — нет'
  Check ($script:IssueNote -eq 'ISSUES «проверить» 3, «ждёт телефона» 1 | шаги: 21a-vent #519; 31b-kod-net #803; 32o-mol-steklo #1665,#519; 33-tablo-il #1709') "строка ISSUES: $($script:IssueNote)"
  $wi = Get-WatchLines ([ordered]@{ '32o-mol-steklo' = 32; '01-start' = 40 }) $true @() $im
  Check ($wi.Count -eq 1 -and $wi[0] -like 'ПРОВЕРИТЬ 32o-mol-steklo 32 мс (#1665, #519) |*') "шаг из issue ниже 100 мс — строка есть: $($wi -join ' / ')"
  function gh {
    $global:LASTEXITCODE = 1
    [System.Management.Automation.ErrorRecord]::new([Exception]::new('HTTP 401: Bad credentials'), 'gh', 'NotSpecified', $null)
  }
  $im2 = Get-IssueSteps @('32o-mol-steklo')
  Check ($im2.Count -eq 0 -and $script:IssueNote -like 'ISSUES «проверить» ошибка gh (код 1) HTTP 401: Bad credentials, «ждёт телефона» ошибка gh (код 1)*| шаги: ни один*') "gh упал — причина в строке ISSUES: $($script:IssueNote)"
  Remove-Item function:gh

  # kadry-2.txt — второй прогон того же отчёта, сразу за kadry.txt
  $q2 = Join-Path $root 'qa2'
  New-Item -ItemType Directory -Force (Join-Path $q2 '2026-11-12-0226-svezhaya-a7246c2') | Out-Null
  New-Item -ItemType Directory -Force (Join-Path $q2 '2026-11-11-2018-svezhaya-b031182') | Out-Null
  Write-Kadry (Join-Path $q2 '2026-11-12-0226-svezhaya-a7246c2/kadry.txt') 'RUN a7246c2 done=True | помехи: 0 | до: ЦП 12%' ([ordered]@{ '21a-vent' = 90 })
  Write-Kadry (Join-Path $q2 '2026-11-12-0226-svezhaya-a7246c2/kadry-2.txt') 'RUN a7246c2 done=True | помехи: 0 | до: ЦП 21%' ([ordered]@{ '21a-vent' = 95 })
  Write-Kadry (Join-Path $q2 '2026-11-11-2018-svezhaya-b031182/kadry.txt') 'RUN b031182 дубль | помехи: 5' ([ordered]@{ '21a-vent' = 999 })
  $past2 = Read-Past @($qa, $q2, (Join-Path $root 'net'))
  Check ($past2.Count -eq 5 -and $past2[0].Commit -eq 'a7246c2' -and $past2[0].Worst['21a-vent'] -eq 90 -and $past2[1].Worst['21a-vent'] -eq 95) "kadry-2.txt — отдельный прогон за kadry.txt ($(@($past2 | ForEach-Object { "$($_.Commit) $($_.Worst['21a-vent'])" }) -join ', '))"
  Check ($past2[2].Commit -eq 'b031182' -and $past2[2].Worst['21a-vent'] -eq 81) 'та же папка в двух местах — из первого'
  Check ((Read-Past @($qa, $q2) 2).Count -eq 2) 'предел прогонов считает и kadry-2.txt'

  # отчёт открытой PR: ветка qa/<папка> в origin — Export-QaBranches кладёт report.md и kadry*.txt, без снимков
  if (Get-Command git -ErrorAction SilentlyContinue) {
    $bare = Join-Path $root 'origin.git'; $clone = Join-Path $root 'clone'
    git init -q --bare $bare
    git clone -q $bare $clone 2>$null
    $g = @('-C', $clone, '-c', 'user.name=t', '-c', 'user.email=t@t')
    git -C $clone symbolic-ref HEAD refs/heads/main
    [IO.File]::WriteAllText((Join-Path $clone 'README.md'), 'x', $utf8)
    git @g add -A; git @g commit -q -m init; git @g push -q origin main 2>$null
    $f = '2026-11-12-0300-svezhaya-abc1234'
    git @g checkout -q -b "qa/$f"
    New-Item -ItemType Directory -Force (Join-Path $clone "qa/$f") | Out-Null
    Write-Kadry (Join-Path $clone "qa/$f/kadry.txt") 'RUN abc1234 done=True | помехи: 0 | до: ЦП 9%' ([ordered]@{ '32o-mol-steklo' = 88 })
    [IO.File]::WriteAllText((Join-Path $clone "qa/$f/report.md"), '# отчёт — кириллица', $utf8)
    [IO.File]::WriteAllText((Join-Path $clone "qa/$f/01-start.jpg"), 'jpg', $utf8)
    git @g add -A; git @g commit -q -m qa; git @g push -q origin "qa/$f" 2>$null
    git @g checkout -q main
    git @g branch -q -D "qa/$f"
    git -C $clone update-ref -d "refs/remotes/origin/qa/$f" 2>$null
    $pr = Export-QaBranches $clone (Join-Path $root 'pr')
    Check (Test-Path (Join-Path $pr "$f/kadry.txt")) 'Export-QaBranches: kadry.txt из ветки qa/*'
    Check (-not (Test-Path (Join-Path $pr "$f/01-start.jpg"))) 'Export-QaBranches: снимки не берёт'
    Check ((Get-Content (Join-Path $pr "$f/report.md") -Raw -Encoding utf8) -eq '# отчёт — кириллица') 'Export-QaBranches: кириллица цела'
    $past3 = Read-Past @((Join-Path $clone 'qa'), $pr)
    Check ($past3.Count -eq 1 -and $past3[0].Commit -eq 'abc1234' -and $past3[0].Worst['32o-mol-steklo'] -eq 88) 'Read-Past: отчёт открытой PR в сводке'
  } else { Write-Output 'git нет — Export-QaBranches не проверен' }
  Remove-Item -Recurse -Force $root
  if ($bad) { Write-Output "kadry.ps1: провалов $bad"; exit 1 }
  Write-Output 'kadry.ps1: всё верно'
}
