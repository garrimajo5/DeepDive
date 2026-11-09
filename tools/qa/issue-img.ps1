# Картинка (или звук) прямо в issue без Python (#1379) — то же, что tools/issue_img.py: кладёт файлы в ветку-сироту
# issue-img (папка = номер issue) одним коммитом и пишет в issue комментарий со встроенными картинками.
#
#   powershell -ExecutionPolicy Bypass -File tools\qa\issue-img.ps1 576 qa\out\27-power.png "Рукава у пульта"
#   powershell -ExecutionPolicy Bypass -File tools\qa\issue-img.ps1 576 v1.png "Вариант 1" v2.png "Вариант 2" -Text "Какой берём?"
#
# Нужен git (как для publish-qa.ps1); комментарий пишет gh. Без gh файлы всё равно уходят в ветку, а текст
# комментария печатается — вставить его в issue в браузере. Рабочая папка и текущая ветка не меняются: коммит
# собирается во временном индексе (GIT_INDEX_FILE). PNG больше 900 КБ пережимается в JPEG 85 %.
# Имя файла в ветке — латиница, цифры, «.», «-», «_» (кириллица в аргументах git в PowerShell 5.1 ломается).
param(
  [Parameter(Position = 0, Mandatory = $true)][int]$Issue,
  [string]$Text = '',
  [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Rest
)
$ErrorActionPreference = 'Stop'
$repoSlug = 'garrimajo5/DeepDive'
$branch = 'issue-img'
$maxBytes = 900000
$audio = @('.mp3', '.wav', '.ogg')
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Fail([string]$msg) { Write-Output "ERROR: $msg"; exit 1 }

function Git-Out {
  $out = & git -C $repo @args
  if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') -> $LASTEXITCODE" }
  return ("$out").Trim()
}

function Safe-Name([string]$path, [int]$i) {
  $base = [IO.Path]::GetFileNameWithoutExtension($path) -replace '[^A-Za-z0-9._-]', '-'
  $base = ($base -replace '-+', '-').Trim('-')
  if ($base -eq '') { $base = "img-$i" }
  return $base + [IO.Path]::GetExtension($path).ToLower()
}

# Пара (путь к файлу для git, имя в ветке): крупный PNG — во временный JPEG.
function Shrink([string]$path, [string]$name, [string]$tmp) {
  $ext = [IO.Path]::GetExtension($name)
  if ((Get-Item $path).Length -le $maxBytes -or $audio -contains $ext) { return @($path, $name) }
  try {
    Add-Type -AssemblyName System.Drawing
    $img = [Drawing.Image]::FromFile((Resolve-Path $path).Path)
    $w = [Math]::Min($img.Width, 1920)
    $h = [int][Math]::Round($img.Height * $w / $img.Width)
    $bmp = New-Object Drawing.Bitmap $img, $w, $h
    $codec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    $par = New-Object Drawing.Imaging.EncoderParameters 1
    $par.Param[0] = New-Object Drawing.Imaging.EncoderParameter ([Drawing.Imaging.Encoder]::Quality), 85L
    $jpgName = [IO.Path]::GetFileNameWithoutExtension($name) + '.jpg'
    $out = Join-Path $tmp $jpgName
    $bmp.Save($out, $codec, $par)
    $bmp.Dispose(); $img.Dispose()
    return @($out, $jpgName)
  } catch {
    return @($path, $name)
  }
}

# Разбор: путь, за ним подпись, если следующий аргумент — не существующий файл (как в issue_img.py).
$pairs = @()
$list = @($Rest | Where-Object { $_ -ne $null })
$k = 0
while ($k -lt $list.Count) {
  $path = $list[$k]; $k++
  $caption = ''
  if ($k -lt $list.Count -and -not (Test-Path -LiteralPath $list[$k] -PathType Leaf)) { $caption = $list[$k]; $k++ }
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Fail "нет файла $path" }
  $pairs += , @($path, $caption)
}
if ($pairs.Count -eq 0) { Fail 'нужен хотя бы один файл: issue-img.ps1 <номер> <файл> "подпись"' }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("issue-img-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $tmp | Out-Null
$files = @()
for ($i = 0; $i -lt $pairs.Count; $i++) {
  $s = Shrink $pairs[$i][0] (Safe-Name $pairs[$i][0] ($i + 1)) $tmp
  $files += , @($s[0], $s[1], $pairs[$i][1])
}

# Коммит в ветку issue-img во временном индексе; кто-то запушил одновременно — ещё раз (до 3 попыток).
$pushed = $false
for ($attempt = 0; $attempt -lt 3 -and -not $pushed; $attempt++) {
  $env:GIT_INDEX_FILE = Join-Path $tmp 'index'
  try {
    if (Test-Path $env:GIT_INDEX_FILE) { Remove-Item $env:GIT_INDEX_FILE }
    $head = (Git-Out ls-remote origin "refs/heads/$branch") -split "`t" | Select-Object -First 1
    if ($head) {
      Git-Out fetch -q origin "refs/heads/$branch" | Out-Null
      Git-Out read-tree "$head^{tree}" | Out-Null
    }
    foreach ($f in $files) {
      $blob = Git-Out hash-object -w -- $f[0]
      Git-Out update-index --add --cacheinfo "100644,$blob,$Issue/$($f[1])" | Out-Null
    }
    $tree = Git-Out write-tree
    $msg = "issue-img #${Issue}: " + (($files | ForEach-Object { $_[1] }) -join ', ')
    if ($head) { $commit = Git-Out commit-tree $tree -p $head -m $msg } else { $commit = Git-Out commit-tree $tree -m $msg }
  } finally {
    Remove-Item Env:\GIT_INDEX_FILE -ErrorAction SilentlyContinue
  }
  & git -C $repo push -q origin "${commit}:refs/heads/$branch"
  if ($LASTEXITCODE -eq 0) { $pushed = $true }
}
if (-not $pushed) { Fail "не удалось запушить ветку $branch" }

# Текст комментария: вступление, по картинке с подписью; звук — ссылкой «▶ послушать».
$parts = @()
if ($Text.Trim() -ne '') { $parts += $Text.Trim() }
foreach ($f in $files) {
  $name = $f[1]; $caption = $f[2]
  $url = "https://raw.githubusercontent.com/$repoSlug/$branch/$Issue/$name"
  if ($audio -contains [IO.Path]::GetExtension($name)) {
    $label = $caption; if ($label -eq '') { $label = $name }
    $parts += "**$label** — [▶ послушать ``$name``]($url)"
  } elseif ($caption -ne '') {
    $parts += "**$caption**`n`n![$caption]($url)"
  } else {
    $parts += "![$name]($url)"
  }
}
$body = $parts -join "`n`n"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  Write-Output "gh не установлен: файлы в ветке $branch, вставьте текст в комментарий issue #$Issue в браузере:"
  Write-Output ''
  Write-Output $body
  exit 0
}
$json = Join-Path $tmp 'comment.json'
# JSON без BOM: gh читает тело как есть.
[IO.File]::WriteAllText($json, (@{ body = $body } | ConvertTo-Json -Compress), (New-Object Text.UTF8Encoding $false))
$url = & gh api -X POST "repos/$repoSlug/issues/$Issue/comments" --input $json --jq '.html_url'
if ($LASTEXITCODE -ne 0) { Fail "gh api: комментарий не записан (файлы уже в ветке $branch)" }
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
Write-Output $url
