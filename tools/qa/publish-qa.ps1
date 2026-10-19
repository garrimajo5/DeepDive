# Сдать отчёт тестера: ветка qa/<папка> от свежего main, отчёт и скриншоты (JPEG до ~300 КБ) в qa/<папка>/, пуш и PR.
# Использование: publish-qa.ps1 -Folder <ГГГГ-ММ-ДД-ЧЧММ-что> -Message "<сообщение коммита>" [-Shots 01-start,04-forward]
# report.md должен уже лежать в D:\AI\DeepDive\qa\<Folder>\report.md. Скриншоты берутся из D:\AI\qa-build\run\.
param([Parameter(Mandatory)][string]$Folder, [Parameter(Mandatory)][string]$Message, [string[]]$Shots)
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
$pngs = Get-ChildItem 'D:\AI\qa-build\run\*.png'
if ($Shots) { $pngs = $pngs | Where-Object { $Shots -contains $_.BaseName } }
foreach ($f in $pngs) {
  $img = [System.Drawing.Image]::FromFile($f.FullName)
  $w = [Math]::Min(1600, $img.Width); $h = [int]($img.Height * $w / $img.Width)
  $bmp = New-Object System.Drawing.Bitmap $img, $w, $h
  $bmp.Save((Join-Path $dir ($f.BaseName + '.jpg')), $codec, $ep)
  $bmp.Dispose(); $img.Dispose()
}

git -C $repo add -A "qa/$Folder"
git -C $repo -c user.name=garrimajo5 -c user.email=garrimajo5@users.noreply.github.com commit -q -m $Message -m 'Co-Authored-By: Claude <noreply@anthropic.com>'
git -C $repo push -q -u origin $branch
if (Get-Command gh -ErrorAction SilentlyContinue) {
  gh pr create -R garrimajo5/DeepDive --base main --head $branch --title "Отчёт тестера: $Folder" --body "Отчёт: qa/$Folder/report.md"
} else {
  Write-Output "gh не установлен: PR откроет Claude (ветка $branch)"
}
git -C $repo checkout -q main
Write-Output "PUSHED $branch"
