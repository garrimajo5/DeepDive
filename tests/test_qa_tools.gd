extends TestCase
## Скрипты тестера tools/qa/*.ps1: Windows PowerShell 5.1 читает UTF-8 без BOM как ANSI,
## и кириллица в строках ломает разбор (issue #37). Каждый .ps1 должен начинаться с BOM.

const DIR := "res://tools/qa"


func _ps1_files() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".ps1"):
			out.append(DIR.path_join(f))
	return out


func test_ps1_found() -> void:
	ok(_ps1_files().size() >= 2, "нашли run-qa.ps1 и publish-qa.ps1")


func test_ps1_start_with_bom() -> void:
	for path in _ps1_files():
		var b := FileAccess.get_file_as_bytes(path)
		ok(b.size() >= 3 and b[0] == 0xEF and b[1] == 0xBB and b[2] == 0xBF, "UTF-8 с BOM: %s" % path)


func test_ps1_valid_utf8() -> void:
	for path in _ps1_files():
		var b := FileAccess.get_file_as_bytes(path)
		var text := b.slice(3).get_string_from_utf8()
		ok(text.length() > 0 and text.contains("\n"), "читается как UTF-8: %s" % path)
		ok(not text.contains("﻿"), "BOM один, в начале: %s" % path)


## run-qa.ps1 ждёт done.txt N × 2 с. Сценарий рос, и ожидания (90 × 2 с) перестало хватать:
## при долгом прогреве после установки игра не доходила до конца (отчёт 2026-10-26-1233, done=False).
## Время сценария — сумма ожиданий и удержаний; сверху четверть на шаги и кадры и 30 с на запуск и прогрев.
func test_run_qa_waits_for_whole_scenario() -> void:
	var ps := FileAccess.get_file_as_bytes(DIR.path_join("run-qa.ps1")).slice(3).get_string_from_utf8()
	var re := RegEx.create_from_string("for \\(\\$i = 0; \\$i -lt (\\d+); \\$i\\+\\+\\) \\{\\s*\\n\\s*Start-Sleep (\\d+)")
	var m := re.search(ps)
	ok(m != null, "цикл ожидания done.txt найден")
	if m == null:
		return
	var budget := int(m.get_string(1)) * int(m.get_string(2))
	var steps: Array = JSON.parse_string(FileAccess.get_file_as_string(DIR.path_join("scenario.json")))
	var timed := 0.0
	for st in steps:
		if st.get("do", "") in ["wait", "hold", "drain", "swipe"]:
			timed += float(st.get("s", 0.0))
	var need := timed * 1.25 + 30.0
	ok(need <= budget, "ожидание %d с покрывает сценарий ~%.0f с" % [budget, need])


## #844: телефону — APK только с arm64-v8a, эмулятору тестера — отдельный только с x86_64 (≈27 МБ меньше на телефоне).
func test_two_apks_phone_and_emulator() -> void:
	var cfg := ConfigFile.new()
	eq(cfg.load("res://export_presets.cfg"), OK, "пресеты читаются")
	var arch := {}
	for i in 2:
		var sec := "preset.%d" % i
		var o := sec + ".options"
		arch[cfg.get_value(sec, "name")] = [cfg.get_value(o, "architectures/arm64-v8a"),
			cfg.get_value(o, "architectures/x86_64"), cfg.get_value(sec, "export_path")]
	eq(arch.get("Android"), [true, false, "build/DeepDive.apk"], "телефон — только arm64-v8a")
	eq(arch.get("Android эмулятор"), [false, true, "build/DeepDive-emulator.apk"], "эмулятор — только x86_64")
	var ci := FileAccess.get_file_as_string("res://.github/workflows/godot.yml")
	ok(ci.contains("--export-debug \"Android эмулятор\" build/DeepDive-emulator.apk"), "CI собирает APK эмулятора")
	ok(ci.contains("build/DeepDive.apk build/DeepDive-emulator.apk --clobber"), "в релиз — оба")
	var run := FileAccess.get_file_as_string("res://tools/qa/run-qa.ps1")
	ok(run.contains("'DeepDive-emulator.apk'"), "run-qa.ps1 ставит на эмулятор x86_64-сборку")


## #1125: релиз перезаливался, скачивание упало (BlobNotFound), а скрипт поставил прошлый APK из папки
## и записал прогон под новым коммитом. Теперь старый файл удаляется до скачивания, ошибка — выход до установки.
func test_run_qa_stops_when_download_fails() -> void:
	var ps := FileAccess.get_file_as_bytes(DIR.path_join("run-qa.ps1")).slice(3).get_string_from_utf8()
	var dl := ps.find("Get-Asset $asset.browser_download_url $apk")
	ok(dl > 0, "скачивание APK из релиза есть")
	var rm := ps.rfind("Remove-Item $apk", dl)
	ok(rm > 0 and rm < dl, "старый APK удаляется до скачивания")
	ok(ps.contains("Invoke-WebRequest $url -OutFile $path -Headers @{ 'User-Agent' = 'run-qa' } -ErrorAction Stop"),
		"ошибка скачивания ловится")
	var fail := ps.find("DOWNLOAD_FAILED", dl)
	var inst := ps.find("adb install")
	ok(fail > 0 and fail < inst, "при ошибке — выход до установки")
	ok(ps.find("exit 1", fail) < inst, "выход с кодом 1")
	ok(ps.find("last-commit.txt\" $head") > inst, "коммит записывается только после установки")


## #1504: APK эмулятора приходил обрезанным (110 МиБ из 114), а скрипт сверял только «не меньше 1 МБ» —
## установка падала INSTALL_PARSE_FAILED_NOT_APK. Теперь длина сверяется с размером в релизе, обрыв — докачка
## и до трёх попыток; так же качается APK телефона (-Phone).
func test_run_qa_checks_apk_size() -> void:
	var ps := FileAccess.get_file_as_bytes(DIR.path_join("run-qa.ps1")).slice(3).get_string_from_utf8()
	ok(not ps.contains("-lt 1MB"), "проверки «не меньше 1 МБ» больше нет")
	var fn := ps.find("function Get-Asset")
	ok(fn > 0, "скачивание со сверкой — одна функция")
	var body := ps.substr(fn, ps.find("\n}\n", fn) - fn)
	ok(body.contains("for ($try = 1; $try -le 3; $try++)"), "до трёх попыток")
	ok(body.contains("if ($got -eq $size) { return '' }"), "успех — только при длине, равной размеру в релизе")
	ok(body.contains("-C -"), "обрыв — докачка с места обрыва")
	ok(not body.contains("Write-Output"), "попытки не смешиваются с ответом функции")
	var emu := ps.find("Get-Asset $asset.browser_download_url $apk $asset.size")
	ok(emu > fn, "APK эмулятора качается со сверкой длины")
	var phone := ps.find("Get-Asset $asset.browser_download_url $file $asset.size")
	ok(phone > fn and ps.rfind("name -eq 'DeepDive.apk'", phone) > fn, "APK телефона — тоже")
	ok(ps.contains("[switch]$Phone"), "ключ -Phone")
	var fail := ps.find("DOWNLOAD_FAILED", emu)
	ok(fail > emu and fail < ps.find("adb install"), "расхождение — выход до установки")


## #1393: проба «QA на эмуляторе» в Actions закрыта (вторая попытка в Compatibility — игра не стартовала, снимка
## нет): workflow удалён, внешний action эмулятора был разрешён только на пробу — в workflow его больше нет.
func test_emulator_probe_closed() -> void:
	ok(not FileAccess.file_exists("res://.github/workflows/qa-emulator.yml"), "workflow пробы удалён")
	for f in DirAccess.get_files_at("res://.github/workflows"):
		var wf := FileAccess.get_file_as_string("res://.github/workflows".path_join(f))
		ok(not wf.contains("android-emulator-runner"), "нет action эмулятора: " + f)


## #1350: `publish-qa.ps1 -Shots a,b,c` через `powershell -File` приходит одной строкой — фильтр не находил ни
## одного снимка, и отчёт уходил без скриншотов молча. Теперь строка разбивается по запятой, без снимков — ошибка.
func test_publish_qa_splits_shots() -> void:
	var ps := FileAccess.get_file_as_bytes(DIR.path_join("publish-qa.ps1")).slice(3).get_string_from_utf8()
	var split := ps.find("-split ','")
	var filt := ps.find("$Shots -contains")
	ok(split > 0 and split < filt, "-Shots разбивается по запятой до фильтра")
	var fail := ps.find("throw", filt)
	ok(fail > 0 and fail < ps.find("foreach ($f in $pngs)"), "без снимков — ошибка до сжатия и коммита")


## #1350: эмулятор закрывался вместе с фоновым run-qa.ps1 посреди ручной проверки. Запуск — через WMI
## (процесс не потомок скрипта), а не Start-Process.
func test_run_qa_emulator_outlives_script() -> void:
	var ps := FileAccess.get_file_as_bytes(DIR.path_join("run-qa.ps1")).slice(3).get_string_from_utf8()
	ok(ps.contains("Invoke-CimMethod Win32_Process -MethodName Create"), "эмулятор — отвязанным процессом")
	ok(not ps.contains("Start-Process \"$sdk\\emulator"), "не потомком скрипта")


## #1379: картинка в issue без Python — issue-img.ps1 делает то же, что tools/issue_img.py: ветка-сирота issue-img,
## коммит во временном индексе (рабочая папка не трогается), ссылки raw.githubusercontent в той же папке номера.
func test_issue_img_ps1_mirrors_python() -> void:
	var path := DIR.path_join("issue-img.ps1")
	ok(FileAccess.file_exists(path), "issue-img.ps1 есть")
	var ps := FileAccess.get_file_as_bytes(path).slice(3).get_string_from_utf8()
	var py := FileAccess.get_file_as_string("res://tools/issue_img.py")
	ok(py.contains("BRANCH = \"issue-img\"") and ps.contains("$branch = 'issue-img'"), "та же ветка, что у issue_img.py")
	ok(ps.contains("https://raw.githubusercontent.com/$repoSlug/$branch/$Issue/$name"), "ссылка как raw_url в Python")
	ok(ps.contains("$repoSlug = 'garrimajo5/DeepDive'"), "тот же репозиторий")
	for step in ["GIT_INDEX_FILE", "hash-object -w", "update-index --add --cacheinfo", "commit-tree", "push -q origin"]:
		ok(ps.contains(step), "git без checkout: %s" % step)
	ok(ps.contains("Remove-Item Env:\\GIT_INDEX_FILE"), "временный индекс снимается — следующий git работает с обычным")
	ok(ps.contains("[^A-Za-z0-9._-]"), "имя в ветке — латиницей")
	ok(ps.contains("UTF8Encoding $false"), "JSON комментария без BOM")
	ok(ps.contains("Get-Command gh"), "без gh — печатает текст комментария")
	var qa := FileAccess.get_file_as_string("res://docs/QA.md")
	ok(qa.contains("tools\\qa\\issue-img.ps1"), "docs/QA.md называет PowerShell-вариант")


func _ps(name: String) -> String:
	return FileAccess.get_file_as_bytes(DIR.path_join(name)).slice(3).get_string_from_utf8()


## #1533: прогон 800+ шагов не укладывался в 195 × 2 с, скрипт не забирал последние снимки и done.txt —
## тестер добирал их руками. Теперь ждём ≥ 600 с, добираем, пока снимков меньше строк «скриншот» в логе,
## и в конце печатаем NOT_DONE со списком пропавших.
func test_run_qa_waits_and_reports_not_done() -> void:
	var ps := _ps("run-qa.ps1")
	var m := RegEx.create_from_string("for \\(\\$i = 0; \\$i -lt (\\d+); \\$i\\+\\+\\) \\{\\s*\\n\\s*Start-Sleep (\\d+)").search(ps)
	ok(m != null and int(m.get_string(1)) * int(m.get_string(2)) >= 600, "ожидание done.txt не меньше 600 с")
	ok(ps.contains("Write-Output \"NOT_DONE $head"), "в конце — строка NOT_DONE")
	ok(ps.rfind("NOT_DONE") > ps.rfind("Write-Output \"files: $run\""), "NOT_DONE — после всего вывода")
	# шаблон строки снимка в скрипте ловит то, что пишет qa_runner.gd, и не ловит «нет картинки»
	var pat := RegEx.create_from_string("-match '(\\^скриншот [^']+)'").search(ps)
	ok(pat != null, "шаблон строки снимка найден")
	if pat == null:
		return
	var runner := FileAccess.get_file_as_string("res://scripts/game/qa_runner.gd")
	ok(runner.contains("_log(\"скриншот %s | %s\""), "qa_runner пишет «скриншот <имя> | …»")
	var re := RegEx.create_from_string(pat.get_string(1))
	var hit := re.search("скриншот 36b-ognecvet-posle | корабль (0, -30, 0)")
	ok(hit != null and hit.get_string(1) == "36b-ognecvet-posle", "имя снимка из строки лога")
	ok(re.search("скриншот 01-start: нет картинки (headless)") == null, "строка без картинки не в счёт")


## #1533: SHA ветки отчёта — до возврата клона на main; -Shots принимает имена с .jpg/.png.
func test_publish_qa_sha_and_extensions() -> void:
	var ps := _ps("publish-qa.ps1")
	var sha := ps.find("$sha = (git -C $repo rev-parse HEAD)")
	ok(sha > 0 and sha < ps.find("git -C $repo checkout -q main"), "SHA берётся до возврата на main")
	ok(ps.contains("Write-Output \"PUSHED $branch $sha\""), "PUSHED печатает SHA")
	ok(ps.contains("raw.githubusercontent.com/garrimajo5/DeepDive/$sha/qa/$Folder/"), "готовый raw-префикс")
	var m := RegEx.create_from_string("-replace '([^']+)', ''").search(ps)
	ok(m != null, "расширение отрезается")
	if m == null:
		return
	var re := RegEx.create_from_string(m.get_string(1))
	for n in ["36b-ognecvet-posle.jpg", "36b-ognecvet-posle.png", "36b-ognecvet-posle.jpeg", "36b-ognecvet-posle"]:
		eq(re.sub(n, ""), "36b-ognecvet-posle", "имя снимка: %s" % n)


## #1350: шумный прогон отличать фактом — загрузка ЦП хоста и число процессов эмулятора до установки сценария и
## после прогона; итог одной строкой RUN (сборка, done, снимки, нагрузка) — в выводе и в конце log.txt.
func test_run_qa_logs_host_load() -> void:
	var ps := _ps("run-qa.ps1")
	ok(ps.contains("function Get-Load") and ps.contains("LoadPercentage") and ps.contains("qemu-system-*"),
		"нагрузка: ЦП и процессы эмулятора")
	var before := ps.find("$loadBefore = Get-Load")
	var after := ps.find("$loadAfter = Get-Load")
	ok(before > 0 and before < ps.find("monkey -p $app"), "«до» — перед запуском игры")
	ok(after > ps.find("function Get-Out"), "«после» — когда забрали снимки")
	var res := ps.find("$result = \"RUN $head done=$done")
	ok(res > after, "итоговая строка RUN называет сборку")
	ok(ps.find("Add-Content \"$run\\log.txt\" \"run-qa: $result\"", res) > res, "итог — и в конец log.txt")
	ok(ps.rfind("NOT_DONE") > res, "NOT_DONE остаётся последней строкой")


## #1350: в облачной сессии pwsh нет — синтаксис скриптов тестера проверяет CI (ubuntu-раннер несёт pwsh),
## и «Тесты» зелёные, только если проверка прошла.
func test_ci_parses_ps1() -> void:
	var ci := FileAccess.get_file_as_string("res://.github/workflows/godot.yml")
	ok(ci.contains("[System.Management.Automation.Language.Parser]::ParseFile"), "CI разбирает .ps1 парсером PowerShell")
	ok(ci.contains("tools/qa/*.ps1"), "все скрипты тестера")
	ok(ci.contains("needs: [changes, test-parts, ps1]"), "итог «Тесты» ждёт проверку скриптов")
	ok(ci.contains("needs.ps1.result }}\" = \"success\""), "и валится, если она красная")


## #1350: пуш в main сравнивается с коммитом последнего зелёного прогона «Godot» на main, а не с прошлым пушем:
## иначе код из отменённого прогона уходил непроверенным, если следом сливали коммит без кода.
func test_ci_main_diff_from_last_green() -> void:
	var ci := FileAccess.get_file_as_string("res://.github/workflows/godot.yml")
	ok(ci.contains("actions/workflows/godot.yml/runs?branch=main&status=success"), "база — последний зелёный прогон main")
	ok(ci.contains("actions: read"), "у job есть право читать прогоны")
