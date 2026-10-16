# Документация FPGA-Пълдина 601/601А

Текущие интерфейсы и руководства. История исправлений сохраняется в Git;
прототипы, журналы установок и снимки тестов не входят в справочник.

| Документ | Содержание |
|---|---|
| [HARDWARE.md](HARDWARE.md) | Характеристики, модели, native-видео, такты и SRAM |
| [REGISTERS.md](REGISTERS.md) | Все новые MMIO: биты, read/write, reset, lock, ACK и очередность |
| [BOOT.md](BOOT.md) | Питание → SD/settings → loader/CRC/SRAM → native BIOS/UniDOS; Reset |
| [MEMORY.md](MEMORY.md) | Физическая карта, RAM/ROM overlay, E6F0/E6F1, IRQ/SWI |
| [FIRMWARE.md](FIRMWARE.md) | BIOS из исходников, состав страниц, UniShell compression |
| [RAMLOADER.md](RAMLOADER.md) | ramloader: загрузка ROM в RAMMAN, SWI-шлюзы, закрепление и выгрузка |
| [CVM.md](CVM.md) | Small-C: две ROM VM, выбор CPU, host/native UniCC и UniAS |
| [FPGA-BIOS.md](FPGA-BIOS.md) | ROM INT E0/E1/E2/E3 и приватная клавиатурная служба |
| [RAM-MANAGER.md](RAM-MANAGER.md) | INT E5, банки, cookie/PCB ownership |
| [GAMEBIOS.md](GAMEBIOS.md) | INT E6 ABI 2, компактный контекст, графика/текст/AY |
| [DMA.md](DMA.md) | Общий физический DMA/блиттер, палитра и совместимость |
| [BANKCOPY.md](BANKCOPY.md) | INT E8 постоянного BIOS, копирование RAM/банков/PAL |
| [PROGRAMMING.md](PROGRAMMING.md) | Рисование/музыка, двойной буфер, полный UniAS пример |
| [GRAPHICS.md](GRAPHICS.md) | Framebuffer, blitter и PAL-порт |
| [HAM.md](HAM.md) | HAM8, таблица компонентов, наложение v6 |
| [AY.md](AY.md) | Tone/noise/envelope, divider и audio timer |
| [MUSIC.md](MUSIC.md) | YPLAY, YM/PSG/VTX/LHA, память и графика |
| [IMAGES.md](IMAGES.md) | JPEG/PNG→HAM8, HVIEW, PCX VIEW |
| [PAINT.md](PAINT.md) | Новый редактор для 601/601А: мышь, PCX/ILBM, модули, Undo/Redo |
| [KEYBOARD.md](KEYBOARD.md) | PS/2 перевод в ROM, native repeat и raw capture |
| [INPUT.md](INPUT.md) | Программный порт мыши PS/2, загружаемый указатель, UART FTDI B |
| [CPU.md](CPU.md) | ISA, дополнительные инструкции HD6303, пределы эмуляции |
| [SD-CARD.md](SD-CARD.md) | Разметка загрузочной карты, профили FAT |
| [STORAGE.md](STORAGE.md) | SD/MBR/EBR, FDISK/FORMAT/MOUNT/UMOUNT |
| [HOSTLINK.md](HOSTLINK.md) | HG, папка хоста, время, транспорт |
| [ARCADE.md](ARCADE.md) | Игры, рекорды, XONIX.CFG и память |
| [BUILD.md](BUILD.md) | Сборка firmware/FPGA, тесты, образы и миграция |

Для запуска без сборки — [готовый SD-образ](../images/README.md).
Для приложения начать с PROGRAMMING/GAMEBIOS, для изменения загрузчика
или железа — с REGISTERS/BOOT и соответствующих исходников RTL/ASM.
