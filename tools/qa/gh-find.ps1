# gh без PATH сессии (#1350, тестер 18.11): GitHub CLI ставится в Machine PATH, но сессия, запущенная до
# установки (или со своим PATH), его не видит — прогон и сдача отчёта не должны от этого зависеть.
# Подключается из run-qa.ps1, kadry.ps1 и publish-qa.ps1.
# Возвращает 'gh' (команда доступна — из PATH или подставная функция SelfTest), полный путь из стандартного
# места установки или '' — тогда вызывающий пишет свою строку «gh не найден». $std — параметр для SelfTest.
function Find-Gh([string]$std = 'C:\Program Files\GitHub CLI\gh.exe') {
  if (Get-Command gh -ErrorAction SilentlyContinue) { return 'gh' }
  if ($std -and (Test-Path $std)) { return $std }
  return ''
}
