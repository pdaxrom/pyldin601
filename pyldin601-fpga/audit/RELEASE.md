# HAM8-картинки, 9 октября 2026

Добавлены C-конвертер JPEG/PNG `ham8conv` и HD6303 `HVIEW.PGM` для IFF ILBM
с фиксированной RGB222 CMAP и ByteRun1. FPGA/ROM сохранены.
Host-проверки macOS/Linux и ASan/UBSan — PASS; настоящий BIOS/UniDOS
601/601A, все пиксели/компоненты, повреждённые файлы и возврат — PASS.
HG обновлён без перезапуска демона и изменения пользовательских файлов;
конвертер установлен в `pyldin601-hg/bin/ham8conv`. Пользователь подтвердил:
«Цвета и ESC работают». На B готового SD-образа добавлены HVIEW и LENA.IFF.
Подробности — [HAM-VIEWER.md](HAM-VIEWER.md).

# Кандидат HAM8 / FPGA BIOS / AY, 9 октября 2026

HAM6 удалён; HAM8 сохраняет 262144 RGB-состояния и 64000 байт на кадр.
CLIPSPR обрезает прозрачные спрайты по всем краям. Добавлен AY-3-8910
с фиксированной частотой 2 МГц и выводом на оба аудиоканала.
AY.PGM воспроизводит мелодию через INT E0 и возвращает UniDOS по ESC.

i8272 и автономный SD backend заменены ROM-драйвером INT17.
Страница B содержит прямое чтение/запись SD с CRC16, монтирование A/B
по MBR/BPB и INT E0 для графики, спрайтов и AY. Она совместима с MC6800;
обрезка использует HD6303. UniAS собирает код и считает CHECKSUM.
Текущее расширение занимает 2859 байт плюс 512 байт CRC-таблиц в 8 КиБ ROM.

Готовый `images/sd.img` обновлён: обе ROM содержат расширение;
на B обновлён HAM и добавлены CLIPSPR, GFXCLIP и AY с исходниками.
MBR, диск A, настройки, прочие файлы boot/B сохранены.
Native-проверки чтения/записи/форматирования, восьми конфигураций,
21 повреждённой разметки и четырёх конфигураций INT E0 — PASS.
HAM/CLIPSPR/AY прошли штатные BIOS/UniDOS обеих моделей.
Diamond fit/strict TRACE и синтезированная EBR — PASS.

9 октября обе ROM на физической SD обновлены с прямой проверкой чтением;
MBR, A/B, P601.SET и 11 таблиц EBR дополнительных дисков сохранены.
FPGA прошита с FLASH Verify ID / Erase,Program,Verify: PASS, 66,45 с.
HG восстановлен, HAM/CLIPSPR/AY установлены в сетевую папку с сохранением
пользовательских файлов. Отчёты: `build/hardware-direct-sd-20261009`.
Пользователь подтвердил загрузку, DIR с A/B, полный Reset удержанием
10 секунд, мелодию AY и возврат UniDOS по ESC: «да». Модель и частота
отдельно не указаны; физическая запись файла новым SD-драйвером ещё
не проверялась. Предыдущие подтверждения HAM/CLIPSPR относятся к версии v4.
[ПЗУ](FPGA-BIOS.md), [звук](AY.md), [сборка](DIAMOND.md).

## История: HAM6/HAM8 v4

# HAM6/HAM8, 9 октября 2026

Интерфейс v4 добавляет оба формата с общей шестибитной PAL-таблицей
в прежних EBR: 4096/262144 логических RGB-состояния, 64000 байт на кадр.
Нативный HD6303 HAM.PGM сохраняет палитру, вычисляет таблицу одним MUL
на отсчёт и строит две страницы аппаратным FILL. SPACE меняет формат,
ESC восстанавливает палитру и возвращает UniDOS. 1009 байт кода/данных,
8192 байта BSS, 101 relocation, 1227 байт PGM. Готовый SD-образ обновлён
на B с сохранением MBR/boot/A/прежних файлов; физическая SD не записывалась.

PASS: полный HAM RGB-куб, оба знака V, пять дополнительных фаз тактов,
native/indexed PAL и геометрия 601/601A, GFX на 1/2/4/8 МГц без HOLD,
настоящие BIOS/UniDOS обеих моделей и точный готовый SD-образ.
Полные HDL-прогоны HAM: 601/8 МГц и 601A/1 МГц, по 24581 команде,
384000 байт кадра, 6144 нативных MUL-отсчёта и восстановление 8192 слов.
VIEW и SPRITES на HDL 601/8 МГц, Python, EDIF и модели Lattice — PASS.

Diamond: 6676 LUT, 3348 slices, 2549 registers, 25 EBR, 1 PLL.
Setup/hold negative slack=0, unconstrained=0; 96-МГц запас 0,620 нс,
прежние ограничения SRAM сохранены. JED SHA-256
`bf7a3ab519e32300fcdde3ed95ce7e54a39d8ede2bc4eb808fcfc2aa47c1321a`.
FLASH Verify ID / Erase,Program,Verify, JTAG Chain и JTAGENB high/low —
PASS; запись 69,48 с, HG восстановлен, HAM установлен. Пользовательские
файлы сохранены. Подтверждение изображения и ESC на плате ожидается.
Отчёты: `build/ham/validation.json`, `build/hardware-ham-20261009`.
[Формат, ограничения и проверки](HAM.md), [сборка](DIAMOND.md).

# Прозрачные спрайты, 9 октября 2026

Интерфейс v3 добавляет COPY с произвольным цветовым ключом, без записи
совпадающих пикселей. Параметры и overlap совпадают с COPY. Для 96 МГц
сравнение и подготовка счётчиков разделены; HOLD и новые EBR не добавлены.
SPRITES.PGM — HD6303-демо трёх 32×32 спрайтов: две страницы кадра, атлас
и неизменяемый фон. Сначала восстанавливаются прежние прямоугольники,
затем рисуются новые; FLIP ждёт VBL, ESC возвращает UniDOS.
1134 байта кода/данных, 102 relocation, 1354 байта PGM.
На B готового SD добавлены программа, ASM и инструкция; VIEW принимает
v2/v3. MBR/boot/A/прочие файлы B сохранены, физическая SD не записывалась.

Финальные проверки — PASS: 32 keyed COPY/281840 пикселей и 512000
пикселей растра на 1/2/4/8 МГц, skipped writes, overlap, CPU/video/DMA,
SRAM-10, bounds, VBL и warm drain. Все восемь HDL-запусков PGM
601/601A × 1/2/4/8 МГц: по 313 команд и 512000 пикселей восьми кадров.
Оригинальные BIOS/UniDOS обеих моделей: два запуска по 400 кадров,
четыре границы, наложение, обе истории страниц, ESC/guards/error и DIR.
Прежний MC6800 GFX обеих моделей на 8 МГц, VIEW v2/v3 и Python — PASS.

Diamond: 6681 LUT, 3354 slices, 2627 registers, 25 EBR, 1 PLL.
Setup/hold negative slack=0, unconstrained=0; SRAM ограничения сохранены.
96-МГц setup margin 0,950 нс. EDIF/vendor PAL audit — PASS.
JED SHA-256 `e0c6aa644f9135f3648c00807536a9ccaf88e37e02fb0861e2ba581658430595`.
FLASH Verify ID / Erase,Program,Verify и JTAG Chain — PASS, 49 входов
сверены; JTAGENB high до/после и low после HG — PASS. Запись 69,34 с.
HG восстановлен, PID 608596; SPRITES и новый VIEW установлены.
Лена и остальные пользовательские файлы сохранены. Пользователь подтвердил
анимацию и возврат по ESC: «Спрайты и ESC работают». Модель и частота
этого запуска не указаны; все восемь сочетаний отдельно проверены в HDL.
Отчёты: `build/sprites/validation.json`,
`build/hardware-sprites-20261009/{result,install-result,files-install}.json`.
[Интерфейс и проверки](GRAPHICS.md), [сборка](DIAMOND.md).

# Программируемая палитра, 9 октября 2026

Графическое устройство версии 2 поддерживает 256 программируемых цветов
через второй порт прежних шести PAL EBR. VIEW.PGM сохраняет исходные PCX
индексы, вычисляет RGB888-палитру на HD6303 и восстанавливает прежние цвета
при ESC или ошибке. Дополнительный буфер 8 КиБ объявлен как PGM BSS.
Готовый SD-образ обновлён только на B: VIEW.PGM/ASM, PALCOEF.ASM и инструкция;
загрузчик, ROM, настройки, A и остальные файлы сохранены.

Diamond: 6643 LUT, 3335 slices, 2616 registers, 25 EBR, 1 PLL;
setup/hold negative slack и unconstrained paths — 0, прежние ограничения SRAM
сохранены. Проверены реальные EDIF-подключения обоих портов и все 8192
записи/чтения в моделях Lattice; native UniDOS 601/601A сверяет PCX, палитру,
BSS, ошибки, ESC и следующий DIR.
FPGA записана с Verify ID / Erase,Program,Verify; FTDI JTAGENB high до/после
и low после HG подтверждены. Новый VIEW доставлен через HG, Лена и остальные
пользовательские файлы не изменены; C-демон автоматически обновил том.
Физическая SD не записывалась. 9 октября пользователь подтвердил работу
на панели: «да, работает!» после просьбы проверить Лену и выход по ESC.
[Интерфейс](GRAPHICS.md), [VIEW и проверки](PCX-VIEWER.md),
[JED, ресурсы и протоколы записи](DIAMOND.md).

# Первоначальное графическое расширение, 9 октября 2026

Добавлены RGB332 320×200, страницы кадра в верхнем 1 МиБ SRAM,
аппаратные FILL/COPY и FLIP по VBL. GFX.PGM, исходник и инструкция добавлены
на B готового образа; boot-раздел, настройки, A и прежние файлы B сохранены.
Прошли проверки графики с одновременными CPU/видео/блиттером без HOLD,
штатного видео, SRAM, клавиатуры со штатным BIOS, firmware и PAL RGB332.
Diamond: 6529 LUT, 3274 slices, 2367 registers, 25 EBR;
setup/hold negative slack и unconstrained paths — 0.
[Интерфейс, ресурсы, JED и результаты](GRAPHICS.md).
Прошивка записана во FLASH с Verify ID / Erase,Program,Verify;
FTDI JTAGENB high проверен до/после. HG восстановлен, GFX.PGM предоставлен
на его диске с побайтной проверкой. SD не записывалась;
журналы — `build/hardware-gfx-20261009`.
9 октября пользователь подтвердил работу графики на плате: «отлично, работает».

# Выпуск HG, 8 октября 2026

Добавлены резидентный HG.PGM, HGTIME.PGM и интерфейс FT2232A/JTAG для
удалённого FAT12-диска с синхронизацией времени. Программы, исходник и
инструкция добавлены на B готового `images/sd.img`; MBR, boot-раздел,
A и прежние файлы B сохранены. Сборка FPGA и сквозные проверки —
в [HG.md](HG.md), запуск — в [host/hg/README.md](../host/hg/README.md).
HG записан во FLASH 8 октября: Verify ID / Erase,Program,Verify и
JTAG Chain Verification прошли без ошибок, FTDI JTAGENB high проверен
до/после. HG-программы добавлены на B физической SD; прямое чтение и
независимая проверка на Mac подтвердили сохранность настроек, A,
прежних файлов B и дополнительного extended-раздела. Журналы и резервные
копии — `build/hardware-hg-20261008`. Пользователь подтвердил работу HG:
DIR / TYPE / COPY. TEST.TXT экспортирован на хост и совпал с исходными
1097 байтами README.TXT; копия в FAT12 также сверена.
Этот выпуск HG подтверждён пользователем на плате 8 октября.
Ниже сохранена история предыдущих выпусков.

# Выпуски FPGA, 4 октября 2026

Прошивка hd-tests содержит выбор 601/601A и отдельный выбор MC6800/HD6303 ISA:
`build/diamond/hd-tests/impl1/pyldin601_classic_impl1.jed`, SHA-256
`eefc5b75bdaf7e7e95b0917c857057e8c57fa97759aa33d99fd65e7e565065e0`.
Она записана во FLASH с успешными Verify ID / Erase,Program,Verify,
JTAG Chain Verification и FTDI JTAGENB high до/после.
[ISA, ресурсы и проверки](HD6303.md), [журналы записи](HARDWARE.md).
Физическая проверка выбора CPU пользователем ещё не выполнена.
Оба boot-меню ждут по 10 секунд. UniAS-программы HDTEST/HDMUL/HDSLEEP
и исходники добавлены на B физической SD-карты 4 октября; все три прошли RTL CPU
и штатный UniDOS в C-модели для обеих моделей.
SD обновлена только в пределах B из свежей резервной копии. Прямое чтение
и повторная проверка на Mac подтвердили образ и все семь файлов;
MBR, boot-раздел и A сохранены. Копии/отчёт — `build/hardware-sd-hd-tests`.
Исполнение тестов на плате пока не подтверждено.
[Запуск и проверки](../tests/hd6303/README.md).
Следующие указания на записанные JED относятся к предыдущим версиям.

Предыдущая прошивка — 601/601A: `build/diamond/models-ebr/impl1/pyldin601_classic_impl1.jed`,
SHA-256 `23aed1527bf33304f413f177a7ca2452ccff7d694c418609a0bec872bd603398`.
Меню, видеорежимы, ресурсы и физическое подтверждение — в [MODELS.md](MODELS.md)
и последнем разделе этого документа. Ниже сохранена последовательность выпусков.

## Удаление аппаратной отладки

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
