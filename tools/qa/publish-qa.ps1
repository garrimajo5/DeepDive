# Сдать отчёт тестера: ветка qa/<папка> от свежего main, отчёт и скриншоты (JPEG до ~300 КБ) в qa/<папка>/, пуш и PR.
# Использование: publish-qa.ps1 -Folder <ГГГГ-ММ-ДД-ЧЧММ-что> -Message "<сообщение коммита>" [-Shots 01-start,04-forward]
# report.md должен уже лежать в D:\AI\DeepDive\qa\<Folder>\report.md. Скриншоты берутся из D:\AI\qa-build\run\;
# -From <имя> — из другой папки прогона: run-pr<номер> после `run-qa.ps1 -Pr`, run-<сценарий> после -Scenario (#1606).
# -Also <имя> — kadry.txt второго прогона того же отчёта (напр. `-From run-cold -Also run`) кладётся рядом как kadry-2.txt:
# сводка ПРОВЕРИТЬ (kadry.ps1) считает его отдельным прогоном (#1350, 11.11).
# В -Shots имя с папкой (`run-koridor/k1-drain-z6`) — снимок из D:\AI\qa-build\run-koridor\, без папки — из -From:
# кадры второго прогона того же отчёта без ручного копирования (#1350, 12.11).
#   publish-qa.ps1 -SelfTest — проверка выбора снимков на временных папках (её гоняет CI, job «Скрипты тестера»)
param([string]$Folder, [string]$Message, [string[]]$Shots, [string]$From = 'run', [string]$Also, [switch]$SelfTest)
$ErrorActionPreference = 'Stop'

# Снимки для отчёта: $shots пусто — все *.png папки $root\$from; иначе по именам. «a,b» одной строкой (`powershell -File`,
# #1350) разбивается по запятой, расширение отбрасывается (#1533), «папка/имя» или «папка\имя» — из $root\папка.
# Одно имя из двух папок — ошибка (JPEG в отчёте называется по имени снимка); ни одного найденного — ошибка.
function Resolve-QaShots([string]$root, [string]$from, [string[]]$shots) {
  $names = @($shots | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() -replace '\.(jpe?g|png)$', '' } |
    Where-Object { $_ })
  if (-not $names) { return @(Get-ChildItem (Join-Path (Join-Path $root $from) '*.png')) }
  $found = @(); $miss = @()
  foreach ($n in $names) {
    $parts = @($n -split '[\\/]' | Where-Object { $_ })
    $dir = if ($parts.Count -gt 1) { $parts[0..($parts.Count - 2)] -join [IO.Path]::DirectorySeparatorChar } else { $from }
    $png = Join-Path (Join-Path $root $dir) ($parts[-1] + '.png')
    if (Test-Path $png) { $found += Get-Item $png } else { $miss += $n }
  }
  if (-not $found) { throw "Ни одного снимка из -Shots ($($names -join ', ')) нет в $root" }
  $dups = @($found | Group-Object BaseName | Where-Object Count -gt 1 | ForEach-Object Name)
  if ($dups) { throw "Снимок с одним именем из двух папок: $($dups -join ', ')" }
  if ($miss) { Write-Warning "Нет снимков: $($miss -join ', ')" }
  return $found
}

if ($SelfTest) {
  $bad = 0
  function Check([bool]$cond, [string]$what) { if (-not $cond) { Write-Output "FAIL $what"; $script:bad++ } else { Write-Output "ok $what" } }
  $root = Join-Path ([IO.Path]::GetTempPath()) ("publish-" + [guid]::NewGuid().ToString('N'))
  # Вход: run\a.png, run\b.png, run-k\k1.png, run-k\a.png (содержимое не читается — только имена)
  foreach ($f in @('run/a', 'run/b', 'run-k/k1', 'run-k/a')) {
    $p = Join-Path $root ($f + '.png'); New-Item -ItemType Directory -Force (Split-Path $p -Parent) | Out-Null
    [IO.File]::WriteAllText($p, 'x')
  }
  function Pick($shots) { @(Resolve-QaShots $root 'run' $shots | ForEach-Object { "$(Split-Path $_.DirectoryName -Leaf)/$($_.BaseName)" }) -join ' ' }
  # без -Shots — вся папка -From: «run/a run/b»
  Check ((Pick @()) -eq 'run/a run/b') "без -Shots — вся папка: $(Pick @())"
  # «a,run-k/k1» одной строкой: a — из -From, k1 — из run-k → «run/a run-k/k1»
  Check ((Pick @('a,run-k/k1')) -eq 'run/a run-k/k1') "имя с папкой — из своей папки: $(Pick @('a,run-k/k1'))"
  # обратная косая и расширение: «run-k\k1.jpg» → «run-k/k1»
  Check ((Pick @('run-k\k1.jpg')) -eq 'run-k/k1') "папка через \ и расширение: $(Pick @('run-k\k1.jpg'))"
  # «b, run-k/a» — разные имена из двух папок, порядок -Shots → «run/b run-k/a»
  Check ((Pick @('b', 'run-k/a')) -eq 'run/b run-k/a') "две папки в одном отчёте: $(Pick @('b', 'run-k/a'))"
  # «a, run-k/a» — одно имя a.jpg из двух папок → ошибка
  $err = ''; try { Pick @('a', 'run-k/a') | Out-Null } catch { $err = "$_" }
  Check ($err -like '*одним именем*') "одно имя из двух папок — ошибка: $err"
  # «zz, run-k/zz» — ничего нет → ошибка
  $err = ''; try { Pick @('zz', 'run-k/zz') | Out-Null } catch { $err = "$_" }
  Check ($err -like 'Ни одного снимка*') "ни одного снимка — ошибка: $err"
  # «a, run-x/q» — найден один, второго нет → предупреждение, отдаётся «run/a»
  Check ((Pick @('a', 'run-x/q') 3>$null) -eq 'run/a') 'часть не нашлась — остальные идут'
  Remove-Item -Recurse -Force $root
  if ($bad) { Write-Output "publish-qa.ps1 -SelfTest: провалов $bad"; exit 1 }
  Write-Output 'publish-qa.ps1 -SelfTest: ok'
  exit 0
}

if (-not $Folder -or -not $Message) { throw 'Нужны -Folder и -Message' }
$repo = 'D:\AI\DeepDive'
$dir = Join-Path $repo "qa\$Folder"
if (-not (Test-Path "$dir\report.md")) { throw "Нет report.md в $dir" }
$branch = "qa/$Folder"
# Замок (#1350, 12.11): два publish-qa.ps1 в одном клоне переключали друг другу ветку — обе ветки ушли пустыми.
# Второй — строка BUSY и выход; коммит — в своём git worktree, рабочая копия клона и её ветка не трогаются.
. (Join-Path $PSScriptRoot 'zamok.ps1')
$lockFile = 'D:\AI\qa-build\publish-qa.lock'
$busy = Lock-Qa $lockFile "publish-qa.ps1 $Folder"
if ($busy) { Write-Output $busy; exit 2 }
$wt = "D:\AI\qa-build\publish-wt"
git -C $repo fetch -q origin main
# Хвост прошлой сдачи, оборванной на полпути (замок уже снят — процесс умер)
if (Test-Path $wt) {
  try { git -C $repo worktree remove --force $wt 2>$null } catch { }
  Remove-Item -Recurse -Force $wt -ErrorAction SilentlyContinue
}
git -C $repo worktree prune
git -C $repo worktree add -q --force -B $branch $wt origin/main
if ($LASTEXITCODE) { throw "git worktree add $wt не удался" }

# Скриншоты: PNG эмулятора 2400x1080 -> JPEG 1600 px по ширине, качество 80 (обычно 150–300 КБ)
Add-Type -AssemblyName System.Drawing
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
$ep = New-Object System.Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 80L
$src = "D:\AI\qa-build\$From"
if (-not (Test-Path $src)) { throw "Нет папки прогона $src (-From)" }
$pngs = Resolve-QaShots 'D:\AI\qa-build' $From $Shots
foreach ($f in $pngs) {
  $img = [System.Drawing.Image]::FromFile($f.FullName)
  $w = [Math]::Min(1600, $img.Width); $h = [int]($img.Height * $w / $img.Width)
  $bmp = New-Object System.Drawing.Bitmap $img, $w, $h
  $bmp.Save((Join-Path $dir ($f.BaseName + '.jpg')), $codec, $ep)
  $bmp.Dispose(); $img.Dispose()
}

# kadry.txt (худший кадр по шагам, run-qa.ps1) — рядом с отчётом: сводка ПРОВЕРИТЬ следующих прогонов берёт числа из него
if (Test-Path "$src\kadry.txt") { Copy-Item "$src\kadry.txt" (Join-Path $dir 'kadry.txt') -Force }
if ($Also) {
  $also = "D:\AI\qa-build\$Also\kadry.txt"
  if (-not (Test-Path $also)) { throw "Нет $also (-Also)" }
  Copy-Item $also (Join-Path $dir 'kadry-2.txt') -Force
}

# Папка отчёта — в worktree ветки отчёта; коммит, пуш и SHA — там же
$dst = Join-Path $wt "qa\$Folder"
New-Item -ItemType Directory -Force $dst | Out-Null
Copy-Item "$dir\*" $dst -Recurse -Force
git -C $wt add -A "qa/$Folder"
git -C $wt -c user.name=garrimajo5 -c user.email=garrimajo5@users.noreply.github.com commit -q -m $Message -m 'Co-Authored-By: Claude <noreply@anthropic.com>'
if ($LASTEXITCODE) { throw "коммит в $wt не удался (нечего коммитить?)" }
$sha = (git -C $wt rev-parse HEAD).Trim()
git -C $wt push -q -u origin $branch
if ($LASTEXITCODE) { throw "push $branch не удался" }
# Сверка: на сервере ветка указывает на наш коммит, и в нём есть report.md
$remote = "$(git -C $repo ls-remote origin "refs/heads/$branch")".Split()[0]
if ($remote -ne $sha) { throw "на сервере $branch = $remote, а не $sha" }
$files = @(git -C $wt show --name-only --format= $sha | Where-Object { $_ -like "qa/$Folder/*" })
if ($files -notcontains "qa/$Folder/report.md") { throw "в коммите $sha нет qa/$Folder/report.md" }
if (Get-Command gh -ErrorAction SilentlyContinue) {
  gh pr create -R garrimajo5/DeepDive --base main --head $branch --title "Отчёт тестера: $Folder" --body "Отчёт: qa/$Folder/report.md"
} else {
  Write-Output "gh не установлен: PR откроет Claude (ветка $branch)"
}
git -C $repo worktree remove --force $wt
# Отчёт живёт в ветке: копия в клоне не нужна и после слияния помешала бы git pull (раньше её убирал checkout main)
Remove-Item -Recurse -Force $dir
Unlock-Qa $lockFile
# Хвост латиницей: строку читают и разбирают в консоли Windows, где кириллица после SHA ломается (#1350, 13.11)
Write-Output "PUSHED $branch $sha (files $($files.Count))"
Write-Output "RAW https://raw.githubusercontent.com/garrimajo5/DeepDive/$sha/qa/$Folder/"
