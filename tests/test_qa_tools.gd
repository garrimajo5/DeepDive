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
	var sha := ps.find("$sha = (git -C $wt rev-parse HEAD)")
	ok(sha > 0 and sha < ps.find("git -C $wt push"), "SHA коммита отчёта — в worktree, до пуша")
	ok(not ps.contains("checkout -q"), "ветка клона не переключается (#1350, 12.11)")
	ok(ps.contains("Write-Output \"PUSHED $branch $sha"), "PUSHED печатает SHA")
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


## #1592: шумный прогон эмулятора отличать от регрессии по итогу RUN — помехи (игру свернули, чужое окно поверх),
## STALE_APK (скачался прошлый APK), -ColdBoot (эмулятор заново без снимка), сценарий из ветки PR.
func test_run_qa_noise_stale_coldboot() -> void:
	var ps := _ps("run-qa.ps1")
	ok(ps.contains("[switch]$ColdBoot"), "ключ -ColdBoot")
	var kill := ps.find("& $adb emu kill")
	ok(kill > 0 and kill < ps.find("emulator.exe"), "-ColdBoot закрывает эмулятор до запуска")
	ok(ps.contains("-avd Pixel_8$cold") and ps.contains("' -no-snapshot-load'"), "холодный старт без снимка состояния")
	ok(ps.contains("помехи: $noise"), "помехи — в итоге RUN")
	ok(ps.find("$result = \"RUN $head done=$done") < ps.find("помехи: $noise") , "помехи — в самой строке RUN")
	# шаблон паузы ловит строку, которую пишет QaRunner
	var pat := RegEx.create_from_string("-Pattern '(\\^игра свёрнута)'").search(ps)
	ok(pat != null, "шаблон паузы найден")
	if pat != null:
		ok(RegEx.create_from_string(pat.get_string(1)).search(QaRunner.PAUSED_LINE) != null, "ловит QaRunner.PAUSED_LINE")
		ok(RegEx.create_from_string(pat.get_string(1)).search(QaRunner.RESUMED_LINE) == null, "возврат не в счёт")
	ok(ps.contains("-notmatch [regex]::Escape($app)"), "своя активность — не помеха")
	# STALE_APK: шаблон версии ловит первую строку лога (Main.version_text из version.txt CI)
	var vm := RegEx.create_from_string("\\$first -match '([^']+)'").search(ps)
	ok(vm != null, "шаблон версии найден")
	if vm != null:
		var re := RegEx.create_from_string(vm.get_string(1))
		var hit := re.search("Сценарий: 812 шагов, версия v0.3 · #1043 a5dcbe0, sdk_gphone64_x86_64")
		ok(hit != null and hit.get_string(1) == "a5dcbe0", "коммит из первой строки лога")
		ok(re.search("Сценарий: 812 шагов, версия v0.3 · dev, PC") == null, "сборка без version.txt — не сверяется")
	var runner := FileAccess.get_file_as_string("res://scripts/game/qa_runner.gd")
	ok(runner.contains("_log(\"Сценарий: %d шагов, версия %s, %s\""), "первая строка лога — версия")
	ok(FileAccess.get_file_as_string("res://.github/workflows/godot.yml").contains("echo \"#${{ github.run_number }} ${GITHUB_SHA::7}\" > version.txt"),
		"version.txt CI — «#сборка коммит»")
	ok(ps.contains("STALE_APK $head $built"), "STALE_APK <ожидался> <получен>")
	ok(ps.contains("if (-not $Pr -and -not $stale) { Set-Content \"$build\\last-commit.txt\" $head }"),
		"чужой APK не помечается проверенным")
	# -Pr: сценарий из ветки PR
	var pr := ps.find("contents/${inBranch}?ref=$prSha")
	ok(pr > 0 and pr < ps.find("ConvertFrom-Json"), "сценарий ветки PR скачан до разбора")
	ok(ps.contains("'tools/qa/scenario.json'"), "без -Scenario — сценарий тестера из ветки")
	ok(ps.contains("Write-Output \"NO_SCENARIO"), "нет файла в ветке — NO_SCENARIO")
	var qa := FileAccess.get_file_as_string("res://docs/QA.md")
	for k in ["-ColdBoot", "STALE_APK", "помехи: N", "NO_SCENARIO"]:
		ok(qa.contains(k), "docs/QA.md: %s" % k)


## #1350 (11.11): после -ColdBoot хост ещё занят загрузкой эмулятора — скрипт ждёт три замера ЦП подряд < 50 %
## (до 120 с) перед запуском игры, сколько ждали и замер выхода — в итоге RUN; без -ColdBoot не ждёт.
func test_run_qa_cools_after_coldboot() -> void:
	var ps := _ps("run-qa.ps1")
	ok(ps.contains("function Get-Cpu"), "ЦП отдельной функцией")
	var wait := ps.find("while ($true) {")
	ok(wait > 0, "цикл остывания")
	var loop := ps.substr(wait, ps.find("$cool = \" | остывание", wait) - wait)
	ok(loop.contains("$cpu = Get-Cpu") and loop.contains("if ($cpu -lt 50) { $calm++ } else { $calm = 0 }"),
			"замеры подряд ниже 50 %: высокий сбрасывает счёт (один низкий среди 64 % и 56 % — не остыл)")
	ok(loop.contains("if ($calm -ge 3 -or $waited -ge 120) { break }"), "три замера подряд, не дольше 120 с")
	ok(loop.contains("Start-Sleep 5; $waited += 5"), "замер раз в 5 с")
	ok(ps.contains("остывание $waited с (ЦП $cpu%)"), "в итоге — замер, по которому вышли, а не новый")
	var guard := ps.rfind("if ($ColdBoot) {", wait)
	ok(guard > 0 and wait - guard < 80, "ждём только после -ColdBoot")
	ok(wait > ps.find("adb install -r -d $apk"), "после установки APK")
	ok(wait < ps.find("$loadBefore = Get-Load") and wait < ps.find("monkey -p $app"), "до запуска игры")
	ok(ps.contains("$cool = \" | остывание $waited с"), "строка «остывание N с»")
	ok(ps.contains("после: $loadAfter$cool\""), "в итоге RUN")
	ok(FileAccess.get_file_as_string("res://docs/QA.md").contains("остывание N с"), "docs/QA.md: остывание")


## #1592: игру свернули посреди прогона — строка в логе (её считает run-qa.ps1); без сценария — молчит.
func test_runner_logs_pause() -> void:
	var r := QaRunner.new()
	r._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	eq(r.log_lines.size(), 0, "без сценария — без строк")
	r.free()


## #1606: прогон PR рядом с плановым — сборка PR ниже стоящей ставится (-d), результат в своей папке (плановый run\
## не затирается, publish-qa.ps1 -From берёт снимки оттуда), NO_ARTIFACT — только при пустом списке артефактов.
func test_run_qa_pr_beside_planned() -> void:
	var ps := _ps("run-qa.ps1")
	ok(ps.contains("install -r -d $apk"), "установка с понижением версии (-d)")
	ok(not ps.contains("install -r $apk"), "без -d установок нет")
	ok(ps.contains("[string]$Out)"), "ключ -Out")
	ok(not RegEx.create_from_string("\\$out\\b").search(ps.replace("$Out", "")), "$out не путается с -Out (PowerShell не различает регистр)")
	ok(ps.contains("\"run-pr$Pr\""), "-Pr — своя папка run-pr<номер>")
	var made := ps.find("$run   = \"$build\\$Out\"")
	ok(made > 0 and made < ps.find("Remove-Item -Recurse -Force $run"), "папка выбрана до очистки")
	var arts := ps.find("/artifacts\" --jq '.artifacts[].name'")
	var none := ps.find("Write-Output \"NO_ARTIFACT")
	ok(arts > 0 and arts < none, "NO_ARTIFACT — по списку артефактов прогона")
	ok(ps.find("gh run download $rid -R garrimajo5/DeepDive") > none, "скачивание — с явным репозиторием, после проверки")
	ok(ps.contains("Push-Location $repo"), "gh — из клона")
	ok(ps.contains("Write-Output \"DOWNLOAD_FAILED PR#"), "артефакт есть, но не скачался — не NO_ARTIFACT")
	ok(ps.contains("actions/workflows/godot.yml/runs?head_sha="), "прогон — именно «Godot»")
	var pub := _ps("publish-qa.ps1")
	ok(pub.contains("[string]$From = 'run'"), "publish-qa.ps1 -From, по умолчанию run")
	ok(pub.contains("Get-ChildItem \"$src\\*.png\""), "снимки — из папки -From")
	ok(not pub.contains("qa-build\\run\\*.png"), "без жёсткого run\\")
	var qa := FileAccess.get_file_as_string("res://docs/QA.md")
	for k in ["-Out", "-From", "run-pr", "-r -d"]:
		ok(qa.contains(k), "docs/QA.md: %s" % k)


## #1614: папка результата чистилась в начале скрипта — NO_RUN у `-Pr` оставлял пустую run-pr<номер>\, а NO_CHANGES
## планового стирал несданные снимки run\. Теперь — только перед самим прогоном, после всех ранних выходов.
func test_run_qa_resets_folder_before_run() -> void:
	var ps := _ps("run-qa.ps1")
	var fn := ps.find("function Reset-Run")
	ok(fn > 0, "чистка папки — функцией")
	ok(ps.find("Remove-Item -Recurse -Force $run") > fn, "Remove-Item $run — только внутри Reset-Run")
	ok(ps.count("Remove-Item -Recurse -Force $run") == 1, "и нигде больше")
	var reset := ps.rfind("Reset-Run")
	for early in ["NO_RUN:", "NO_ARTIFACT:", "NO_CHANGES", "DOWNLOAD_FAILED PR#", "NO_ASSET ${head}", "NO_PR #"]:
		var at := ps.find(early)
		ok(at > 0 and at < reset, "%s — до чистки папки" % early)
	ok(reset < ps.find("$loadBefore = Get-Load"), "эмулятор: папка готова до прогона")
	var pc := ps.find("NO_GODOT")
	var pc_reset := ps.find("Reset-Run", pc)
	ok(pc_reset > pc and pc_reset < ps.find("Copy-Item \"$user\\out\\*\" $run"), "-Pc: папка готова до копирования")


## #1350 (11.11): сводка ПРОВЕРИТЬ под строкой RUN — худший кадр шагов открытых «проверить» с прошлыми прогонами
## из qa/ и счётом тихих подряд < 100 мс. Логику на выдуманных папках гоняет CI (`kadry.ps1 -SelfTest`, pwsh);
## здесь — что шаблоны ловят настоящие строки: лог QaRunner и раздел «Частота кадров» отчёта тестера.
func test_run_qa_watch_summary() -> void:
	var k := _ps("kadry.ps1")
	var log_re := RegEx.create_from_string("\\$l -match '([^']+)'").search(k)
	ok(log_re != null, "шаблон строки скриншота найден")
	if log_re != null:
		var r := QaRunner.new()
		r.worst_ms = 111.4
		r.worst_at = "шаг 342 wait, код 29 мс"
		r.jump_ms = 163.0
		var line := "скриншот 21a-vent | корабль (1, 2, 3)" + r.worst_text()
		r.free()
		var m := RegEx.create_from_string(log_re.get_string(1)).search(line)
		ok(m != null and m.get_string(1) == "21a-vent" and m.get_string(2) == "111", "худший кадр из строки QaRunner: %s" % line)
	var rep_re := RegEx.create_from_string("\\[regex\\]::Matches\\(\\$part, '([^']+)'\\)").search(k)
	ok(rep_re != null, "шаблон отчёта найден")
	if rep_re != null:
		var text := FileAccess.get_file_as_string("res://qa/2026-11-11-2018-svezhaya-b031182/report.md")
		var part := text.substr(text.find("\n## Частота кадров"))
		part = part.substr(0, part.find("\n## ", 5))
		var got := {}
		for m in RegEx.create_from_string(rep_re.get_string(1)).search_all(part):
			if not got.has(m.get_string(1)):
				got[m.get_string(1)] = int(m.get_string(2))
		eq([got.get("32o-mol-steklo"), got.get("21a-vent"), got.get("20-scanner"), got.get("09d-vote"), got.get("35-zadacha-07")],
			[144, 111, 105, 71, 42], "числа отчёта b031182 по шагам")
		ok(not got.has("32o"), "сокращённые имена — не шаги")
	var run := _ps("run-qa.ps1")
	var res := run.find("Add-Content \"$run\\log.txt\" \"run-qa: $result\"")
	var dot := run.find(". (Join-Path $PSScriptRoot 'kadry.ps1')")
	ok(dot > res, "сводка — после строки RUN")
	ok(run.find("Write-Kadry \"$run\\kadry.txt\" $result") > dot, "kadry.txt — в папку прогона")
	ok(run.find("Read-Past \"$repo\\qa\"") > dot, "прошлое — из qa/ клона")
	ok(run.rfind("NOT_DONE") > run.find("foreach ($w in $watch)"), "NOT_DONE остаётся последней")
	ok(k.contains("labels=$q") and k.contains("EscapeDataString"), "метка в адресе URL-кодом (кириллица в PS 5.1)")
	ok(_ps("publish-qa.ps1").contains("Copy-Item \"$src\\kadry.txt\""), "publish-qa.ps1 сдаёт kadry.txt")
	var ci := FileAccess.get_file_as_string("res://.github/workflows/godot.yml")
	ok(ci.contains("./tools/qa/kadry.ps1 -SelfTest"), "CI гоняет проверку kadry.ps1")
	ok(FileAccess.get_file_as_string("res://docs/QA.md").contains("ПРОВЕРИТЬ"), "docs/QA.md: сводка ПРОВЕРИТЬ")


## #1350, 12.11: две сессии тестера одного часа — второй run-qa.ps1 на том же эмуляторе, два publish-qa.ps1 в одном
## клоне, обе ветки отчётов пустые. Оба скрипта берут замок zamok.ps1 (живой чужой — BUSY и выход), сдача — в своём
## worktree со сверкой ветки на сервере; логику замка гоняет CI (`zamok.ps1 -SelfTest`, pwsh).
func test_qa_lock_and_worktree() -> void:
	var z := _ps("zamok.ps1")
	ok(z.contains("[IO.FileMode]::CreateNew"), "замок берётся атомарно")
	ok(z.contains("function Lock-Qa") and z.contains("function Unlock-Qa") and z.contains("\"BUSY $($held.since)"),
		"BUSY <с какого времени>")
	ok(z.contains("StartTime"), "PID сверяется со временем запуска процесса")
	var run := _ps("run-qa.ps1")
	var lock := run.find("$busy = Lock-Qa $lockFile")
	ok(lock > 0 and lock < run.find("function Reset-Run"), "run-qa берёт замок до первого прогона")
	ok(run.find("exit 2", lock) > lock, "занято — выход с кодом 2")
	ok(run.strip_edges().ends_with("Unlock-Qa $lockFile"), "замок снимается в конце")
	ok(run.find("[Console]::OutputEncoding") < run.find("function Get-Asset"), "вывод в UTF-8 с самого начала")
	var pub := _ps("publish-qa.ps1")
	var plock := pub.find("$busy = Lock-Qa $lockFile")
	ok(plock > 0 and plock < pub.find("worktree add"), "publish-qa берёт замок до worktree")
	ok(pub.contains("git -C $wt commit") or pub.contains("git -C $wt -c user.name"), "коммит — в worktree")
	ok(pub.contains("ls-remote origin") and pub.find("ls-remote") < pub.find("Write-Output \"PUSHED"),
		"PUSHED — после сверки ветки на сервере")
	var ci := FileAccess.get_file_as_string("res://.github/workflows/godot.yml")
	ok(ci.contains("./tools/qa/zamok.ps1 -SelfTest"), "CI гоняет проверку zamok.ps1")
