# Сдать отчёт тестера: ветка qa/<папка> от свежего main, отчёт и скриншоты (JPEG до ~300 КБ) в qa/<папка>/, пуш и PR.
# Использование: publish-qa.ps1 -Folder <ГГГГ-ММ-ДД-ЧЧММ-что> -Message "<сообщение коммита>" [-Shots 01-start,04-forward]
# report.md должен уже лежать в D:\AI\DeepDive\qa\<Folder>\report.md. Скриншоты берутся из D:\AI\qa-build\run\;
# -From <имя> — из другой папки прогона: run-pr<номер> после `run-qa.ps1 -Pr`, run-<сценарий> после -Scenario (#1606).
param([Parameter(Mandatory)][string]$Folder, [Parameter(Mandatory)][string]$Message, [string[]]$Shots, [string]$From = 'run')
$ErrorActionPreference = 'Stop'
$repo = 'D:\AI\DeepDive'
$dir = Join-Path $repo "qa\$Folder"
if (-not (Test-Path "$dir\report.md")) { throw "Нет report.md в $dir" }
$branch = "qa/$Folder"
git -C $repo fetch -q origin main
git -C $repo checkout -q -B $branch origin/main

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

git -C $repo add -A "qa/$Folder"
git -C $repo -c user.name=garrimajo5 -c user.email=garrimajo5@users.noreply.github.com commit -q -m $Message -m 'Co-Authored-By: Claude <noreply@anthropic.com>'
git -C $repo push -q -u origin $branch
# SHA коммита отчёта — до возврата на main (потом `git rev-parse HEAD` даёт коммит main, #1533)
$sha = (git -C $repo rev-parse HEAD).Trim()
if (Get-Command gh -ErrorAction SilentlyContinue) {
  gh pr create -R garrimajo5/DeepDive --base main --head $branch --title "Отчёт тестера: $Folder" --body "Отчёт: qa/$Folder/report.md"
} else {
  Write-Output "gh не установлен: PR откроет Claude (ветка $branch)"
}
git -C $repo checkout -q main
Write-Output "PUSHED $branch $sha"
Write-Output "RAW https://raw.githubusercontent.com/garrimajo5/DeepDive/$sha/qa/$Folder/"
