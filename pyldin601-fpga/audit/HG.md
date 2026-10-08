# HG: удалённый FAT12-диск и время хоста

8 октября 2026. Реализован интерфейс, аналогичный uJ11 HG, для той же платы
hardware-lcd / LCMXO2-7000HC-4TG144I. Резидентный драйвер HG.PGM использует
ABI `native-src/VDISK.601`: INT 5D устанавливает блоковое устройство, INT 2C
сохраняет программу резидентной, INT 40 вызывает read/write через 5-байтовую
таблицу параметров. Первый свободный дисковод — обычно E: после A/B,
ROM-диска C и электронного диска D. Повторный HG устанавливает ещё один
дисковод; для повторной синхронизации времени используется HGTIME.PGM.

## Драйвер и время

Исходник `firmware/hg/HG.ASM` собирается UniAS в relocatable PGM: заголовок
A55A, таблица 16-битных перемещений, entry=0. HG.PGM содержит 1948 байт
кода/данных и 219 перемещений; HGTIME.PGM — 982 байта и 152 перемещения.
Это только инструкции MC6800; рабочая ISA HD6303 не требуется.
У HG отдельные буферы FAT 512 байт и каталога 66 байт в обычной памяти CPU.
Они являются частью резидентной PGM, как у оригинального VDISK.

Перед регистрацией HG читает BPB с хоста и заполняет native disk header:
размер сектора, кластер, reserved/FAT/root/total sectors, media, SPT/heads.
Драйвер работает с логическими номерами секторов; аппаратный i8272 не
участвует. Статусы переводятся в native BIOS: read-only=01h,
range=02h, checksum=04h, protocol/I/O=08h, FIFO=10h, timeout=40h.
При отсутствии хоста установка диска отменяется; циклы ожидания ограничены.

HG автоматически вызывает TIME, HGTIME делает только TIME. Используется
тот же 6-байтовый формат uJ11: RT-11 date word, high word ticks, low word ticks,
все слова little-endian; запрос содержит частоту 50 Гц. Дата преобразуется
в day/month/full binary year для INT 1F, тики — в часы, минуты, секунды и
сотые для INT 1D. Ответ и диапазон тиков проверяются до изменения даты.
Хост использует локальную дату/время, диапазон HG v1 — 1972–2035;
UniDOS SETDATE принимает даты начиная с 1980 года.

## Регистры и аппаратный интерфейс

E670–E673 находятся в штатном I/O-окне E600–E6FF и не пересекаются с SD,
FDC, PIA, MC6845 или электронным диском.

| Адрес | Значение |
|---|---|
| E670 | DATA: RX pop / TX push |
| E671 | bit 0 RX ready, bit 1 TX room, bit 2 SELECT, bit 3 TX empty, bit 6 RX overflow, bit 7 TX underflow |
| E672 | bit 0 request/TDO enable, bit 1 RX enable, bit 2 TX enable; bit 7 idle flush |
| E673 | ID=48h (`H`) |

`rtl/classic_hg.v` содержит два FIFO по 64 байта, каждый в EBR.
Счётчики занятости заменены wrap-битами read/write pointers.
RAM read ports синхронные; TDO регистрируется на 24 МГц. Это убрало
нарушения CLOCK_TO_OUT 15 нс предварительной сборки. TCK/TMS проходят
через синхронизаторы, TDI захватывается синхронно; разрешён TCK до 1 МГц.
Между внешним falling TCK и следующим rising TCK хватает времени на
синхронизацию, смену FIFO head и выходной регистр.

Отправка и получение имеют раздельные enable: TX-заголовок/данные не
порождают RX dummy-байты, а RX-данные не вызывают TX underflow. При смене
направления CPU ждёт TX empty. Idle flush разрешён только при request=0
и SELECT=0. Reset очищает интерфейс и освобождает TDO. HG не выдаёт
SRAM-запросы и не использует DMA/HOLD. CPU сам копирует данные E670↔RAM;
видео, электронный диск и существующий SRAM-арбитр сохранены.

| FT2232A | Сигнал | Вывод FPGA |
|---|---|---:|
| ADBUS0 | TCK | 131 |
| ADBUS1 | TDI | 136 |
| ADBUS2 | TDO | 137 |
| ADBUS3 | TMS / SELECT | 130 |
| ADBUS7 | JTAGENB, open-drain | 120 |

LPF задаёт `JTAG_PORT=DISABLE MUX_CONFIGURATION_PORTS=ENABLE`, как uJ11.
Высокий JTAGENB включает JTAG, низкий — GPIO. Демон проверяет уровень
ADBUS7, при SIGINT/SIGTERM возвращает его в high-Z с pull-up платы.
Физическое подключение ADBUS7 используется прежнее.

## Протокол и хост

За основу взяты локальные исходники `lsi11-fpga/host/hg` и драйверы
`uJ11-fpga/demos/rt11/hostdisk`. Wire framing, TIME и MPSSE pacing совпадают:
10 байт `HG`, version=1, operation, unit=0, LBA LE16, count LE16, XOR.
READ=1, WRITE=2, TIME=3. Размер операции 1–512 байт; драйвер диска всегда
передаёт 512. MORE/chaining этим драйвером/демоном не поддерживается.
Host сначала передаёт status; данные защищены sum16 little-endian.
Для WRITE итоговый status приходит после проверки суммы и `fsync`.

Python-демон `host/hg/hgfsd.py` использует системный libftdi1 через ctypes,
MPSSE mode 0, LSB first, 100 кГц по умолчанию. Каждый байт завершается
USB-чтением, как в uJ11. FIFO переживают паузы CPU; транспорт не зависит
от частоты CPU. UART канала B не используется этим интерфейсом.

Режим `--image` обслуживает обычный сырой FAT12-том. `--directory` создаёт
плоский FAT12 из DOS 8.3-файлов, экспортирует изменения после паузы и
проверки целостности двух FAT/цепочек. Имена хоста сохраняют прежний регистр;
новые файлы получают верхний регистр. Есть блокировка от второго демона,
read-only, отказ от symlink и журнал незавершённых изменений перед записью
сектора. После аварии сначала восстанавливается `.p601-hg.img`, затем
импортируется директория; повреждённый образ не затирается.

Default FAT12 — 32736 секторов, 8 секторов/кластер, FAT×2 по 12 секторов,
512 root entries, SPT=81, heads=2. Это 4084 кластера и максимум для этого
размера кластера/служебной области; 32737 секторов уже дают 4085 кластеров.
Проверенный пользовательский формат 32400 секторов выбирается `--blocks 32400`.
SD A/B сохраняют ограничение i8272 1,44 МиБ; HG обходится без CHS.

## Проверки

- Host tests: READ/WRITE/TIME, malformed header, count/range/status,
  checksum и read-only; MPSSE byte commands и ADBUS7 open-drain.
- FAT12: 32400 и 32736 секторов, граница 4085 кластеров, импорт/экспорт,
  удаление, имена без расширения, блокировка и восстановление после аварии.
- RTL FIFO: 1 МГц TCK с выборкой на rising edge, 64-byte pause, wrap,
  направления, overflow/underflow и Reset.
- Оригинальный BIOS/UniDOS 601 и 601A загружают настоящий HG.PGM своим
  relocator. DIR, COPY E→A→E и DEL проходят; файлы сверены по байтам.
  Проверено чтение файла из последнего data cluster 4085 и прямые
  чтение/запись последнего физического сектора 32735. Read-only, неверная
  сумма, отсутствие хоста и восстановление возвращают ожидаемые ошибки.
- Production VHDL CPU + classic_system + SRAM + FTDI pins выполняют native
  INT40 read/write и TIME резидентного драйвера с настоящими BIOS IRQ и видео
  для 601/601A на 1/2/4/8 МГц. Нет FIFO ошибок или HOLD; по 12 IRQ ack.
- Общие Python, board syntax, RTL и software boot проверки проходят.

Журналы: `build/hg-final-regression.log`, `hg-bios-601*-*.log`,
`hg-general.log`, `hg-rtl-regression.log`, `hg-boot-regression.log`.
Новый демон проверен на настоящем FT2232 Linux-хоста: MPSSE sync,
JTAGENB low и возврат high подтверждены чтением пина. Пользователь подтвердил
успешную работу HG на физической плате после проверки DIR, TYPE и COPY.

8 октября HG.PGM, HGTIME.PGM, HG.ASM и HGHOWTO.TXT записаны на B физической
SD только в пределах LBA 36864–39743. Прямое чтение и независимая проверка
на Mac подтвердили программы, сохранность MBR, boot-раздела с пользовательскими
настройками, A и прежних файлов B. Дополнительный extended-раздел
LBA 40960–122879 (40 МиБ) также сохранён и полностью сверен по байтам.
Копия первых 20 МиБ и extended-раздела, readback и отчёт записи находятся
в `build/hardware-hg-20261008`. Готовый репозиторный образ остаётся образом
с тремя разделами и настройками по умолчанию.

После возврата карты в плату демон запущен на Linux с каталогом
`/home/sash/Work/FPGA/pyldin601-hg/files`: 32736 секторов FAT12,
TCK 100 кГц. JTAGENB low подтверждён чтением пина. В каталоге находится
README.TXT для проверки чтения; журнал — `run/hgfsd.log`, PID —
`run/hgfsd.pid` в `/home/sash/Work/FPGA/pyldin601-hg`.
Демон запущен вручную и не устанавливается в автозагрузку.
Отчёт запуска — `build/hardware-hg-20261008/hg-start.json`.
Пользователь подтвердил B:HG / DIR / TYPE / COPY: «готово работает».
Созданный гостем TEST.TXT появился в каталоге хоста; все 1097 байт совпали
с README.TXT. Копии обоих файлов внутри FAT12 также сверены по байтам.
SHA-256: `d08c8f2141c4d66dd7f90563b62c849fb17536dafccd35584bca0183c151e925`.
Отчёт — `build/hardware-hg-20261008/hg-verified.json`.
Часы гостя независимо с хостом не сравнивались; TIME проверен в регрессии.

## Diamond

Diamond 3.14, Linux `sash@192.168.1.108`, чистая финальная сборка
`/tmp/pyldin601-hg.JnoURN/final`. Synthesis, MAP, PAR, TRACE, Jedecgen.

| Ресурс | Занято | Всего | Осталось |
|---|---:|---:|---:|
| LUT4 | 6698 | 6864 | 166 |
| Slices | 3409 | 3432 | 23 |
| Registers | 2160 | 7209 | 5049 |
| EBR | 16 | 26 | 10 |
| PLL | 1 | 2 | 1 |

EBR: primary BIOS 8, font 2, SD/FDD 2, PAL waveform 1, video line 1,
HG RX/TX FIFO 2. TRACE: setup/hold negative slack=0, unconstrained paths=0;
все прежние ограничения SRAM остаются обязательными в build guard.
JED, MAP/TRACE/synthesis отчёты: `build/diamond/hg/impl1`.
Фиксированные исходники: `build/diamond/source-hg-final.tar.gz` и `.sha256.json`.
Эта сборка записана во FLASH 8 октября 2026. Programmer Verify ID,
Erase,Program,Verify и JTAG Chain Verification — PASS; JTAGENB high
проверен до и после записи. Журналы: `build/hardware-hg-20261008`.
Последняя подтверждённая пользователем keyboard-pacing прошивка сохранена
для возврата. Дисковый обмен HG на физической плате подтверждён пользователем
и проверкой файла, записанного через гостевой COPY, на хосте.

Финальный JED SHA-256: `5131b049d7209af1d660ae3be1bc877be52383028e802388bb15492405a5c989`.
Архив SHA-256: `93f9c6e6cba59d79875277d0e24d4aace538a1f01d567879987e8aa0c0faf35f`.
