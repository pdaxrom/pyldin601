# Проверки переработанного проекта

## Программы HD6303 и таймауты, 4 октября 2026

HDTEST: 740 случаев; HDMUL: все 65536 произведений; HDSLEEP: 64 пробуждения
SLP — PASS на настоящем RTL CPU. Все три CMD пропускаются в MC6800;
намеренные ошибки результата/ожидания дают FAIL. В оригинальном UniDOS
для 601 и 601A программы загружаются с B, проходят и возвращают управление
для следующего DIR. [Программы, сборка и границы проверки](../tests/hd6303/README.md).
Три теста FAT12 и все прежние Python-тесты проходят; MBR, boot и A сохранены.
`make test-firmware` подтверждает оба таймаута по 500 PAL ticks / 10 секунд,
1/2/Enter, все сочетания модели/CPU, SDHC/SDSC, ошибки и warm reset.
Diamond: прежние 6539 LUT / 10 EBR, setup/hold negative slack 0,
unconstrained 0. Новый JED записан с Verify и FTDI JTAGENB high до/после;
журналы — `build/hardware-hd-tests`. Физическая карта не менялась.

## Предыдущая версия с выбором CPU, 3 октября 2026

Полный `make test` — PASS. Дополнительно: 2917 результатов HD6303,
2820 прежних проб в HD-режиме, 33 запрещённых в MC6800 opcode,
26 TRAP, три пробуждения SLP, live ISA switch и изменение входа после fetch.
Native BIOS/ROM совпадают с C-эталоном на 500000 инструкций и итоговой RAM
для всех четырёх сочетаний 601/601A и MC6800/HD6303.
Оба boot-меню, их таймауты и все четыре сочетания проходят firmware-тесты;
PS/2/SRAM/SPI mixed HDL подтверждает HD6303 и загрузку LOADER.BIN для обеих
моделей, включая удержание клавиши между меню.

Чистый Diamond: 6539 LUT, 3334 slices, 2128 registers, 10 EBR;
setup/hold negative slack 0, unconstrained 0. JED записан во FLASH:
Verify ID / Erase,Program,Verify и JTAG Chain Verification успешны,
FTDI JTAGENB high до/после; SD не менялась. Журналы — `build/hardware-cpu-isa`.
Физическая проверка выбора CPU пользователем ещё не выполнена.
[Полные команды, scope, первичная документация и архив](HD6303.md).

## Предыдущая записанная версия 601/601A, 3 октября 2026

Девять Python-тестов, исполнение MC6800 boot для 601/601A, timeout/1/2/Enter,
SDHC/SDSC, ошибки CRC/FAT/SRAM и неверный/отсутствующий ROM-комплект — PASS.
Реальные BIOS_A/XBIOS подтверждают пять видеорежимов, четыре палитры,
384 PLOT-точки и 8000 записей символов/атрибутов. `tb_video_601a` сверил
7618560 пикселей, включая оба поля PAL, blink, курсоры и подчёркивания.
Прежние эталоны классического PAL, цвета и DAC также проходят.

Обе модели прошли 40000 CPU-циклов без HOLD и 448 строк без опоздания:
17920 видеочтений для 601, 35840 для 601A. Два профиля SRAM проверяют
весь используемый 1 МиБ, электронный диск, ROM-underlays и 24 фазы Reset.
Mixed HDL CPU/SRAM/SPI/PS2 выбирает 601A и загружает LOADER.BIN;
preloaded-SRAM handoff проверяет оригинальный BIOS A, lock и warm reset.
Полная mixed HDL загрузка всех ROM с SD здесь не заявляется.

Diamond: 6182 LUT, 3156 slices, 2117 registers, 10 EBR; setup/hold negative
slack 0, unconstrained 0. FLASH Program/Verify прошёл; FTDI подтвердил
высокий JTAGENB до и после. Пользователь подтвердил 601A, текст 80 колонок
и DIR. Цветные режимы 601A физически ещё не подтверждены.
Источники, журналы и ограничения — в [MODELS.md](MODELS.md).

## История проверок до поддержки 601A

Ниже сохранены результаты соответствующих прежних сборок; их количества
тестов, ресурсы и указания на ожидаемую проверку относятся к тем этапам.

Клавиатура/PAL 2026-10-03: 184 навигационных случая против `keyboard.c`,
768000 пикселей текста/графики в обоих полях против `mc6845.c`, 128000 пикселей
всех символов шрифта и подчёркиваний, периферия, SRAM bus audit с двумя
профилями задержек и двадцать IRQ/RTI штатного BIOS — PASS.
Старая навигационная таблица, старая запись Scroll Lock и старый PAL RTL
отдельно воспроизводят сбои в новых тестах.
Журнал: `build/io-pal-regression.log`; причины — в [IO-FIXES.md](IO-FIXES.md),
сборка/запись — в [RELEASE.md](RELEASE.md).

Удаление аппаратной отладки 2026-10-03: RTL, board syntax, 7 Python-тестов,
полный CPU/video/electronic disk bus audit в двух профилях задержек SRAM,
handoff/lock/warm reset и двадцать natural PAL IRQ/RTI на настоящем CPU
прошли. Запас system→CPU 6.621 ns, FPGA 5892 LUT / 8 EBR.
Подробности и журналы — в [RELEASE.md](RELEASE.md).

Восстановление электронного диска 2026-10-03: `test-rtl`, `test-memory-bus`,
`test-firmware`, `test-handoff`, `test-board-syntax`, `test-python` PASS.
Оба профиля задержек SRAM проверили по 606 чтений и 630 записей диска,
единственный автоинкремент после completion, wrap 512 КиБ, 24 фазы warm reset
и содержимое всей используемой SRAM 1 МиБ вместе с CPU/video traffic.
Cold boot очищает все 512 КиБ; warm reset сохраняет данные. Существующий
образ физической SD совместим. Логи и ограничения — в
[ELECTRONIC-DISK.md](ELECTRONIC-DISK.md).

Дополнение CPU 2026-10-03: 500000 инструкций native BIOS, все PC/SP/X/A/B/CCR
и итоговая RAM совпали с C-эмулятором; 2820 результатов ALU/адресации/ветвлений
и 24 сценария IRQ/SWI/WAI/NMI прошли. Старый CPU воспроизводимо теряет
SWI frame при IRQ. Actual CPU + CPU/video SRAM прошёл 20 PAL IRQ и переход
02:00:00; handoff/lock/warm reset также PASS. Подробности, журналы и границы
сравнения — в [CPU-CONFORMANCE.md](CPU-CONFORMANCE.md).

Дополнение 2026-10-03: `make test` PASS с шестнадцатым bench delayed SRAM
stress и firmware SRAM readback fault. `make test-sram-diagnostic` PASS
на полном диапазоне 2038 KiB в C-модели и на коротком диапазоне с реальным
VHDL CPU, включая внесённые повреждения. Четыре виртуальных часа простоя
и 32 завершённых DIR прошли в оригинальном эмуляторе. На плате пользователь
сообщил SRAM diagnostic `ROUNDS 15` без ошибок. Короткий mixed HDL тест
настоящего VHDL CPU/UniBIOS прошёл 20 PAL IRQ, включая переход через два
часа; изменения RAM совпали с native, старый заголовок сохранён.
Это не подтверждение стабильности DOS на плате; границы и логи —
в [STABILITY.md](STABILITY.md).

Дата: 2026-10-02. Рабочая директория: `pyldin601-fpga`.
`make test` завершился с кодом 0; `make test-stage1` отдельно также код 0.

- Python: 7 тестов генератора SD/FAT и MC6800 ассемблера.
- Icarus: 15 benches: memory mapping/ROM guard/CHS, арбитраж трёх владельцев,
  boot aperture/CRC/geometry/warm lock, SPI ABI 8/16 бит, SRAM byte lanes,
  SD, PS/2, keyboard queue/IRQ, i8272, i8272/SD integration, PAL video,
  текстовые PAL pixels/initial font, BIOS layout/Win/Caps/RGB, сравнение
  курсора с оригинальным renderer и прозрачное чередование CPU/video в SRAM.
- Дополнительные SD runs: SDSC; повреждённый CRC сектора и успешный retry
  без reset. FDC bench включает ранний TC чтения/записи и reset.
- Сквозной аппаратный i8272 -> synchronous sector RAM -> SD SPI: A/B,
  чтение после записи и FORMAT, проверка CRC16, ранний TC без записи
  частичного сектора и недопустимый CHS без обращения к SD.
- Прозрачный доступ к экранной SRAM: непрерывная нагрузка CPU чтениями
  и записями, 40000 циклов без hold, 17920 видео-чтений, 448 строк
  загружены до начала видимой части. В рабочем цикле слоты 3/10/17
  соответственно отданы CPU/видео/видео; boot использует арбитраж с hold.
- Настоящий VHDL CPU против C MC6800: 1965 сравнённых байт состояния:
  ALU/flags/DAA/CPX/addressing, JSR/BSR/RTS, SWI/IRQ/RTI, периодический hold.
- Исполняемые boot.asm/loader.asm через байтовую SPI-модель SD:
  SDHC обычный FAT16, SDHC фрагментированный FAT16, SDSC; проверено
  физическое содержимое всех 333824 байт ROM, handoff и warm reset.
  Отдельно rejected повреждённый ROM и укороченная FAT chain.
  Около 44,9 млн инструкций и 1310 прочитанных секторов для успешной загрузки.
  Проверены инициализация 40×24 text/CRTC до первого SD command, все
  11 этапов и счётчики 05/05 ROM и 08/08 RAM disk. Ошибки CRC, FAT chain
  и отсутствия SD выводят соответственно этапы 08, 06 и 01 на экран.
- Текстовый RTL-test сверяет 128 pixels настоящего шрифта (буква A и
  соседний пробел), затем font replacement и сохранение при warm reset.
- Сравнение с оригинальным MC6845: 128000 видимых pixels двух кадров,
  текстовый/графический cursor, stride42/48 и ненулевое начало экрана.
- Штатный UniBIOS на оригинальном MC6800/keyboard.c подтверждает латиницу
  при старте и warm reset, FB/FC по два раза и сохранение видеобитов E629.
  Production classic_system проверен PS/2 make/repeat/break обеих Win,
  Caps Lock, кириллицей, DRB readback и RGB-катодами.
- Mixed HDL stage1: настоящий cpu6800.vhd + classic_system + SRAM + SPI;
  LOADER.BIN загружен в RAM через 4 чтения SD-секторов.
  Настоящее HDL ядро инициирует text до первого SD command; проверены
  RAM с названием этапа и 9345 bright PAL samples во время boot.
- Mixed HDL handoff: настоящий CPU программирует metadata, выполняет
  RAM-трамплин/commit, запускает классический reset vector; warm reset
  сохраняет lock и маркер RAM-диска. В этом коротком fixture ROM заранее
  размещён в SRAM, CRC metadata соответствует пустому аккумулятору.
  Он проверяет границу CPU/RTL, не полную загрузку ROM с SD.
- Board top/PLL синтаксически проанализированы NVC с тестовыми заглушками
  MachXO2 primitives; это не проверка реального PLL или synthesis.
- Diamond 3.14 на Linux: synthesis/MAP/PAR/TRACE/Jedecgen успешно завершены.
  LUT 5759/6864, slices 2942/3432, registers 1846/7209, EBR 8/26.
  Setup = 0 errors, hold = 0 errors, unconstrained = 0 paths.
  Дополнительное ограничение system -> CPU 20 ns проверяет 2006 путей;
  худшая задержка 14.973 ns, запас 5.027 ns. См. `DIAMOND.md`.

Фотографии пользователя подтверждают UniDOS 7.20 и A:\> на физической
плате с предыдущей text-сборкой. Визуальная проверка исправлений текущей
io-сборки отдельно от симуляции и FLASH Verify пока не подтверждена.

Полная mixed HDL загрузка всех ROM была запущена на промежуточной версии,
но не дошла до конечного PASS и остановлена после изменения RTL. Текущий
`make test-system` оставлен как воспроизводимый отдельный длительный тест;
его прохождение здесь НЕ заявляется. В обычном `make test` нет имитации
полного HDL ROM boot с подменой на C core.

Не подтверждены: полная спецификация i8272, NMI/WAI CPU, полный набор
режимов MC6845, фактические сигналы на выводах SRAM/SD. C firmware boot
не проверяет дисковую ОС (FDC reads=0).
Логи текущих запусков — `build/io-fixes-tests.log` и `build/stage1.log`;
SHA исходников
зафиксирован в `rewrite-manifest.json`.

После пользовательской проверки красная индикация Caps инвертирована.
Для этой локальной правки повторён `tb_keyboard_layout` (PASS,
`build/caps-led-test.log`); остальные функциональные проверки выше относятся
к io-сборке. Новая прошивка отдельно проходит Diamond fit/STA и FLASH Verify.
