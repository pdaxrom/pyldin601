# Diamond

Текущая версия с HG, 8 октября 2026: 6698 LUT, 3409 slices,
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
