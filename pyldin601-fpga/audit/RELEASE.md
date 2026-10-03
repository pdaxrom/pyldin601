# Обычная версия без аппаратной отладки, 3 октября 2026

Пользователь подтвердил исправную работу электронного диска без сбоев.
Согласно его условию после этого удалена аппаратная отладка. Электронный
диск остаётся в системе, а SD-карта не требует изменений.

## Удалённая логика

Из classic_system и board top удалены RAM_DIAGNOSTICS, контрольная копия
BIOS в EBR, сравнение runtime-чтений, кольцевая CPU-трасса, UART heartbeat,
приём H/h, регистры диагностики и остановка CPU. Из CPU bus удалены вход
halt и диагностические выходы состояния; pending/complete/issued остаются
внутренним состоянием обычного адаптера. TX удерживается в idle, RX не
используется. Модуль runtime_uart_diagnostics и BIOS reference удалены
из исходников и проекта Diamond, вместе с зависимыми tools/test fixtures.
Генератор пакета Diamond больше не имеет режима runtime-diagnostic.

Ранее использованные исходники сохранены в `build/retired-runtime-debug.tar.gz`
и точных архивах предыдущих сборок. Журналы прежней диагностики сохранены
как история. Offline-проверки CPU, арбитра, периферии и отдельного SRAM-test
не включают эту логику в FPGA.

CPU, арбитр, SRAM controller, video, boot ports, boot.asm, loader.asm и
boot.mem совпадают по SHA с проверенной cpu-edisk сборкой. Порядок доступа
CPU/video, электронный диск, защита ROM и экранный статус загрузки не
изменены. CRC32 ПЗУ перед запуском BIOS остаётся частью bootstrap.

## Проверки

`make test-rtl test-board-syntax test-python test-memory-bus test-handoff`
прошёл с кодом 0: `build/release-clean-regression.log`. Проверены периферия,
SD/FDD, шрифт, курсор, 384000 пикселей против оригинального MC6845,
40000 CPU-циклов без video HOLD и 448 видеострок до deadline.

Оба профиля задержек SRAM прошли по 145400 CPU-слотов, 67160 видеочтений,
73270 физических записей, 606 чтений и 630 записей электронного диска.
Проверены wrap 512 КиБ, однократный автоинкремент после completion,
все ROM-банки, 24 фазы warm reset и сохранность полного 1 МиБ.
Mixed HDL с настоящим CPU прошёл handoff/lock/warm reset.

`make test-runtime-irq STABILITY_IMAGE=build/sd-text.img` прошёл с кодом 0:
`build/release-clean-runtime-irq.log`. Настоящий VHDL CPU и штатный BIOS
выполнили двадцать PAL IRQ/RTI, включая переход через 02:00:00;
изменения RAM совпали с C-эмулятором, баннер сохранён, 172800 видеочтений,
CPU на runtime capture не удерживается. CPU-конформанс повторно не
прогонялся, поскольку ядро не изменено; его проверки описаны в
[CPU-CONFORMANCE.md](CPU-CONFORMANCE.md).

## Diamond

Linux: `sash@192.168.1.108`, `/tmp/pyldin601-release-clean.ZfEkFp`,
Diamond 3.14, LCMXO2-7000HC-4TG144I, system 24 МГц.
Точные 29 входных файлов:
`build/diamond/source-release-clean.tar.gz` и `.sha256.json`.

| Ресурс | Занято | Всего | Осталось |
|---|---:|---:|---:|
| LUT4 | 5892 | 6864 | 972 |
| Slices | 3010 | 3432 | 422 |
| Registers | 1898 | 7209 | 5311 |
| EBR | 8 | 26 | 18 |
| PLL | 1 | 2 | 1 |

Удаление отладки освободило 606 LUT, 302 slices, 427 registers и 6 EBR.
Распределение оставшихся EBR по MAP: bootstrap 4, шрифт 2, SD/FDD buffer 2.
В синтезированном EDIF нет ram_diagnostics, runtime_uart_diagnostics,
bios_golden и diagnostic_halt.

TRACE setup/hold negative slack 0, unconstrained paths 0. Все 2023
полупериодных пути system→CPU проходят 20 ns: worst 13.379 ns,
margin 6.621 ns. JED экспортирован только после проверки этих условий.

JED: `build/diamond/release-clean/impl1/pyldin601_classic_impl1.jed`.
SHA-256: `7e7a7dacf6da195cae8219abf4a3d83ae87bb1c01c21169bb1d935046aea8ffc`.
Отчёты MAP/PAR/TRACE/Synthesis и build log сохранены рядом с JED.
Перед программированием ещё раз сверяются source manifest, JED и TRACE.

## Физическая плата

Предыдущая cpu-edisk версия прошла проверку пользователя: электронный диск
работает, сбоев нет. Её пассивный UART PID 279897 остановлен перед новой
записью; полная трасса сохранена в `build/hardware-cpu-edisk/uart-live`.
После удаления UART новый capture не запускается.

Результат программирования этой версии сохраняется в
`build/hardware-release-clean/result.json`. Процедура использует FTDI
`hgfsd --jtag-only` для высокого JTAGENB до и после, затем FLASH Verify ID
и Erase,Program,Verify. SD не перезаписывается.

FLASH Verify ID / Erase,Program,Verify завершились успешно, JTAG Chain
без ошибок. Wall time 65.52 секунды; FTDI подтвердил высокий JTAGENB
до и после. Журналы/XCF/result — `build/hardware-release-clean`.
SD не перезаписывалась. На этой версии аппаратного UART-capture нет.

## Повторная сборка перед коммитом

3 октября полный `make test test-memory-bus test-runtime-irq
STABILITY_IMAGE=build/sd-text.img` прошёл с кодом 0. Повторно проверены
500000 последовательных инструкций с native BIOS, 24 сценария IRQ/SWI/WAI,
CPU ALU/адресация, SD/FAT firmware, периферия, два профиля SRAM и двадцать
runtime PAL IRQ. Журнал: `build/precommit-regression.log`.

Повторная сборка Diamond 3.14 в `/tmp/pyldin601-precommit.kaXZyj` прошла
Synthesis/Translate/MAP/PAR/TRACE/Jedecgen. Ресурсы: 5892 LUT, 3010 slices,
1898 registers, 8 EBR; setup/hold negative slack 0, unconstrained paths 0,
2023 полупериодных пути system→CPU без ошибок. Все 29 входных файлов
совпали с source-release-clean manifest. Конфигурационные данные JED
совпадают с прошитой версией; отличаются дата создания и transmission checksum.

JED: `build/diamond/precommit/impl1/pyldin601_classic_impl1.jed`.
SHA-256: `5e47fb1106705af4c7783c44f86667e3a8090f96ffb6696fd6f067fabdb64d72`.
Отчёты и result: `build/diamond/precommit`; архив исходников:
`build/diamond/source-precommit.tar.gz` и `.sha256.json`.
Повторная сборка не программировала плату.

## Клавиатура и PAL, 3 октября 2026

Исправлены PS/2-коды навигации и лишняя Кир/Лат от Scroll Lock.
Номер строки шрифта во втором поле PAL теперь меняется на границе полной
горизонтальной строки. Подробности и отрицательные проверки старого RTL:
[IO-FIXES.md](IO-FIXES.md).

`make test-rtl test-board-syntax test-memory-bus test-runtime-irq
STABILITY_IMAGE=build/sd-text.img` прошёл с кодом 0:
`build/io-pal-regression.log`. Новые проверки: 184 случая клавиатуры,
128000 пикселей шрифта и 768000 пикселей MC6845 в обоих полях PAL.
Оба профиля SRAM прошли прежние 145400 CPU-слотов, 67160 видеочтений и
606/630 чтений/записей электронного диска; настоящий CPU/BIOS выполнил
двадцать IRQ/RTI с совпадением RAM, целым баннером и 172800 видеочтений.
CPU и прошивки не менялись.

Diamond 3.14: `/tmp/pyldin601-io-pal.l3TTXa`.
Все 29 входных файлов сверены с `build/diamond/source-io-pal.sha256.json`.
Synthesis/Translate/MAP/PAR/TRACE/Jedecgen прошли. Занято 5892/6864 LUT,
3010/3432 slices, 1899/7209 registers, 8/26 EBR и 1/2 PLL.
EBR: bootstrap 4, шрифт 2, SD/FDD buffer 2.
Setup/hold negative slack 0, unconstrained paths 0. Все 1994 полупериодных
пути system→CPU проходят 20 ns; worst 15.767 ns, margin 4.233 ns.

JED: `build/diamond/io-pal/impl1/pyldin601_classic_impl1.jed`.
SHA-256: `4fb2815b4e90849f2d3745abe0183dd72385e33c09184f5d979faad85fe2eca5`.
Отчёты и результат: `build/diamond/io-pal`.
Процедура записи и журналы: `build/hardware-io-pal`.

FLASH Verify ID и Erase,Program,Verify прошли, JTAG Chain без ошибок.
FTDI подтвердил высокий JTAGENB до и после записи. Wall time 65.88 секунды.
SD не перезаписывалась, аппаратная отладка выключена, электронный диск
включён. Визуальную проверку новых исправлений выполняет пользователь.

## Цветной PAL классической 601, 3 октября 2026

Добавлены 80×200×16 IRGB и 160×200×4, все четыре палитры E629.
Использован подход PAL-кодировщика uJ11: непрерывная DDS и чередование V,
burst и его гашение. Для 16 цветов расчёты заменены одним waveform EBR.
Текст и 320×200×2 сохраняют прежние уровни и границы пикселей. CPU,
арбитр, SRAM-контроллер, SD/FDD и электронный диск не изменялись.
Подробности интерфейса и проверок — [COLOUR.md](COLOUR.md).

`make test-rtl test-board-syntax test-memory-bus test-runtime-irq
STABILITY_IMAGE=build/sd-text.img` завершился с кодом 0:
`build/colour-pal-regression.log`. Проверены 1 280 000 цветных пикселей,
3 038 260 DAC-отсчётов, реальные INT12/INT22/INT60/INT66 BIOS/XBIOS,
прежние монохромные эталоны, периферия, SRAM/электронный диск и 20
IRQ/RTI рабочего BIOS с совпадением RAM и 172800 видеочтений.

Diamond 3.14: `/tmp/pyldin601-colour-pal-r2.yp9Yzs`.
31 входной файл сверяется с `build/diamond/source-colour-pal.sha256.json`.
Пройдены Synthesis/Translate/MAP/PAR/TRACE/Jedecgen.

| Ресурс | Занято | Всего | Свободно |
|---|---:|---:|---:|
| LUT4 | 6006 | 6864 | 858 |
| Slices | 3070 | 3432 | 362 |
| Registers | 1941 | 7209 | 5268 |
| EBR | 9 | 26 | 17 |
| PLL | 1 | 2 | 1 |

EBR: bootstrap 4, шрифт 2, SD/FDD buffer 2, PAL waveform 1.
Относительно io-pal добавлено 114 LUT и один EBR.
Setup/hold negative slack 0, unconstrained paths 0. Все 1994
полупериодных пути system→CPU проходят 20 ns: worst 15.275 ns,
margin 4.725 ns. System 24 MHz: worst 39.390 ns, margin 2.111 ns.
Clock-to-output: margin 3.812 ns при требуемых 15 ns.
Первая попытка выявила опоздание EBR→DAC до 0.770 ns; отдельный
выходной регистр устранил его без изменения фаз пикселя или ослабления LPF.

JED: `build/diamond/colour-pal/impl1/pyldin601_classic_impl1.jed`.
SHA-256: `d7354d1077eac7190418d5837475b26f60eb5f88368c4847593ba8abe419cba0`.
Отчёты и result — `build/diamond/colour-pal`.
Процедура записи и журналы — `build/hardware-colour-pal`.

FLASH Verify ID и Erase,Program,Verify завершились успешно; JTAG Chain
без ошибок. FTDI подтвердил высокий JTAGENB до и после записи.
Wall time 66.15 секунды; SHA JED совпал с указанным выше.
SD не перезаписывалась, электронный диск включён, runtime-отладка выключена.
После записи пользователь подтвердил работу цветного режима на плате.


## 3 октября 2026 — 601/601A

Меню до первого SD command: 1=601, 2=601A, Enter/default=601, timeout пять
секунд по PAL ticks. Новый loader выбирает P601.ROM/P601A.ROM и проверяет
модель; Reset сохраняет model_a и lock. Поддержаны все пять видеорежимов A,
включая 80 колонок, текстовые атрибуты и мигание. Буферы строк перенесены
в один EBR; фиксированные SRAM-слоты и CPU без HOLD сохранены.

Проверки и источники: [MODELS.md](MODELS.md). Девять Python-тестов,
software boot всех ветвей, HDL периферии и обоих renderer, 7618560 A-пикселей,
реальные BIOS/XBIOS, mixed CPU/SPI/PS2 boot, handoff/Reset A,
два профиля SRAM. Прежние mono/colour/DAC эталоны сохранены.

Diamond `/tmp/pyldin601-models-ebr.5bW9s1`, 31 входной файл по
`source-models-ebr.sha256.json`. LUT 6182/6864, slices 3156/3432,
registers 2117/7209, EBR 10/26, PLL 1/2. EBR: bootstrap 4, font 2,
SD/FDD 2, waveform 1, line cache 1. Свободны 682 LUT, 276 slices и 16 EBR.
Setup/hold negative slack 0, unconstrained 0; 1994 system→CPU пути,
worst 15.396 ns, margin 4.604 ns. Clock-to-output margin 2.000 ns.

JED SHA-256: `23aed1527bf33304f413f177a7ca2452ccff7d694c418609a0bec872bd603398`.
FLASH Verify ID и Erase,Program,Verify успешны, wall time 66.45 секунды.
JTAGENB HIGH/readback подтверждён до и после записи.
Первый раздел SD обновлён с прямой проверкой чтением; MBR и A/B побайтно
сохранены. Пользователь подтвердил: 601A загрузился, текст и DIR работают.
Архивы и журналы — `build/diamond/models-ebr`, `build/hardware-models`,
`build/sd-models`; аппаратная runtime-отладка выключена.
