# Сдать отчёт тестера: ветка qa/<папка> от свежего main, отчёт и скриншоты (JPEG до ~300 КБ) в qa/<папка>/, пуш и PR.
# Использование: publish-qa.ps1 -Folder <ГГГГ-ММ-ДД-ЧЧММ-что> -Message "<сообщение коммита>" [-Shots 01-start,04-forward]
# report.md должен уже лежать в D:\AI\DeepDive\qa\<Folder>\report.md. Скриншоты берутся из D:\AI\qa-build\run\;
# -From <имя> — из другой папки прогона: run-pr<номер> после `run-qa.ps1 -Pr`, run-<сценарий> после -Scenario (#1606).
# -Also <имя> — kadry.txt второго прогона того же отчёта (напр. `-From run-cold -Also run`) кладётся рядом как kadry-2.txt:
# сводка ПРОВЕРИТЬ (kadry.ps1) считает его отдельным прогоном (#1350, 11.11).
param([Parameter(Mandatory)][string]$Folder, [Parameter(Mandatory)][string]$Message, [string[]]$Shots, [string]$From = 'run',
  [string]$Also)
$ErrorActionPreference = 'Stop'
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
$pngs = Get-ChildItem "$src\*.png"
# -Shots a,b,c через `powershell -File` приходит одной строкой «a,b,c» (#1350): разбиваем по запятой сами.
# Имена можно с расширением: «36b-ognecvet-posle.jpg» — то же, что «36b-ognecvet-posle» (#1533).
$Shots = @($Shots | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() -replace '\.(jpe?g|png)$', '' } |
  Where-Object { $_ })
if ($Shots) {
  $pngs = $pngs | Where-Object { $Shots -contains $_.BaseName }
  $miss = $Shots | Where-Object { $_ -notin @($pngs | ForEach-Object BaseName) }
  if (-not $pngs) { throw "Ни одного снимка из -Shots ($($Shots -join ', ')) нет в $src" }
  if ($miss) { Write-Warning "Нет снимков: $($miss -join ', ')" }
}
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
Write-Output "PUSHED $branch $sha (файлов $($files.Count))"
Write-Output "RAW https://raw.githubusercontent.com/garrimajo5/DeepDive/$sha/qa/$Folder/"
