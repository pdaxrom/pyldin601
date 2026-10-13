# Сборка, проверки и подготовка SD

Все команды выполняются из `pyldin601-fpga`. Исходники firmware собирает
UniAS. Нужны C-компилятор/Make; Python 3 используется для тестовых
сценариев и работы с обычными SD-образами, не как ассемблер/ROM-патчер.
Для HDL нужны Icarus Verilog и NVC 1.23+ с mixed HDL.

## ROM и приложения

```sh
make -f firmware/Makefile all UNIAS=/path/to/hd6303-toolchain/unias
make fixtures UNIAS=/path/to/hd6303-toolchain/unias
```

Первая команда создаёт ROM/PGM из ASM/INC. `fixtures` дополнительно
извлекает исходные данные и создаёт комплекты тестов/контейнеров.
Список результатов: `build/partitions`, `build/bootstrap`, `build/game`,
`build/audio`, `build/gfx`, `build/hg`, `build/storage`, `build/memory-test`.
Листинги/log/manifest сохраняются в build, не в исходниках.

Отдельные цели: `make firmware`, `game-apps`, `audio-apps`, `gfx-apps`,
`storage-apps`, `hg-apps` с тем же UNIAS. Память: отдельная цель
`make -f firmware/Makefile memory UNIAS=/path/to/unias`.
Для JPEG/PNG конвертера `make ham8conv`; зависимости libjpeg/libpng
описаны в [IMAGES.md](IMAGES.md). Полный маленький исходник и проверенная
команда PGM-сборки находятся в [PROGRAMMING.md](PROGRAMMING.md#сборка-примера).
Состав ROM и сжатие UniShell — [FIRMWARE.md](FIRMWARE.md).

## Проверки по слоям

| Слой | Цели Make |
|---|---|
| Регистры/RTL, boot header и ports | test-rtl |
| Меню/settings/SD init | test-setup, test-setup-hdl, test-sd-init |
| Общая загрузочная консоль/передача управления | test-boot-console, test-handoff |
| ISA/прерывания | test-cpu, test-hd6303, test-cpu-interrupts, test-boot-lockstep |
| SRAM/частота/шины | test-turbo, test-memory-bus |
| MBR/EBR/boot priority/LBA | test-partitions, test-boot-partitions, test-raw-sd, test-storage-software |
| RAM/BIOS/Y-код | test-ram-pages, test-ram-pages-bios, test-ram-pages-ycode, test-ram-manager |
| Клавиатура | test-keyboard-rom, test-keyboard-bios |
| Graphics/HAM/спрайты | test-gfx, test-ham-pal, test-ham-layers, test-clip-sprites |
| AY/записи/IRQ | test-ay, test-audio-app, test-audio-irq |
| GAMEBIOS/игры | test-gamebios, test-gamebios-rtl, test-xonix |
| HG/форматы/инструменты | test-hg, test-python |
| Сжатая оболочка | test-shell |
| Дисковый сектор/разные оболочки/ROM fallback, cold/warm Reset | test-shell-boot |
| Независимость ROM, отсутствие служб, перенос страниц | test-rom-modules |

```sh
make test UNIAS=/path/to/hd6303-toolchain/unias
make test-ham-layers test-xonix UNIAS=/path/to/hd6303-toolchain/unias
```

Тесты используют разные уровни: функции C-инструментов, реальные
перемещаемые PGM в эмуляторе с BIOS/UniDOS и production HDL CPU/SRAM/IO.
Нельзя считать сборку/эмулятор подтверждением физической платы или всех
частот. Логи находятся в build; матрица конкретного target определяется
его runner. У C-референса CPU есть ограничения reset/IRQ/SLP/TRAP,
поэтому специальные случаи также проверяются по архитектурной семантике,
а не только совпадением с эмулятором. Полные mixed HDL прогоны медленные.

## FPGA

Lattice Diamond 3.14, project `pyldin601_classic.ldf`, constraints
`pyldin601_classic.lpf`, device LCMXO2-7000HC-4TG144I.
Текущая graphics v6 использует PAR seed 7 и проходит setup/hold:
negative slack=0, unconstrained paths=0. Использование:
5323 LUT, 2672 slices, 2159 registers, 23 EBR, 1 PLL.
PAL/AY EBR wiring и INITVAL проверяются отдельными checkers в tests.
Журналы synthesis/MAP/PAR/TRACE и JED остаются в build.
Не заменять SRAM-10/27-нс ограничения ослабленными для получения PASS.

## SD-образ и миграция

Для новой карты готовый образ и SHA256 находятся в [images](../images/README.md).
Он не содержит пользовательские изменения физической общей SD.
Для создания собственного начального образа:

```sh
make image UNIAS=/path/to/hd6303-toolchain/unias
```

Генератор извлекает программы прежнего ROM-диска и распаковывает архивы
оригинальным UNARC. В новом образе A — прежние системные файлы, B сначала
пустой, C — распакованные программы. Готовый images/sd.img дополнительно
содержит приложения/тесты на B. `make image` не обновляет используемую карту.

Для общей карты сначала получить полную резервную копию как обычный файл:

```sh
python3 tools/migrate_sd.py --backup card-before.img --output card-new.img
python3 tools/install_game.py --image card-new.img --output card-games.img
```

Мигратор сохраняет настройки, прежние A/B и чужие разделы; добавляет том
без перемещения существующих данных. Установщик игр сохраняет записи
рекордов и пользовательский XONIX.CFG. `--apps-only` у install_game
меняет только именованные файлы B, не ROM. Программа отказывается открывать
блочное устройство: редактируются обычные образы. Получившийся размер
должен помещаться на карте. Перед установкой проверить CRC/SHA и таблицу
разделов, затем использовать точную инструкцию записи из images/README.
FAT12-профили, номера разделов и работа FDISK — [STORAGE.md](STORAGE.md).

Новый формат ROM/страничная RAM/raw PS2/music/layer v6 требуют согласованных
FPGA и обеих ROM. Не устанавливать новый ROM-container на FPGA старого
формата. Любая запись реальной общей SD должна сохранять остальные тома
и настройки; обычная сборка документации ничего на плате не записывает.
