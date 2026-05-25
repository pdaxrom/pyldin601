# Эмуляторы Pyldin-601

В этом репозитории собирается один исполняемый файл, который умеет запускать две модели:

- `Pyldin-601`, оригинальный компьютер на MC6800, частота CPU 1 MHz.
- `HD6303`, новая FPGA-модель на HD6303, частота CPU 4 MHz.

При запуске GUI без параметра `-m` приложение показывает выбор модели. Для прямого запуска из командной строки:

```sh
./Pyldin-601 -m 601
./Pyldin-601 -m hd6303
```

Полезные параметры:

```text
-m <601|hd6303>  модель компьютера
-d <dir>         каталог данных с Bios/Rom/Floppy/Hd6303
-t               установить дату и время из host-системы
-i               показывать текущую скорость CPU
-p <type>        printer port: file, system или covox
```

## Каталог данных

Desktop bundle и install tree содержат такой набор данных:

```text
share/pyldin/
  Bios/
  Floppy/
  Rom/
  Hd6303/
    Bios/
    Rom/
    SD/
  shaders/
```

Источники в checkout:

```text
native/Bios/
native/Floppy/
native/RAMROMDiskPipnet/
native-hd6303/Hd6303/
pyldin601/shaders/
```

HD6303-режим сейчас всегда открывает SD image:

```text
Hd6303/SD/lil601.img.gz
```

Если нужно проверить другой образ, положи его под этим именем в `native-hd6303/Hd6303/SD/` или в `Hd6303/SD/` выбранного `-d` каталога. Файл `lil601-fat16.img.gz` в репозитории является примером FAT16 SD image, но сам эмулятор не выбирает его автоматически, пока он не переименован или не скопирован в `lil601.img.gz`.

## SD в HD6303

Эмулятор читает gzip-сжатый raw SD image целиком в память. При записи через SPI SD image помечается dirty и при завершении эмулятора сохраняется обратно в тот же `.gz`.

Поддерживаемые варианты загрузки:

- Raw FAT12 без MBR: boot sector находится в LBA0 SD image.
- MBR с разделами FAT12/FAT16: boot sector находится в первом секторе выбранного раздела.

Важно: для FAT16 загрузочный сектор UniDOS должен быть записан в boot sector FAT16-раздела, а не в LBA0 всего SD image. LBA0 у partitioned image остается MBR.

SimpleIO печатает найденные разделы на экран:

```text
SD partitions:
 P1 boot type $06 fs FAT16 lba $00000800 size ...
```

Поддерживаемые типы MBR:

```text
0x01      FAT12
0x04      FAT16
0x06      FAT16
0x0e      FAT16 LBA
0x0b/0x0c FAT32 определяется и печатается, но сейчас не монтируется
```

Текущий FAT16-код использует 16-битное поле BPB `TotalSectors16`, поэтому практический размер раздела лучше держать до 65535 секторов. Рабочий пример в репозитории: SD image 32 MiB, первый active FAT16-раздел начинается с LBA 2048 и имеет 63488 секторов.

## Обязательные файлы для загрузки

В корне загрузочной файловой системы должен лежать:

```text
UNIDOS.CMD
```

Boot sector ищет именно это имя в формате 8.3. Имя лучше писать в верхнем регистре.

Утилита UniDOS `MAKEBOOT.CMD` устанавливает загрузочный сектор на выбранный UniDOS drive/partition. Она сохраняет BPB файловой системы и заменяет только boot code:

- байты `0x000..0x00a`
- байты `0x04d..0x1ff`

То есть геометрия FAT, размер кластера, число FAT и прочие BPB-поля остаются от `mkfs.fat` или `SDFORMAT.CMD`.

## Быстро: создать образ из существующего шаблона

Это самый надежный способ на macOS, потому что не нужно вручную создавать MBR.

Нужны `mtools` и `gzip`. Пример использует `UNIDOS.CMD` из FPGA checkout:

```sh
export EMU=/Users/sash/Work/P601/pyldin601
export FPGA=/Users/sash/Work/FPGA/PYLDIN601-HD6303
export UNIDOS=$FPGA/SW/SRC/UNI/UNIDOS.CMD
mkdir -p /tmp/pyldin-sd
```

### FAT12 raw image

```sh
gzip -dc "$EMU/native-hd6303/Hd6303/SD/lil601.img.gz" > /tmp/pyldin-sd/lil601.img
mcopy -o -i /tmp/pyldin-sd/lil601.img "$UNIDOS" ::UNIDOS.CMD
gzip -9 -n -c /tmp/pyldin-sd/lil601.img > "$EMU/native-hd6303/Hd6303/SD/lil601.img.gz"
```

### FAT16 partitioned image

В примере первый раздел начинается с LBA 2048, значит byte offset равен `2048 * 512 = 1048576`.

```sh
gzip -dc "$EMU/native-hd6303/Hd6303/SD/lil601-fat16.img.gz" > /tmp/pyldin-sd/lil601.img
mcopy -o -i /tmp/pyldin-sd/lil601.img@@1048576 "$UNIDOS" ::UNIDOS.CMD
gzip -9 -n -c /tmp/pyldin-sd/lil601.img > "$EMU/native-hd6303/Hd6303/SD/lil601.img.gz"
```

После этого desktop bundle надо обновить, если запускается staged app:

```sh
cd "$EMU/pyldin601"
cmake --build out/build/release --target bundle
```

## С нуля: FAT12 raw image

Нужны `dosfstools` (`mkfs.fat`) и `mtools`.

```sh
export EMU=/Users/sash/Work/P601/pyldin601
export FPGA=/Users/sash/Work/FPGA/PYLDIN601-HD6303
export UNIDOS=$FPGA/SW/SRC/UNI/UNIDOS.CMD
mkdir -p /tmp/pyldin-sd
cd /tmp/pyldin-sd

dd if=/dev/zero of=lil601.img bs=512 count=32400
mkfs.fat -F 12 -S 512 -s 8 -r 512 -n UniDOS lil601.img
mcopy -o -i lil601.img "$UNIDOS" ::UNIDOS.CMD
```

Если нужен SD-файл ровно 32 MiB, его можно расширить после форматирования. BPB FAT12 останется на 32400 секторов, а хвост SD image будет неиспользуемым:

```sh
truncate -s 32M lil601.img
```

Установить UniDOS boot code, сохранив BPB, можно из существующего bootable FAT12 image. Эта команда должна брать именно boot sector файловой системы. Если `lil601.img.gz` уже заменен на partitioned image, возьми шаблон из `lil601-fat16.img.gz` с `skip=2048`.

```sh
gzip -dc "$EMU/native-hd6303/Hd6303/SD/lil601.img.gz" | dd of=unidos-bootsec.bin bs=512 count=1
dd if=unidos-bootsec.bin of=lil601.img bs=1 count=11 conv=notrunc
dd if=unidos-bootsec.bin of=lil601.img bs=1 skip=77 seek=77 count=435 conv=notrunc
```

Упаковать для эмулятора:

```sh
gzip -9 -n -c lil601.img > "$EMU/native-hd6303/Hd6303/SD/lil601.img.gz"
```

## С нуля: FAT16 partitioned SD image

Нужны `sfdisk`, `dosfstools` и `mtools`. Этот пример создает 32 MiB SD image с одним active FAT16-разделом:

```sh
export EMU=/Users/sash/Work/P601/pyldin601
export FPGA=/Users/sash/Work/FPGA/PYLDIN601-HD6303
export UNIDOS=$FPGA/SW/SRC/UNI/UNIDOS.CMD
mkdir -p /tmp/pyldin-sd
cd /tmp/pyldin-sd

truncate -s 32M lil601-fat16.img
printf 'label: dos\nunit: sectors\n\n2048,63488,6,*\n' | sfdisk lil601-fat16.img

dd if=/dev/zero of=part-fat16.img bs=512 count=63488
mkfs.fat -F 16 -S 512 -n UNIDOS part-fat16.img
mcopy -o -i part-fat16.img "$UNIDOS" ::UNIDOS.CMD
```

Установить UniDOS boot code в boot sector раздела. Здесь шаблон берется из boot sector первого раздела `lil601-fat16.img.gz`, а не из LBA0:

```sh
gzip -dc "$EMU/native-hd6303/Hd6303/SD/lil601-fat16.img.gz" | dd of=unidos-bootsec.bin bs=512 skip=2048 count=1
dd if=unidos-bootsec.bin of=part-fat16.img bs=1 count=11 conv=notrunc
dd if=unidos-bootsec.bin of=part-fat16.img bs=1 skip=77 seek=77 count=435 conv=notrunc
```

Скопировать готовый раздел внутрь SD image начиная с LBA 2048:

```sh
dd if=part-fat16.img of=lil601-fat16.img bs=512 seek=2048 conv=notrunc
gzip -9 -n -c lil601-fat16.img > "$EMU/native-hd6303/Hd6303/SD/lil601.img.gz"
```

Не записывай `unidos-bootsec.bin` в LBA0 `lil601-fat16.img`: там должен остаться MBR.

## Утилиты внутри UniDOS

`SDFORMAT.CMD` форматирует raw FAT12 SD-образ старого типа. Она полезна для простой FAT12-карты без MBR.

`MAKEBOOT.CMD` ставит загрузочный сектор на выбранный drive/partition:

```text
A:\>MAKEBOOT
Boot drive/partition (A-Z)? A
FAT12 boot sector
Completed
```

Для FAT16-раздела выбирается буква смонтированного раздела. Утилита должна напечатать `FAT16 boot sector`. Если она пишет `Not FAT12/FAT16 boot sector`, значит выбран не FAT12/FAT16 boot sector или у файловой системы нет ожидаемой BPB-сигнатуры `FAT12`/`FAT16`.

## Проверка образа

Проверить тип raw FAT12:

```sh
gzip -dc native-hd6303/Hd6303/SD/lil601.img.gz | file -
```

Проверить MBR FAT16:

```sh
gzip -dc native-hd6303/Hd6303/SD/lil601.img.gz | file -
```

Проверить boot sector FAT16-раздела с LBA 2048:

```sh
gzip -dc native-hd6303/Hd6303/SD/lil601.img.gz | dd bs=512 skip=2048 count=1 2>/dev/null | strings -a
```

В выводе должны быть `UniDOS`, `FAT16` и `UNIDOS.CMD`.
