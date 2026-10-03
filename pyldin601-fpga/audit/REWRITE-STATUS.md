# Состояние после переработки, 2 октября 2026

`AUDIT.md` описывает исходный прототип, а не текущую реализацию.
Рабочие исходники теперь находятся в родительской `pyldin601-fpga`.
Ниже указано, что устранено и что ещё требует проверки; исправление исходника
не приравнивается к подтверждённой работе на FPGA.

| Findings | Текущее состояние |
|---|---|
| A01–A04 | Полный комплект исходников в новой директории; board top VHDL, исправлены имена PLL; аппаратный FAT удалён, SD/FAT выполняет MC6800 |
| A05 | CPU/SPI-модель подтверждает передачу к reset vector BIOS; реальное HDL-ядро подтверждает первую стадию; отдельный preloaded-SRAM тест проверяет commit/handoff/warm reset, полная mixed HDL загрузка ещё не завершена |
| A06–A07 | Защёлкнута CPU-транзакция, issued/accept/done; тест трёх владельцев подтверждает однократное выполнение |
| A08 | Warm reset останавливает CPU, дожидается внешнего обмена и сохраняет lock; все комбинации reset во время SD write ещё не покрыты |
| A09 | Реальный VHDL CPU сравнивается с C core; исправлены CPX/TST/DAA, запрещён direct JSR 6801; проверены SWI/IRQ/RTI и подпрограммы; NMI/WAI и полный набор ещё не покрыты |
| A10 | Boot CPU 4 МГц, runtime 1 МГц; clock из регистра на falling system edge; переключение проверено функционально; Diamond STA и отдельный 20 ns путь к CPU проходят |
| A11 | Page modulo 5 и write-under-ROM приведены к классической модели, проверены mapping-тестом |
| A12 | Общий rom_write_guard после арбитража подключён в production system; commit/retained lock — в boot ports |
| A13 | SRAM byte lanes/turnaround/reset проверены в симуляции; Diamond fit/STA проходят; runtime CPU/видео чередуют слоты, 40000 циклов CPU без hold |
| A14–A16 | Один SPI engine, ABI нового Пълдина на E660, runtime-доступ с владением CS; проверены 8/16-битные обмены |
| A17 | Ошибка runtime SD не требует cold reset; добавлен тест CRC rejection + retry |
| A18 | SDHC/SDSC, CRC16, ограниченные ожидания; CSD/capacity и дополнительные ошибки SD не покрыты полностью |
| A19 | Аппаратный i8272: односекторные READ/WRITE/FORMAT и ранний TC; совместный FDC/EBR/SD SPI тест проходит; полная спецификация i8272 ещё не реализована |
| A20–A21 | Reset приоритетен, принятый обмен дренируется; выбор диска защёлкнут; добавлены TC/reset сценарии |
| A22 | `--boot B` явно документирован как swap физических образов A/B |
| A23 | Предел 80×2×18 и классические 720/1440 КиБ явно проверяются; экзотические геометрии emulator floppy.c не обещаются |
| A24 | Аппаратный file-helper удалён из тестовой модели; реальные asm выполняются через байтовой SPI, metadata проверяется в boot ports RTL |
| A25 | Boot software имеет ограниченные ожидания, CRC и код ошибки EE; до первого SD command включает текстовый экран и показывает 11 этапов/прогресс/код ошибки; commit failure останавливает RAM-трамплин |
| A26 | Единственный исполняемый источник ROM — P601.ROM; отдельные дубли BIOS/FONT/ROM с SD убраны; CFG только информационный |
| A27 | Выбранная комплектация BIOS + RAMROMDiskPipnet указана в README; пользовательское сравнение альтернативных ROM-комплектов не выполнено |
| A28 | `make image` использует native/Floppy/system.imz на A; B пустой; фотографии пользователя подтверждают UniDOS 7.20 и A:\> на плате |
| A29 | 12 МиБ только structural test генератора, LBA контроллер отложен согласно выбору пользователя |
| A30 | FAT16-only первичный раздел явно документирован |
| A31–A32 | Graphics stride 48, адреса DMA ограничены base RAM; boot text 40×24 с font INITVAL в существующих 2 EBR; RTL-тесты pixels/font replacement/warm retention проходят |
| A33 | PAL 50 полей/25 кадров, boot status (9345 bright samples); 128000 pixels text/graphics и cursor совпали с оригинальным MC6845 renderer; полный набор режимов ещё не покрыт |
| A34–A36 | Очередь/unread/IRQ/trigger/Pause; исправлен E629 readback, обе Win=FB, Caps=FC, RGB; штатный BIOS подтверждает латиницу при старте/reset и переключения; полный PS/2 набор ещё не покрыт |
| A37 | Page shadow E6F0, keyboard IRQ, printer-status и segment enable приведены к модели; полное периферийное сравнение не выполнено |
| A38 | Diamond synthesis/MAP/PAR/TRACE/Jedecgen проходят; 5747 LUT, 8 EBR, setup/hold errors=0, unconstrained paths=0; FLASH/SD Verify проходят; фотографии подтвердили BIOS/UniDOS на text-сборке |
| A39 | Makefile воспроизводит Python, RTL, VHDL CPU и CPU/SPI firmware tests; отдельный длительный full-system target |
| A40 | Исходный CPU68 сохранён с notice/SHA-256; изменения документированы в vendor/README.md |

Diamond подтвердил вместимость выбранного MachXO2 и timing closure при
ограничениях LPF. Запуск UniDOS на плате подтверждён фотографиями пользователя
на предыдущей text-сборке. Допущения внешних таймингов — в `DIAMOND.md`.

Дополнительно исправлен доступ к чтению E6A0 после commit: без него проверка
lock в RAM-трамплине останавливалась. Интеграционный handoff тест проходит.

Текущий JED находится в `build/diamond/caps-led/impl1`, совместимый SD-образ —
`build/sd-text.img`. Шрифт включён в конфигурацию FPGA; начальный статус
доступен и без SD. CPU/SPI tests проверяют все 11 этапов, прогресс ROM/RAM-диска
и сообщения об отсутствии SD, повреждённом ROM и обрыве FAT chain.
`build/boot-status.png` и `build/boot-error.png` построены из экранной RAM
исполняемого CPU-теста и того же штатного шрифта; это не фотографии платы.

JED и SD-образ записаны на физические устройства по разрешению пользователя;
подробности проверки и журналы — в `HARDWARE.md`.
Исправления E629, Win/Caps, курсора, RGB и надписи ROM DISK описаны
в `IO-FIXES.md`. LOADER.BIN на существующей SD менять не требуется.
