# Проверки переработанного проекта

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
