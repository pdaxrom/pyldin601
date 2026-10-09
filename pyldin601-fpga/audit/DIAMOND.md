# HAM8, прямой SD и AY, 9 октября 2026

Итоговый кандидат Diamond 3.14: 5542/6864 LUT, 2782/3432 slices,
2249/7209 registers, 24/26 EBR, 1/2 PLL. Свободны 1322 LUT,
650 slices, 4960 registers, две EBR и одна PLL. i8272/автономный SD
удалены; AY использует одну EBR. HAM6 удалён, графический интерфейс v5.
Strict TRACE: setup/hold cumulative negative slack=0, unconstrained paths=0.
SRAM budgets, включая 27-нс SRAM→CPU, сохранены. Минимальный запас
96 МГц: 0,137 нс для периода EBR и 0,302 нс для обычного пути данных.

JED: `build/diamond/direct-sd-ay/pyldin601_classic_impl1.jed`, SHA-256
`1b1e8b851944f846ca351005594e1b51302fc9f1598872e2b6337158a252f473`. Замороженные 59 входов:
`build/diamond/source-direct-sd-ay-ham8-final.tar.gz` и `.sha256.json`.
Linux: `/tmp/p601-direct-sd-ay-ham8`; все 59 входов сверены после сборки.
EDIF проверен для PAL и AY: INITVAL, режимы памяти и фактические адресные
пины. AY ADA0=1 нужен для разрешения записи 9-битного слова;
проверка только поведенческой RAM не обнаруживала эту ошибку.
Модель Lattice DP8KC прошла 33164 AY-такта / 33163 независимые проверки.

9 октября обе ROM на физической SD обновлены и проверены прямым чтением.
MBR, A/B, P601.SET и 11 таблиц EBR дополнительных дисков сохранены.
FLASH Verify ID / Erase,Program,Verify и JTAG Chain — PASS; запись 66,45 с.
59 входов сверены, JTAGENB high до/после и low после запуска HG — PASS.
HG восстановлен, PID 630683; HAM/CLIPSPR/AY установлены в сетевую папку,
Лена и прочие пользовательские файлы сохранены. Пользователь подтвердил
загрузку, DIR с A/B, полный Reset удержанием 10 секунд, мелодию AY и
возврат UniDOS по ESC: «да». Модель и частота отдельно не указаны.
Отчёты: `build/hardware-direct-sd-20261009/{sd-write,result,install-result,files-install}.json`.
[API ПЗУ](FPGA-BIOS.md), [AY](AY.md), [HAM8](HAM.md).

## История: HAM6/HAM8 v4

# Diamond

HAM6/HAM8 v4, 9 октября:
6676/6864 LUT, 3348/3432 slices, 2549/7209 registers, 25/26 EBR, 1/2 PLL.
Свободны 188 LUT, 84 slices, 4660 registers, 1 EBR, 1 PLL. Оба HAM-формата
используют одну прежнюю PAL-таблицу. Strict TRACE setup/hold negative slack=0,
unconstrained paths=0; SRAM budgets и 27-нс SRAM→CPU сохранены.
Worst 96-МГц setup имеет запас 0,620 нс. EDIF и модели Lattice подтвердили
порядок всех PAL-слов, оба порта и работу на 96/24 МГц.
JED `build/diamond/ham-v4/pyldin601_classic_impl1.jed`, SHA-256
`bf7a3ab519e32300fcdde3ed95ce7e54a39d8ede2bc4eb808fcfc2aa47c1321a`.
Входы `build/diamond/source-ham-v4.tar.gz` и `.sha256.json`,
Linux `/tmp/pyldin601-ham-pipeline-strategy`. Совпадение всех фактических
входов после сборки: `build/ham/post-build-source-check.json`.
При прототипировании выявлены нарушение EBR→DAC и зависимость от фазы;
общий трёхступенчатый PAL-конвейер и полутактовый буфер исправляют их,
без изменения относительного положения картинки/sync/burst.
Подробности и нативное демо — [HAM.md](HAM.md).
FLASH Verify ID / Erase,Program,Verify, JTAG Chain и JTAGENB high до/после
прошли; 51 вход сверён, запись 69,48 с. HG восстановлен, JTAGENB low
проверен; HAM установлен, пользовательские файлы сохранены. Отчёты:
`build/hardware-ham-20261009`. Изображение HAM на плате пока ожидает
подтверждения пользователя.

## Предыдущая сборка: прозрачный COPY v3

Прозрачный COPY v3, 9 октября:
6681/6864 LUT, 3354/3432 slices, 2627/7209 registers, 25/26 EBR, 1/2 PLL.
Свободны 183 LUT, 78 slices, 4582 registers, 1 EBR и 1 PLL.
Относительно палитры v2: +38 LUT, +19 slices, +11 registers; память прежняя.
TRACE setup/hold negative slack=0, unconstrained paths=0. SRAM budgets,
27-нс SRAM→CPU и PAR seed 3 сохранены. Worst 96-МГц setup: 9,301 нс,
запас 0,950 нс; worst hold для этой частоты: запас 0,198 нс.
Первая версия соединяла сравнение ключа со счётчиками и не прошла 96 МГц.
Финальная версия регистрирует сравнение и готовит декременты/последний
столбец во время SRAM-обращения, без задержек CPU или ослабления LPF.
EDIF и модели Lattice подтвердили все PAL-адреса и оба порта палитры.
JED `build/diamond/sprites-v3-counters/impl1/pyldin601_classic_impl1.jed`,
SHA-256 `e0c6aa644f9135f3648c00807536a9ccaf88e37e02fb0861e2ba581658430595`.
Входы `build/diamond/source-sprites-v3-counters.tar.gz` и `.sha256.json`;
Linux `/tmp/pyldin601-sprites-v3-counters`. После сборки изменена только
инструкция VIEWHOW.TXT: v2 or later. Все HDL/ROM/constraints/программы
равны входам сборки: `build/sprites/post-build-source-check.json`.
SPRITES — перемещаемый HD6303 PGM, 1134 байта кода/данных,
102 relocation, 1354 байта файла. [Интерфейс и проверки](GRAPHICS.md).
FLASH Verify ID / Erase,Program,Verify, JTAG Chain и JTAGENB high до/после
прошли; запись 69,34 с. HG восстановлен, PID 608596, JTAGENB low проверен.
Файлы SPRITES и совместимого VIEW установлены, пользовательские файлы
сохранены. Отчёты — `build/hardware-sprites-20261009`;
анимацию и возврат по ESC пользователь подтвердил: «Спрайты и ESC работают».

## Предыдущая сборка: палитра v2

Программируемая палитра 256 цветов, 9 октября:
6643/6864 LUT, 3335/3432 slices, 2616/7209 registers,
25/26 EBR, 1/2 PLL. Свободны 221 LUT, 97 slices, 4593 registers,
1 EBR, 1 PLL. Относительно общего PAL-окна: +40 LUT, +22 slices,
+37 registers; EBR/PLL прежние. Шесть RGB332 waveform EBR стали
двухпортовыми 8192×1 DP8KC: порт A читает PAL, порт B записывает/читает
палитру CPU. Дополнительной памяти и FPGA-умножителей нет.
TRACE setup/hold negative slack=0, unconstrained paths=0; прежние SRAM
ограничения сохранены. PAR seed 2 дал до 0,202 нс нарушения 96-МГц
пути waiting→rows блиттера; seed 3 проходит с прежними ограничениями.
EDIF-аудит проверяет все 8192 начальных и 1024 IRGB/burst слова,
адреса обоих портов и вывод данных DIB1 для x1. Модели Lattice подтвердили
запись/чтение всех 8192 адресов и синхронную задержку.
JED `build/diamond/palette-v2-final/impl1/pyldin601_classic_impl1.jed`, SHA-256
`17512367bf251d669debba4c4f2b2a0b0ce025bc42468e12ed9d6c2e675e23d1`.
Комплект входов — `build/diamond/source-palette-v2-reviewed.tar.gz`
и `.sha256.json`. После сборки изменены только Makefile, VIEWHOW.TXT
и EDIF-аудит; равенство всех HDL/ROM/constraints/программных входов
подтверждено в `build/palette/post-build-source-check.json`.
FLASH Verify ID / Erase,Program,Verify и JTAG Chain Verification — PASS;
все 47 входов и JED проверены перед записью. FTDI JTAGENB high до/после
и low после восстановления HG — PASS. Запись заняла 67,37 с.
HG восстановлен, PID 604281; все файлы хоста сохранены во время записи.
Затем обновлены только VIEW.PGM/VIEW.ASM/VIEWHOW.TXT/PALCOEF.ASM;
C-демон автоматически пересобрал сетевой том. Лена и остальные файлы
не изменены, физическая SD не записывалась. Отчёты —
`build/hardware-palette-20261009/{result,install-result,view-install}.json`.
Все восемь VIEW/HD6303 запусков 601/601A × 1/2/4/8 МГц — PASS;
native UniDOS, все индексы/отсчёты и восстановление палитры, PAL-порт,
legacy video/переключения, блиттер и SRAM с задержками — PASS.
Сводка — `build/palette/validation.json`.
9 октября пользователь подтвердил новую палитру на плате: «да, работает!»
в ответ на проверку Лены и возврата по ESC. Модель и частота этого запуска
не указаны; все восемь сочетаний отдельно проверены в HDL.
[Порт палитры](GRAPHICS.md), [расчёт HD6303 и проверки VIEW](PCX-VIEWER.md).

Общее PAL-окно 48 мкс × 264 строки, 9 октября:
6603/6864 LUT, 3313/3432 slices, 2579/7209 registers,
25/26 EBR, 1/2 PLL. Свободны 261 LUT, 119 slices, 4630 registers,
1 EBR, 1 PLL. Относительно исправления sync: +20 LUT, +10 slices;
регистры/EBR/PLL прежние. H=12..60 мкс, V=38..301;
логические размеры 320/640 × 8×R6 и RGB332 320×200 сохранены.
TRACE setup/hold negative slack=0, unconstrained paths=0;
все прежние ограничения SRAM проходят. PAR seed 1 не прошёл 96 МГц
на gfx_done→rows (до 0,229 нс); явный seed 2 проходит без ослабления
ограничений и без изменения SRAM/блиттера.
Повторно прошли 32 поля геометрии, 28 переходов режимов, 7618560
пикселей 601A, курсор/подчёркивание/bootstrap, 512000 RGB332-пикселей,
восемь профилей SRAM 601/601A на 1/2/4/8 МГц и SRAM с задержками.
Все PAL-ROM в моделях Lattice и настоящем EDIF также проходят.
JED `build/diamond/pal-aperture/impl1/pyldin601_classic_impl1.jed`, SHA-256
`b4ca9768bdcfabbac23acacce8abbe05d4c04e865ff1c7c7f21c19709e81e9e9`.
Комплект 34 входов: `build/diamond/source-pal-aperture-final.tar.gz`
и `.sha256.json`; Linux `/tmp/pyldin601-pal-aperture-final`.
Отчёты — `build/hardware-pal-aperture-20261009/{result,install-result}.json`.
FLASH Verify ID / Erase,Program,Verify и JTAG Chain Verification — PASS;
FTDI JTAGENB high до/после и low после восстановления HG — PASS.
Запись заняла 69,06 с; файлы HG сохранены, SD не записывалась.
Физическая проверка на панели подтверждена пользователем 9 октября:
«уже нормально» — после проверки загрузчика, краёв UniDOS/часов и возврата
из VIEW по ESC.
[Геометрия и проверки](VIDEO-VIEWPORT.md).

Исправление кадровых PAL-синхроимпульсов, 9 октября:
6583/6864 LUT, 3303/3432 slices, 2579/7209 registers,
25/26 EBR, 1/2 PLL. Свободны 281 LUT, 129 slices, 4630 registers,
1 EBR, 1 PLL. Широкий импульс изменён с 29,625 до 27,25 мкс,
интервал между широкими импульсами — с 2,375 до 4,75 мкс;
строчный импульс — с 4,625 до 4,75 мкс. Окно изображения и SRAM прежние.
TRACE setup/hold negative slack=0, unconstrained paths=0.
Новый независимый тест измеряет настоящие отсчёты ЦАП за четыре поля:
64 мкс/строка, 50 Гц, импульсы 2,375/4,75/27,25 мкс и интервалы 4,75 мкс.
На старом RTL он воспроизводит неверный широкий импульс 29,625 мкс.
Повторно прошли 28 переходов режимов, 1,28 млн цветовых пикселей
и все PAL-ROM в моделях Lattice и настоящем EDIF.
JED `build/diamond/pal-sync/impl1/pyldin601_classic_impl1.jed`, SHA-256
`2b1bc509486fa3a5467d5259ef1665398277eb3a0b4afecf63732d4861e0b84b`.
Комплект 34 входов: `build/diamond/source-pal-sync.tar.gz`
и `.sha256.json`; Linux `/tmp/pyldin601-pal-sync`.
FLASH Verify ID / Erase,Program,Verify и JTAG Chain Verification — PASS;
FTDI JTAGENB high до/после и low после восстановления HG — PASS.
Запись заняла 67,54 с; файлы HG сохранены, SD не записывалась.
Отчёты — `build/hardware-pal-sync-20261009/{result,install-result}.json`.
Пользователь прислал фотографии: обрезание bootstrap, первых букв UniDOS
и часов осталось. Исправление длительностей sync не устранило этот дефект.
[Причина, параметры PAL и проверки](VIDEO-VIEWPORT.md).

Постоянный PAL burst при boot/тексте/RGB332, 9 октября:
6596/6864 LUT, 3309/3432 slices, 2587/7209 registers,
25/26 EBR, 1/2 PLL. Свободны 268 LUT, 123 slices, 4622 registers,
1 EBR, 1 PLL. Относительно сдвига окна: +6 LUT, +2 slices, −2 registers.
Единственное изменение входного RTL — удалена зависимость burst от
colour_enabled/extended; координаты окна и SRAM не изменены.
TRACE setup/hold negative slack=0, unconstrained paths=0.
Прошли bootstrap text, 32 поля геометрии, 1,28 млн цветовых пикселей,
все PAL-ROM в моделях Lattice и новый тест переходов режимов:
28 переключений, 1151999 отсчётов вне картинки, 131112 burst-отсчётов,
192000 текстовых пикселей после возврата. На старом RTL этот тест
воспроизводит отсутствие burst (такт 13962, DAC 15 вместо 8).
JED `build/diamond/pal-envelope/impl1/pyldin601_classic_impl1.jed`, SHA-256
`5c16b5a5db762789cae9b193a4b718d3bb5fa5fda4919642c03d185e5102a6fc`.
Комплект 34 входов: `build/diamond/source-pal-envelope.tar.gz`
и `.sha256.json`; Linux `/tmp/pyldin601-pal-envelope`.
FLASH Verify ID / Erase,Program,Verify и JTAG Chain Verification — PASS;
FTDI JTAGENB high до/после и low после восстановления HG — PASS.
Запись заняла 67,28 с; файлы HG сохранены, SD не записывалась.
Отчёты — `build/hardware-pal-envelope-20261009/{result,install-result}.json`.
После записи пользователь подтвердил, что сдвиг после VIEW и обрезание
bootstrap остались, включая перемещение часов. Постоянный burst
сам по себе не устранил физический сбой геометрии.
[Подробности PAL и проверок](VIDEO-VIEWPORT.md).

Сдвиг PAL-окна влево на 8 пикселей сетки 320×200, 9 октября:
6590/6864 LUT, 3307/3432 slices, 2589/7209 registers,
25/26 EBR, 1/2 PLL. Свободны 274 LUT, 125 slices, 4620 registers,
1 EBR, 1 PLL. Относительно предыдущего положения окна:
−15 LUT, −6 slices, +12 registers; EBR/PLL прежние.
Единственное изменение входного RTL — начало/конец горизонтального окна
96/496 → 86/486; ширина 50 мкс и высота 280 строк сохранены.
TRACE setup/hold negative slack=0, unconstrained paths=0;
повторно прошли 32 поля каждого отсчёта ЦАП, курсор, RGB332,
восемь профилей прозрачного SRAM-доступа и все PAL-ROM в моделях Lattice.
JED `build/diamond/pal-shift8/impl1/pyldin601_classic_impl1.jed`, SHA-256
`0afbf621f757f75ae09dfabb9a3e946af7f0a66c4bb45d8acd728f7b0380c049`.
Комплект 34 входов: `build/diamond/source-pal-shift8.tar.gz`
и `.sha256.json`; Linux `/tmp/pyldin601-pal-shift8-final`.
FLASH Verify ID / Erase,Program,Verify и JTAG Chain Verification — PASS;
FTDI JTAGENB high до/после и low после восстановления HG — PASS.
Запись заняла 68,89 с; файлы HG сохранены, SD не записывалась.
Отчёты — `build/hardware-pal-shift8-20261009/{result,install-result}.json`.
Физическое положение окна после сдвига ожидает проверки пользователя.

Полное PAL-окно, 9 октября: 6605/6864 LUT, 3313/3432 slices,
2577/7209 registers, 25/26 EBR, 1/2 PLL. Свободны 259 LUT, 119 slices,
4632 registers, 1 EBR, 1 PLL. Относительно предыдущей RGB332-ROM сборки:
−24 LUT, −14 slices, +62 registers; EBR/PLL прежние.
TRACE setup/hold negative slack=0, unconstrained paths=0;
все прежние ограничения SRAM проверены. Настоящие EBR INITVAL и модели
Lattice SP8KC/DP8KC проходят полный перебор PAL-ROM.
JED `build/diamond/pal-viewport/impl1/pyldin601_classic_impl1.jed`, SHA-256
`198caae9d844fd1dd74b8ca561ffaeb5a2789739c3b0c106fe9acb099fe96067`.
Полный комплект 34 входов, включая boot.mem:
`build/diamond/source-pal-viewport.tar.gz` и `.sha256.json`;
Linux `/tmp/pyldin601-pal-viewport-final`.
FLASH Verify ID / Erase,Program,Verify и JTAG Chain Verification — PASS;
FTDI JTAGENB high до/после и low после восстановления HG — PASS.
Запись заняла 68,43 с; все файлы HG сохранены, SD не записывалась.
Отчёты — `build/hardware-pal-viewport-20261009/{result,install-result}.json`.
[Геометрия, двойные банки и проверки](VIDEO-VIEWPORT.md).

Исправление порядка RGB332-ROM, 9 октября: 6629/6864 LUT,
3327/3432 slices, 2515/7209 registers, 25/26 EBR, 1/2 PLL.
Свободны 235 LUT, 105 slices, 4694 registers, 1 EBR и 1 PLL.
TRACE setup/hold negative slack=0, unconstrained paths=0;
все прежние ограничения SRAM проверены. Ресурсы относительно HG v2 не выросли.
JED `build/diamond/pal-rom-order/impl1/pyldin601_classic_impl1.jed`, SHA-256
`ccbf88d0b750ac044456a501a472ab911d73d38c3278dc3c771fbc5511cdea66`.
Полный комплект входов, включая `build/boot.mem`, сохранён в
`build/diamond/source-pal-rom-order.tar.gz` и `.sha256.json`;
Linux `/tmp/pyldin601-pal-rom-order`. Проверка настоящего EDIF теперь
входит в build-diamond.tcl: все 8192 RGB332 и 1024 IRGB/burst слова совпадают
с исходником. Отдельно прошли модели Lattice SP8KC/DP8KC.
FLASH Verify ID / Erase,Program,Verify и JTAG Chain Verification — PASS;
FTDI JTAGENB high до/после записи и low после запуска C-сервиса — PASS.
Отчёты записи — `build/hardware-pal-rom-20261009/{result,install-result}.json`.
[Причина неверного цвета на Лене и исправление](PCX-VIEWER.md).

Пакетный HG v2, 9 октября: 6629/6864 LUT, 3327/3432 slices,
2515/7209 registers, 25/26 EBR, 1/2 PLL. Осталось 235 LUT, 105 slices,
4694 registers, 1 EBR, 1 PLL. TRACE setup/hold negative slack и
unconstrained paths — 0; все ограничения SRAM проходят.
JED `build/diamond/hg-packets/impl1/pyldin601_classic_impl1.jed`, SHA-256
`ae479c01f8163e848a15fe97dacdb404cfbe48ac0f8a61a2530d5a44cfdf133e`.
Исходники `build/diamond/source-hg-packets.tar.gz` и `.sha256.json`;
Linux `/tmp/pyldin601-hg-packets`. Программы HG отдельно собираются UniAS.
FLASH Verify ID / Erase,Program,Verify и JTAG Chain Verification — PASS;
JTAGENB high до/после, low после запуска HG проверены.
[Протокол, USB-замер и проверки](HG.md).

Повторная сборка 9 октября с HD6303 по умолчанию в первичном BIOS:
те же 6529 LUT / 3274 slices / 2367 registers / 25 EBR / 1 PLL.
TRACE setup/hold negative slack и unconstrained paths — 0.
JED `build/diamond/view-hd-default/impl1/pyldin601_classic_impl1.jed`, SHA-256
`54f1a9ba29b26f6fcb077f39fcd7552cdd9907b5c08e806da4819fa4c82233dd`.
Исходники `build/diamond/source-view-hd-default.tar.gz` и `.sha256.json`;
Linux `/tmp/pyldin601-view-hd-default`. Аппаратная графика не менялась;
VIEW.PGM выполняется программно и не добавляет FPGA-ресурсов.
[Вьюер, формат и проверки](PCX-VIEWER.md).

Текущая версия с RGB332 и HG, 9 октября 2026: 6529 LUT, 3274 slices,
2367 registers, 25 EBR, 1 PLL. Свободны 335 LUT, 158 slices,
4842 registers, 1 EBR и 1 PLL. TRACE setup/hold negative slack
и unconstrained paths — 0. Ограничения SRAM сохранены.
[Графика, точный JED, EBR и проверки](GRAPHICS.md).

Предыдущая версия с HG, 8 октября 2026: 6698 LUT, 3409 slices,
2160 registers, 16 EBR, 1 PLL. Свободны 166 LUT, 23 slices,
5049 registers, 10 EBR и 1 PLL. TRACE setup/hold negative slack
и unconstrained paths — 0. Все 39 входов сверены; FLASH Verify ID,
Erase,Program,Verify и FTDI JTAGENB high до/после — PASS.
[Протокол, проверки и запись HG](HG.md).

Предыдущая версия с исправлением очереди PS/2, 8 октября 2026:
6525 LUT, 3326 slices, 2061 registers, 14 EBR, 1 PLL.
Свободны 339 LUT, 106 slices, 5148 registers, 12 EBR и 1 PLL.
TRACE setup/hold negative slack и unconstrained paths — 0.
SRAM→CPU worst 21,090 нс при бюджете 27 нс, запас 5,910 нс.
Прирост относительно PAL-tick версии — 10 LUT и 4 регистра, EBR прежние.
Все 36 входов сверены; FLASH Verify и FTDI JTAGENB high до/после — PASS.
[Проверки клавиатуры](KEYBOARD.md), [запись платы](HARDWARE.md).

Предыдущий BIOS Setup с SD power-up/retries, исправлением SAVE и PAL/PIA latch:
6515 LUT, 3320 slices,
2057 registers, 14 EBR. Свободны 349 LUT, 112 slices, 5152 registers,
12 EBR. TRACE setup/hold negative slack и unconstrained paths — 0.
SRAM→CPU worst 24,625 нс при ограничении 27 нс; fast clock 96 МГц.
Версия записана во FLASH с Verify и JTAGENB high до/после.
[Архив, SHA и проверки](BIOS-SETUP.md), [запись SD/FPGA](HARDWARE.md).


Предыдущая записанная сборка с переключением 1/2/4/8 МГц и оптимизированной SRAM: 6437 LUT,
3281 slices, 2044 registers, 10 EBR. TRACE setup/hold и unconstrained paths — 0.
SRAM clock 96 МГц; путь SRAM→CPU worst 22,533 нс при ограничении 27 нс.
Сборка записана во FLASH с успешным Verify и JTAGENB high до/после.
[Архив и бюджет SRAM](TURBO-SRAM.md), [журналы записи](HARDWARE.md).

Предыдущая записанная hd-tests сборка 601/601A с меню по 10 секунд: 6539 LUT, 3334 slices, 2128 registers,
10 EBR. TRACE: setup/hold negative slack 0, unconstrained paths 0;
system→CPU worst 18.525 ns при ограничении 20 ns, запас 1.475 ns.
Чистая сборка выполнена в отдельном Linux-каталоге; все этапы реально
исполнены. JED записан во FLASH с успешным Verify; FTDI JTAGENB high до/после.
[Архив, SHA, ISA и проверки](HD6303.md), [журналы записи](HARDWARE.md).
Предыдущая записанная models-ebr: 6182 LUT, 3156 slices, 2117 registers, 10 EBR.
[Её физическое подтверждение](MODELS.md).
Далее сохранена история предыдущих сборок.

## 2 октября 2026

Обычная сборка того этапа с исправленным CPU и электронным диском, без
аппаратной отладки: 5892 LUT, 3010 slices, 1898 registers, 8 EBR;
TRACE без ошибок и unconstrained paths. 2023 полупериодных пути
system→CPU, worst 13.379 ns, margin 6.621 ns.
[Удаление отладки, проверки, точный архив и JED](RELEASE.md).
Предыдущая cpu-edisk версия с отладкой: 6498 LUT, 3312 slices,
2325 registers, 14 EBR; электронный диск прошёл проверку пользователя.
Предыдущая cpu-conformance версия без диска: 6398 LUT, 3262 slices,
2339 registers, 14 EBR; worst 15.323 ns, margin 4.677 ns.
[Проверка CPU и точный архив](CPU-CONFORMANCE.md).
Предыдущая video-wrap-pipeline версия: 6594 LUT, 3364 slices,
2352 registers, 14 EBR; она дала повреждение четвёртого и шестого DIR.
Предыдущая normal-uart версия: 6444 LUT, 3287 slices, 2337 registers,
14 EBR; worst system→CPU 15.161 ns, margin 4.839 ns.
Предыдущая сборка после рефакторинга SRAM: 5829 LUT, 2980 slices,
1899 registers, 8 EBR; она также дала физический сбой на третьем DIR.
Точные исходники, JED и границы проверки — в
[RAM-ARBITRATION.md](RAM-ARBITRATION.md). Ниже сохранена история сборок.

3 октября подготовлены следующие сборки: обычная с readback CRC SRAM и
самостоятельная диагностика SRAM, обе 5745 LUT / 8 EBR, TRACE без ошибок.
Диагностическая версия записана после нового разрешения пользователя:
Program/Verify прошёл за 53 секунды, пользователь сообщил `ROUNDS 15`
без ошибок. После неё обычная версия с CRC также записана с успешным
Program/Verify за 53 секунды; она впоследствии заменена сборками выше.
Подробности и SHA — в [STABILITY.md](STABILITY.md).
Описанная ниже caps-led версия — историческая сборка до диагностики.

Сборка выполнена на разрешённой Linux-машине `sash@192.168.1.108`
в `/tmp/pyldin601-caps-led.MQKe1v`, отдельно от других проектов.
Diamond 3.14.0.75.2, Synplify V-2023.09L-2 Build349R, Ubuntu 24.04.5.
Target: LCMXO2-7000HC-4TG144I, hardware-lcd, clk_ext 12 МГц,
PLL/system 24 МГц, CPU boot 4 МГц / classic 1 МГц.
При сборке программатор и физическая плата не использовались.
Последующая запись FLASH с Verify описана в [HARDWARE.md](HARDWARE.md).

| Ресурс | Использовано | Всего | Осталось |
|---|---:|---:|---:|
| LUT4 | 5747 | 6864 | 1117 |
| Slices | 2938 | 3432 | 494 |
| Registers | 1857 | 7209 | 5352 |
| EBR | 8 | 26 | 18 |
| PLL | 1 | 2 | 1 |

Synthesis, Translate, MAP, PAR, TRACE и Jedecgen завершились успешно.
TRACE: setup errors 0, hold errors 0, unconstrained paths 0,
coverage 100%. Отдельный MAXDELAY system -> CPU 20 ns покрывает 2006
путей; худшая задержка 14.827 ns, запас 5.173 ns. Это проверяет передачу
данных за половину периода system, а не только частоту MC6800.

Прошивка: `../build/diamond/caps-led/impl1/pyldin601_classic_impl1.jed`.
SHA-256: `d4fce89e0ad9f33788e66d22c2bcb442ed55dddc0bfec564510d17258f5a2e14`.
В той же директории сохранены MRP, PAR, TWR, SRR, EDIF, PRF и build log.
Архив исходников `source-caps-led.tar.gz` и SHA каждого файла
`source-caps-led.sha256.json` сохранены в `build/diamond`.
`build-diamond.tcl` не экспортирует JED при нарушениях setup/hold,
незаданных путях или неприменённом ограничении CPU.

В этой версии первичный BIOS включает текстовый экран 40×24 и показывает
этапы загрузки до первого SD command. Штатный шрифт заранее размещён в тех
же 2 EBR через INITVAL; SD-загрузчик может заменить его без переконфигурации
FPGA. Распределение EBR: boot ROM 4 EBR, font 2 EBR,
секторный буфер SD/FDD 2 EBR. Для экранных этапов после запуска LOADER.BIN
подготовлен образ `build/sd-text.img`. LOADER.BIN в текущей версии не менялся;
существующая карта совместима с исправлениями клавиатуры/курсора/RGB.

Предыдущая text-сборка сохранена в `build/diamond/text`: 5739 LUT,
2934 slices, 1898 registers, те же 8 EBR. Текущая версия исправляет
readback E629, курсор, Win/Caps и RGB; описание — в `IO-FIXES.md`.
Предыдущая io-сборка сохранена в `build/diamond/io`: 5759 LUT, 8 EBR.
В caps-led-сборке инвертирован красный индикатор по физической проверке
пользователя; PIA readback и клавиатурное состояние не менялись.

## Почему первоначально было 22375 LUT

Основная память машины уже находилась во внешней SRAM. Раздувание создала
512-байтовая SD RAM с асинхронными чтениями и двумя независимыми местами
записи: она синтезировалась в триггеры и мультиплексоры, а не EBR.
В исходном EDIF только SD backend занимал 10152 ORCALUT4 и 4379 FF.
Ещё 2213 ORCALUT4 расходовала клавиатура с индексируемой картой 512
удерживаемых клавиш. Эти значения относятся к synthesis netlist, а не
к окончательной сумме LUT4 MAP, включающей carry/distributed RAM.

Исправления: у SD один RAM write port и синхронные read ports с prefetch;
boot ROM и font RAM явно выводятся в EBR; удержание клавиш учитывается
в активной клавише и очереди; арифметика геометрии ограничена реальным
классическим диапазоном 80×2×18. Промежуточный MAP: 7943 LUT / 8 EBR,
затем 5921 LUT / 8 EBR; итоговая версия со слотами SRAM — 5739 LUT / 8 EBR.
Аппаратный FDD-контроллер сохранён во всех этих версиях.

## Допущения внешних таймингов

Ниже описаны тайминги исторической caps-led сборки. Текущая SRAM-10
последовательность на 96 МГц и её ограничения — в [TURBO-SRAM.md](TURBO-SRAM.md).

Схема hardware-lcd указывает IS61WV102416BLL-10; ограничения проверены
также с более медленными значениями -20 из приложенного datasheet.
Текущий контроллер имеет отдельный setup-такт, два access-такта,
hold и release. OE активен два периода system до read capture;
WE low также два периода при записи. Адрес, CE, byte lanes и DQ
удерживаются ещё один такт после rising WE. Слоты CPU/видео 3/9,
10/16 и 17/23; подробная последовательность — в [RAM-ARBITRATION.md](RAM-ARBITRATION.md).
LPF: clock-to-pad <=15 ns; input setup >=10 ns, hold >=5 ns.
Для чтения бюджет 15 ns output +20 ns SRAM +4 ns PCB +10 ns input
меньше двух периодов 24 МГц (83.3 ns). При записи минимальный WE pulse
с учётом разброса pad delay >=68.3 ns, требование SRAM-20 <=17 ns;
адрес и данные остаются стабильными после конца записи.
PCB budget 4 ns — принятое допущение, измерения платы не проводились.

Boot/FDC SPI используют divider 1 (SCK 6 МГц); MISO имеет 10 ns setup
и 5 ns hold относительно system. MISO меняется на falling SCK,
следующий после sampling rising SCK через 83.3 ns. Прямой SPI ABI
позволяет программно изменить divider; STA здесь не подтверждает
электрическую работоспособность всех SD-карт на произвольной скорости.
PS/2 и кнопка reset асинхронны и исключены только от входных портов
до первых synchronizer stages; внутренних clock domains не исключаем.

Предупреждение MAP: UART RX `rxd` не используется и удалён синтезом;
TX удерживается в idle. Это не относится к SD/FDD/PS2/TV.
Перед прошивкой нужно сверить установленную FPGA, кварц и SRAM.
Физические наблюдения учитываются отдельно от fit/STA и Programmer Verify.
Для текущей 601/601A пользователь подтвердил запуск 601A, текст 80 колонок
и DIR; цветные режимы 601A пока проверены только в симуляции.


## HG, 8 октября 2026

Текущая сборка с HG прошла чистые synthesis/MAP/PAR/TRACE/Jedecgen:
6698/6864 LUT, 3409/3432 slices, 2160/7209 registers, 16/26 EBR,
1/2 PLL. Свободны 166 LUT, 23 slices и 10 EBR. HG использует два
64-байтовых FIFO в EBR, без доступа к SRAM. TDO регистрируется на 24 МГц;
все CLOCK_TO_OUT и прежние ограничения SRAM проходят. Setup/hold negative
slack и unconstrained paths — 0. JTAG-пины переключаются через JTAGENB,
как в uJ11. Прошивка HG записана во FLASH 8 октября 2026;
Verify ID / Erase,Program,Verify прошли без ошибок, JTAGENB high проверен до/после.
[Исходники, отчёты, протокол и проверки](HG.md).
