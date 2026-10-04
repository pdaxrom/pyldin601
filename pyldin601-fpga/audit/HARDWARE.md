# Запись SD и FPGA

## Последняя записанная версия: PAL/PIA latch, 4 октября 2026

Пользователь подтвердил холодный запуск предыдущей SD-init версии, но
полный Reset давал STEP 01 на любой частоте. Диагностическая сборка
`41590c3bebfee3ede741a489435d48f79d53762370af18cb49c59875582cc3d3`
показала `00 FF FF 37 A3`: потеря первого PAL tick до CMD0, SPI свободен.
Воспроизведена гонка чтения E62B с установкой 50-Гц latch. Новый импульс
теперь имеет приоритет над очисткой, сохраняется для следующего чтения.

Записан `build/diamond/pal-tick/impl1/pyldin601_classic_impl1.jed`, SHA-256
`92c426a53eeacddd2769d49ba640b868056563f784b7c45cc6a74050910f24f8`.
Все 36 входов сверены с `source-pal-tick.sha256.json`. Diamond:
6515 LUT, 3320 slices, 2057 registers, 14 EBR; TRACE setup/hold negative
slack и unconstrained paths — 0. SRAM→CPU 24,625 нс при пределе 27 нс.
FLASH Verify ID / Erase,Program,Verify и JTAG Chain Verification успешны.
FTDI `hgfsd --jtag-only` подтвердил JTAGENB high до/после. Wall time
67,71 секунды. SD не записывалась: P601.SET, ROM и диски A/B сохранены.

Проверки: старый RTL теряет совпавший tick; новый проходит с пустой и
установленной защёлкой и после полного Reset. Прошли 12 SD-init случаев,
HDL handoff/warm reset, штатные IRQ/RTI, SRAM 1/2/4/8 МГц, HDL SAVE
и загрузка LOADER.BIN. Пользователь подтвердил успешный полный Reset
и загрузку системы с этой прошивкой 4 октября 2026 года.
Linux-каталог: `/tmp/pyldin601-pal-tick.laSwcV/hardware-pal-tick`;
локальные журналы/XCF/result — `build/hardware-pal-tick`. Диагностическая
запись и её журналы — `build/hardware-sd-reload`.

## Предыдущая записанная версия: SD power-up и retries, 4 октября 2026

По сообщению пользователя редкий cold boot останавливался на STEP 01,
до чтения разделов/конфигурации. Старый BIOS воспроизвёл отказ в модели
карты, не отвечающей первые 700 мс. Добавлены минимум 300 мс с CS high
до CMD0, начальные такты перед каждой попыткой, повтор CMD0/CMD8 и
ожидание CMD55/ACMD41 по PAL до примерно двух секунд. SD остаётся
на 400 кГц до окончания инициализации. [Проверки и границы](BIOS-SETUP.md).

Записан `build/diamond/sd-init/impl1/pyldin601_classic_impl1.jed`,
SHA-256 `7e71a30abafcb4833a1b1dbec295da2cfed0dc790676ffe50208f30677ab14ff`.
Все 36 входов совпали с `source-sd-init.sha256.json`; TRACE setup/hold
negative slack и unconstrained paths — 0. FLASH Verify ID /
Erase,Program,Verify и JTAG Chain Verification успешны. Через FTDI
`hgfsd --jtag-only` подтвердил JTAGENB high до и после записи.
Wall time — 67,43 секунды. SD не перезаписывалась; P601.SET и A/B сохранены.

Linux-каталог: `/tmp/pyldin601-sd-init.QPJS90/hardware-sd-init`.
Локальные журналы, XCF и result.json — `build/hardware-sd-init`.
Пользователь подтвердил холодный запуск; после полного Reset обнаружена
регрессия ожидания PAL tick, исправление описано выше.

## Предыдущая записанная версия: исправление SAVE, 4 октября 2026

После первоначальной записи BIOS Setup пользователь показал ложную ошибку
`SAVE FAILED - CHECK SD`: сохранённые 601A / HD6303 Y / 4 МГц прочитались
после выключения и включения. Симптом воспроизведён со старым resident BIOS
при снятии SD busy внутри байта. Исправление ожидания FFh проверено
39 программными сценариями и настоящим HDL CPU/SPI.
[Причина и границы проверки](BIOS-SETUP.md).

Записан `build/diamond/bios-save-busy/impl1/pyldin601_classic_impl1.jed`,
SHA-256 `f4110aeaef3decc7747cc37e32aa60551ad2add7c8d8c0cb64972e200f9d3b58`.
Все 36 входов совпали с `source-bios-save-busy.sha256.json`;
TRACE setup/hold negative slack и unconstrained paths — 0.
FLASH Verify ID / Erase,Program,Verify и JTAG Chain Verification успешны.
`hgfsd --jtag-only` подтвердил JTAGENB high через FTDI до и после записи.
Wall time — 67,42 секунды. SD не записывалась; исправление находится в
EBR первичного BIOS, выбранная пользователем конфигурация сохраняется.

Linux-каталог: `/tmp/pyldin601-bios-save-busy.BWOhrR/hardware-bios-save-busy`.
Локальные журналы Programmer, XCF и result.json — `build/hardware-bios-save-busy`.
Успешный SAVE исправленной версии на физической карте пока не подтверждён.

## Предыдущая записанная версия: BIOS Setup и Reset 10 секунд, 4 октября 2026

По запросу пользователя обновлены SD и FLASH FPGA. Записан
`build/diamond/bios-setup-final/impl1/pyldin601_classic_impl1.jed`, SHA-256
`51a4175f3e6af96339a38b61b1da346c03a1b84d53cfd021440896928df2c965`.
Все 36 входных файлов совпали с source-bios-setup-final.sha256.json;
TRACE setup/hold negative slack и unconstrained paths — 0.
FLASH Verify ID подтвердил LCMXO2-7000HC. Erase,Program,Verify и JTAG
Chain Verification успешны. uJ11 hgfsd --jtag-only через FTDI подтвердил
JTAGENB high до и после записи. Programmer — 56 секунд, wall — 67,88 секунды.

SD сверена по прежнему by-id, размеру 7988051968 байт, removable и отсутствию
mount. До записи первые 20 МиБ сохранены на Linux и Mac, SHA сверена.
В первый раздел добавлен P601.SET (601, расширение N, 1 МГц). Записаны
только 16 МиБ на LBA 2048; прежние boot-файлы, MBR и текущие A/B сохранены.
После fsync выполнено прямое чтение 20 МиБ; результат совпал с подготовленным
образом. На Mac повторно сверены SHA и файлы, выполнен программный boot
прочитанного образа. На момент этой записи первый раздел совпал с готовым images/sd.img;
текущие A/B физической карты отличаются от A/B готового образа и не заменялись.

| Данные | SHA-256 |
|---|---|
| Резервная копия 20 МиБ | `348fd7ef8ee1b3fe4664e72c575f6e71f3974e794d756192ec1b0277ccb81fd9` |
| Обновлённые / прочитанные 20 МиБ | `11428fd0023979e8f2798a81a7072173224f2474b320d8ca9360310443b84d60` |
| Первый раздел | `d831f587e7e0d48ec65a5254a7c6739df54f6f4ce382fbecdd4f4134fc7f8ecb` |

Linux-каталог: `/tmp/pyldin601-bios-setup-final.D3czl7/hardware-bios-setup`.
Локальные копии, XCF, журналы и отчёты — `build/hardware-bios-setup`:
sd-before.img, sd-after.img, sd-readback.img, sd-write.json, result.json,
update-result.json, program.log, jtag-before.log и jtag-after.log.
Позже пользователь подтвердил меню и чтение сохранённых настроек после
включения, но SAVE показал ошибку (см. исправление выше).
Физическая проверка Reset 10 секунд ещё не получена.
[Поведение и проверки](BIOS-SETUP.md).

## Предыдущая записанная версия: частоты и SRAM, 4 октября 2026

По запросу пользователя записан
`build/diamond/turbo-final/impl1/pyldin601_classic_impl1.jed`, SHA-256
`c3aa29a6fa656c08df8a93feadda8228970020ed9094521d9d9919ea69e42cdc`.
Все 34 входных файла совпали с `source-turbo-final.sha256.json`;
TRACE setup/hold negative slack и unconstrained paths — 0.

Рабочий каталог Linux: `/tmp/pyldin601-turbo-final.0qohlD/hardware-turbo`.
FTDI был свободен перед записью. uJ11 `hgfsd --jtag-only` подтвердил
высокий JTAGENB до и после. FLASH Verify ID подтвердил LCMXO2-7000HC;
FLASH Erase,Program,Verify и JTAG Chain Verification завершились без ошибок.
Время Programmer — 55 секунд, wall time — 66,78 секунды.
Журналы, XCF и result.json сохранены в `build/hardware-turbo`.

Короткое нажатие Reset переключает 1/2/4/8 МГц, длинное около двух секунд
вызывает warm reset с возвратом на 1 МГц. Индикатор показывает частоту;
при bootstrap — 04. SRAM работает на 96 МГц, слот 62,5 нс, без HOLD.
SD не перезаписывалась. Физическая проверка новых частот и таймингов
пользователем ещё не получена. [Расчёты и тесты](TURBO-SRAM.md).

## Проверка звука, 4 октября 2026

Пользователь подтвердил наличие звука на аудиовыходе платы и сообщил,
что без внешнего усилителя громкость небольшая. В текущем RTL бит 3
регистра E62B управляет speaker, а `audio={2{speaker}}` дублирует сигнал
на оба канала. LPF и схема hardware-lcd согласованы: audio[0] —
AUDIO_R/PL15A, вывод FPGA 21; audio[1] — AUDIO_L/PL15B, вывод 22.
Это монофонический однобитный выход; регулировка громкости не реализована.

## Обновление SD: тесты HD6303 на B, 4 октября 2026

По запросу пользователя обновлена карта в Linux-кардридере
`sash@192.168.1.108`. Устройство сверено по
`/dev/disk/by-id/usb-Generic_MassStorageClass_000000001210-0:2` → `/dev/sdf`,
размеру 7988051968 байт и признаку removable; все разделы не смонтированы.
Перед записью сохранены первые 20 МиБ карты и отдельно том B. Резервная
копия перенесена на Mac, её SHA-256 сверена до начала записи.

Из свежей копии подготовлено добавление семи файлов в B: HDTEST.CMD,
HDMUL.CMD, HDSLEEP.CMD, их ASM-исходники и README.TXT. Перед обновлением
B был пустым. На карту записаны только 1474560 байт третьего раздела:
LBA 36864, 2880 секторов. MBR, первый раздел, A и область после B не записывались.
Перед записью повторно сверены устройство, отсутствие mount и содержимое
карты с резервной копией; открыт эксклюзивный дескриптор устройства.

После `fsync` выполнено прямое чтение первых 20 МиБ (`dd iflag=direct`).
Прочитанные байты совпали с подготовленным образом. Повторная проверка на
Mac подтвердила сохранность MBR/boot/A и SHA-256 всех семи файлов против
`build/hd6303-apps`. Изменений FPGA этой операцией не выполнялось.

| Данные | SHA-256 |
|---|---|
| Резервная копия первых 20 МиБ | `99a4ee4151ae58b04eac1970db94eb485babaaabd2c49e643d38c53c6e0b85e4` |
| Обновлённые / прочитанные первые 20 МиБ | `bd6c8c0b3fc60924a005e9883b0818603603c100c5d51a509e2dc91bbc4a057f` |
| Записанный том B | `d7f81f7b1fa653a8ef6276f042b8e1097e9ee3980905635f338bcb9d8e6b970c` |

Локальные копии/отчёты — `build/hardware-sd-hd-tests/sd-before.img`,
`sd-after.img`, `sd-readback.img`, `prepared.json`, `sd-write.json`;
на Linux — `/tmp/pyldin601-sd-hd-tests.h1BwW4`. Основной `build/sd.img`
заменён проверенным `sd-after.img` и совпадает с чтением карты. Прежний
основной образ сохранён как `sd-main-before.img`; отчёт — `main-image.json`
в том же локальном каталоге. После `fsync` разделы
остались не смонтированными. `udisksctl power-off` не выполнился из-за
отсутствия авторизации polkit; отключение питания кардридера не подтверждено.
Результат исполнения программ на физической плате ещё не получен.
[Запуск тестов](../tests/hd6303/README.md), [карта и образы](../SD-card.md).

Проверенный образ добавлен в репозиторий как `images/sd.img` (20 МиБ).
Он совпадает с `sd-readback.img`; `images/SHA256SUMS` и `images/sd.json`
фиксируют контрольные суммы. [Запись карты и первый запуск](../images/README.md).

## Предыдущая записанная версия: меню 10 секунд, 4 октября 2026

Записан `build/diamond/hd-tests/impl1/pyldin601_classic_impl1.jed`, SHA-256
`eefc5b75bdaf7e7e95b0917c857057e8c57fa97759aa33d99fd65e7e565065e0`.
31 входной файл совпал с `build/diamond/source-hd-tests.sha256.json`.
FLASH Verify ID / Erase,Program,Verify и JTAG Chain Verification успешны.
Programmer: 56 секунд, wall: 66.99 секунды. uJ11 `hgfsd --jtag-only`
подтвердил высокий JTAGENB через FTDI до и после записи.
Журналы/XCF/result — `build/hardware-hd-tests`.

Оба меню теперь ждут 500 PAL ticks, по 10 секунд; выборы и сохранение при
Reset прежние. При записи JED SD не менялась; затем отдельной операцией
обновлён B, как описано выше. [Подготовка и запуск](../tests/hd6303/README.md).
Физическая проверка этих программ пользователем ещё не выполнена.

## Предыдущая версия с выбором CPU, 3 октября 2026

Записан `build/diamond/cpu-isa/impl1/pyldin601_classic_impl1.jed`:
SHA-256 `769bfaa459ff931c37fadc91da779bcd9cd948c4e153900ff25d2b2d490753e8`.
Все 31 входной файл совпали с `build/diamond/source-cpu-isa.sha256.json`.
FLASH Verify ID и Erase,Program,Verify завершились успешно;
JTAG Chain Verification без ошибок. Programmer: 56 секунд, wall: 67.19 секунды.
uJ11 `hgfsd --jtag-only` подтвердил высокий JTAGENB через FTDI до и после.
Журналы/XCF/result — `build/hardware-cpu-isa`.

После выбора 601/601A отдельное меню выбирает MC6800 или HD6303 ISA;
по умолчанию MC6800, таймаут 5 секунд. Меню находится в FPGA ROM,
SD не перезаписывалась. Физическая проверка выбора CPU пользователем
ещё не выполнена. [Файл, ресурсы и проверки](HD6303.md).

## Предыдущая записанная версия 601/601A, 3 октября 2026

Записан `build/diamond/models-ebr/impl1/pyldin601_classic_impl1.jed`:
SHA-256 `23aed1527bf33304f413f177a7ca2452ccff7d694c418609a0bec872bd603398`.
Все 31 входной файл совпали с `build/diamond/source-models-ebr.sha256.json`.
FLASH Verify ID и Erase,Program,Verify успешны, wall time 66.45 секунды.
uJ11 `hgfsd --jtag-only` и FTDI readback подтвердили высокий JTAGENB
до и после записи. Журналы/XCF/result — `build/hardware-models`.

На SD обновлены только 16 МиБ первого раздела со смещения 1 МиБ:
текущий LOADER.BIN, прежний P601.ROM, новый P601A.ROM и P601.CFG.
Прямое чтение подтвердило записанный том; MBR и диски A/B сохранены
побайтно. Копии/отчёт — `build/sd-models/sd-before.img`, `sd-after.img`,
`sd-write.json`. [Разметка и подготовка обновления](../SD-card.md).

Пользователь подтвердил: 601A загрузился, текст 80 колонок и DIR работают.
Аппаратная runtime-отладка выключена, электронный диск включён.
Цветные режимы 601A физически ещё не подтверждены; ранее пользователь
подтвердил цвет классической 601 и электронный диск.

## Первоначальная запись, 2 октября 2026

По явному разрешению пользователя JED записан во внутреннюю FLASH
LCMXO2-7000HC на Linux-машине `sash@192.168.1.108` через Diamond Programmer
3.14. Рабочий каталог: `/tmp/pyldin601-text.sjnVRH/hardware-20261002`.

Перед Programmer выполнен тот же `hgfsd --jtag-only`, что используется у
uJ11. FT2232D ADBUS7 переведён во вход/high-Z; подтяжка платы поднимает
JTAGENB. Высокий уровень подтверждён чтением FTDI до проверки ID и после
прошивки. Активных владельцев FTDI перед операцией не было.

Сначала `FLASH Verify ID` подтвердил LCMXO2-7000HC. Затем
`FLASH Erase,Program,Verify` завершился с кодом 0 и `Operation: successful`;
JTAG Chain Verification также без ошибок. Время Programmer — 54 секунды.
JED: `build/diamond/text/impl1/pyldin601_classic_impl1.jed`.
SHA-256: `c51796333ff6c8c8eaf39954f77747b9d807a77f578061584d4908c3ec6d82ac`.

После вставки пользователем SD-карта появилась как единственный заполненный
слот USB-кардридера: `/dev/sdf`, 7988051968 байт, removable=1,
`/dev/disk/by-id/usb-Generic_MassStorageClass_000000001210-0:2`.
Смонтированных разделов не было. Записаны первые 20971520 байт из
`build/sd-text.img`; запись сброшена через fsync, затем область прочитана
повторно через `dd iflag=direct`.
SHA-256 образа и чтения совпал:
`c4814e9490d8936be896322ed7b85649ddacde4b226a0f8aa90d1128ff58a003`.

До записи сохранена точная копия перезаписываемой области:
`build/hardware-20261002/sd-prefix-before.img`, 20 МиБ,
SHA-256 `ffa7fc69f6929f87bd23c4e4552d3ad3ab4f7f1c61d9e614c2eafcf35fba7e0e`.
Это копия первых 20 МиБ; остальная область карты не перезаписывалась.
Полные журналы Programmer, XCF, отчёт записи SD и копия сохранены локально
в `build/hardware-20261002`.

Удалённый `udisksctl power-off` не получил разрешения polkit. Запись и прямое
чтение к этому моменту уже завершились; смонтированных файловых систем не
было. При последней проверке слот стал пустым (0 байт).

Эти результаты подтверждают запись и Verify FLASH/SD. После установки карты
пользователь прислал фотографии PAL-экрана с UniDOS 7.20, вводом даты/времени
и приглашением A:\>. Запуск BIOS и дисковой ОС на text-сборке подтверждён.
Фотографии сохранены в `build/hardware-io/unidos-*-before.png`.

## Исправленная io-сборка

После исправления E629, Win/Caps, RGB и курсора выполнена новая запись FLASH.
Рабочий каталог Linux: `/tmp/pyldin601-io.6QLgiE/hardware-io`.
Перед записью `hgfsd --jtag-only` поднял JTAGENB через FT2232D ADBUS7 high-Z;
высокий уровень подтверждён. `FLASH Verify ID` подтвердил LCMXO2-7000HC.
`FLASH Erase,Program,Verify` завершился с кодом 0 и `Operation: successful`;
JTAG Chain Verification без ошибок, время Programmer — 53 секунды.
После записи FTDI readback JTAGENB также высокий.

JED io-сборки: `build/diamond/io/impl1/pyldin601_classic_impl1.jed`.
SHA-256: `c65b78eb51a1976c0443bd01a721af5c14b728a471467552abd33522a650dcdc`.
Журналы Programmer, оба FTDI readback, XCF и `result.json` сохранены
в `build/hardware-io`. Исходники совпадают с SHA сборочного архива.

SD-карта повторно не записывалась: LOADER.BIN не изменился, имеющийся
`sd-text.img` совместим. Надпись ROM DISK находится в первичном FPGA BIOS.
Описание исправлений и симуляционных проверок — в `IO-FIXES.md`.
Визуальная проверка исправленного курсора, переключения раскладки и цветов
RGB на io-сборке пользователем ещё не подтверждена.

## Инверсия красного Caps LED

Пользователь проверил индикатор на плате и сообщил обратную полярность Caps.
Красный выход инвертирован. Обновлённый `tb_keyboard_layout` прошёл;
Diamond fit/STA проходит: 5747 LUT, 8 EBR, setup/hold/unconstrained = 0.

JED caps-led: `build/diamond/caps-led/impl1/pyldin601_classic_impl1.jed`.
SHA-256: `d4fce89e0ad9f33788e66d22c2bcb442ed55dddc0bfec564510d17258f5a2e14`.
Рабочий каталог Linux: `/tmp/pyldin601-caps-led.MQKe1v/hardware-caps-led`.
JTAGENB поднят через FTDI/uJ11 hgfsd; высокий уровень подтверждён до и после.
Verify ID успешен. FLASH Erase,Program,Verify завершился с кодом 0,
Operation successful, JTAG Chain Verification без ошибок; время 54 секунды.
Журналы, XCF и result.json сохранены в `build/hardware-caps-led`.
Карта SD не перезаписывалась. Визуальная проверка новой полярности ещё
не подтверждена пользователем.

## Самостоятельная диагностика SRAM, 3 октября

После нового явного разрешения пользователя «заливай» записан диагностический
JED `build/diamond/sram-diagnostic/impl1/pyldin601_classic_impl1.jed`.
SHA-256: `078042d8327c1561010e7a4d2cc344ecc9967a849515f57896a0691af390a5ca`.
Linux directory: `/tmp/pyldin601-sram-diagnostic.nFnvYy/hardware-sram-diagnostic`.
FTDI свободен перед операцией. Тот же uJ11 `hgfsd --jtag-only` подтвердил
высокий JTAGENB до и после. Verify ID подтвердил LCMXO2-7000HC;
FLASH Erase,Program,Verify завершился с кодом 0, без ошибок JTAG Chain,
`Operation: successful`, за 53 секунды. Логи/XCF/result.json сохранены
в `build/hardware-sram-diagnostic`.

SD не читалась и не записывалась этой операцией. Диагностический код проверяет
2038 KiB физической SRAM, перезаписывая её пятью шаблонами, и повторяется.
После полного круга на PAL экране появляется `ALL FIVE PATTERNS OK. ROUNDS 0001`;
при первом несовпадении — `FAIL AT ... EXPECT ... GOT ...`.
Пользователь сообщил «ошибок нет» и значение `ROUNDS 15`; все пять шаблонов
многократно завершились. Сохранено буквальное значение ответа, поскольку
счётчик на экране выводится в hex. Этот тест не использует SD/FDD и работает
через boot SRAM transactions; он не доказывает стабильность DOS.

## Возврат обычной прошивки с SRAM CRC, 3 октября

После успешной физической диагностики и mixed HDL тестов штатного BIOS IRQ
записана обычная версия `build/diamond/stability/impl1/pyldin601_classic_impl1.jed`.
SHA-256: `d30d36480bf87b153d312d29eed27369b78e1c0f86d9bc83332a154843ed29a0`.
Linux directory: `/tmp/pyldin601-stability.gNXDHi/hardware-stability`.
Это предыдущая прошивка платы. Исходники production RTL, boot EBR и JED
проверены по сохранённому сборочному manifest; изменения тестов/документации
не меняют эту сборку.

Перед записью FTDI был свободен. uJ11 `hgfsd --jtag-only` подтвердил высокий
JTAGENB до и после. Verify ID подтвердил LCMXO2-7000HC. FLASH
Erase,Program,Verify прошёл с кодом 0, без ошибок JTAG Chain, за 53 секунды.
Журналы/XCF/result.json сохранены в `build/hardware-stability`.

SD не перезаписывалась. Новый этап 0C проверяет физические SRAM ROM-данные
по CRC32 перед commit и запуском штатного BIOS. Отсутствие ошибок Program/Verify
не подтверждает устранение runtime-нестабильности; загрузка UniDOS и
повторные DIR/простой требуют наблюдения на плате.

## Предыдущая обычная версия с UART, 3 октября

Рефакторинг арбитра тоже дал физический сбой на третьем DIR. После него
записан JED `build/diamond/normal-uart/impl1/pyldin601_classic_impl1.jed`,
SHA-256 `662b2693487f4d75bd264e7029cea86b51fc1c479bb95aa3547aad642d65d1d7`.
FLASH Erase,Program,Verify прошёл за 56 секунд. FTDI JTAGENB высокий до/после.
Эта версия принимала BUS1 через UART второго канала; lock и
штатный BIOS подтверждены. SD не перезаписывалась. Протокол, ресурсы и
ограничения проверки — в [RUNTIME-UART.md](RUNTIME-UART.md).

## Перенос адресов экранной памяти, 3 октября

После сообщения о пропавшем промпте пользователь подтвердил, что пробел
вводится, а Enter возвращает промпт. CPU не был остановлен: UART показывал
цикл BIOS чтения клавиатуры, SD ready, BIOS mismatch отсутствовал.
Полная предыдущая трасса сохранена в `build/hardware-normal-uart/uart-followup`:
5305 пакетов, 0 bad frames, только reason 0. Это не устанавливает причину
прежних самопроизвольных перезапусков и порчи RAM.

Записан JED этой версии
`build/diamond/video-wrap-pipeline/impl1/pyldin601_classic_impl1.jed`, SHA-256
`e8cfb0c8b7f5f76047a8cfd072ea216c60af863bff40c151fc02417fd27257e5`.
Текстовый video read после FFFE возвращается к F000; графический read
пропускает FFF8 и возвращается к 0, как оригинальный MC6845 renderer.
Расчёт позиции курсора тоже учитывает этот перенос. 384000 пикселей
шести кадров совпадают с оригинальным эмулятором; все RTL-тесты проходят.
Diamond setup/hold/unconstrained = 0, 6594 LUT / 14 EBR.

Linux directory: `/tmp/pyldin601-video-wrap-pipeline.B37BXP/hardware-video-wrap`.
Исходники и JED сверены с архивом/manifest до записи. uJ11
`hgfsd --jtag-only` подтвердил высокий JTAGENB через FTDI до и после.
FLASH Verify ID подтвердил LCMXO2-7000HC. FLASH Erase,Program,Verify успешен,
JTAG Chain Verification без ошибок. Programmer сообщает 56 секунд;
измеренный wall time процесса — 67.46 секунды. Логи/XCF/result.json
сохранены в `build/hardware-video-wrap`. SD не перезаписывалась.

Для этой версии был запущен пассивный UART-capture: PID 271119, Linux
`/tmp/pyldin601-video-wrap-pipeline.B37BXP/uart-live`, максимум 24 часа,
без передачи команд и доступа к SD. Metadata —
`build/hardware-video-wrap/live-capture.json`. Четвёртый DIR показал другую
директорию/Unknown, пятый был нормальным, шестой дал мусор. Причина основного
сбоя не устранена. Capture остановлен перед новой прошивкой; 1726 пакетов
без bad frames и BIOS mismatch сохранены в `build/hardware-video-wrap/uart-live`.

## Без электронного диска, 3 октября

По запросу пользователя удалён runtime-интерфейс E680–E683: счётчик,
автоинкремент и SRAM address mux отсутствуют. Старый SD loader продолжает
загружать ROM: boot-доступы 80000–FFFFF подтверждаются без SRAM-транзакций.
Новый loader уже не выполняет это обнуление. Этап 0A — `ROM DISK DISABLED`.

Записан `build/diamond/no-edisk/impl1/pyldin601_classic_impl1.jed`, SHA-256
`7740ffd3d5ec09ae098f1cd035bffa1c3a3001f4d4f9fea8496381d39fc720ad`.
Исходники и JED сверены с архивом/manifest. Linux build
`/tmp/pyldin601-no-edisk.V0Gkpm`. FLASH Verify ID подтвердил LCMXO2-7000HC;
Erase,Program,Verify и JTAG Chain Verification прошли без ошибок.
Programmer сообщает 56 секунд, wall time 67.48 секунд. uJ11 `hgfsd --jtag-only`
подтвердил высокий JTAGENB через FTDI до и после. SD не перезаписывалась.
Логи/XCF/result.json сохранены в `build/hardware-no-edisk`.

Активный пассивный UART: PID 274164, Linux
`/tmp/pyldin601-no-edisk.V0Gkpm/uart-live`, максимум 24 часа.
Подтверждены runtime BIOS, ROM lock, SD ready и reason 0. Это подтверждает
запуск, не устранение прежнего повреждения RAM/директории.

Позже пользователь показал испорченный баннер сразу после загрузки этой
no-edisk версии без клавиатурного ввода. Она не устранила основной сбой.
PID 274164 остановлен перед новой прошивкой; сохранены 3240 пакетов без
bad frames и только reason 0 в `build/hardware-no-edisk/uart-live`.

## Исправленный CPU, 3 октября

Записан обычный `build/diamond/cpu-conformance/impl1/pyldin601_classic_impl1.jed`.
SHA-256 `3c4c79674f3afdab1da1dd69dab31ff6a626ac80aa5062c2be8e2d43f9c1d74c`.
FLASH Verify ID / Erase,Program,Verify успешны, Programmer 56 секунд,
wall 67.46 секунд. `hgfsd --jtag-only` подтвердил JTAGENB high до и после.
Исходники/JED/тайминги сверены; SD не перезаписывалась, электронный диск
отключён. Логи/XCF/result — `build/hardware-cpu-conformance`.

После записи пользователь подтвердил: баннер целый, несколько DIR
возвращают приглашение без сбоев. Длительная проверка простоя ещё не проведена.
UART второго канала FTDI оставлен в пассивном capture PID 277762,
`/tmp/pyldin601-cpu-conformance.oN1L4u/uart-live`, максимум 24 часа.
Воспроизводимые ошибки CPU и дифференциальная проверка описаны в
[CPU-CONFORMANCE.md](CPU-CONFORMANCE.md).


## Возвращён электронный диск, 3 октября

Записан обычный JED `build/diamond/cpu-edisk/impl1/pyldin601_classic_impl1.jed`,
SHA-256 `82bf9f7d3c421ac2f28d255ac6f4e97e7019a24e3315039434450b0d4b18f719`.
Исправленный CPU сохранён, электронный диск 512 КиБ восстановлен.
FLASH Verify ID / Erase,Program,Verify и JTAG Chain Verification успешны.
Programmer 56 секунд, wall 67.46 секунд; FTDI JTAGENB high до и после.
Исходники/JED/TRACE сверены, SD не перезаписывалась.
Логи/XCF/result — `build/hardware-cpu-edisk`; проверки и точный состав
сборки — [ELECTRONIC-DISK.md](ELECTRONIC-DISK.md).

Предыдущий UART PID 277762 остановлен: 1203 пакета, 0 bad frames сохранены
в `build/hardware-cpu-conformance/uart-live`. Новый пассивный capture
PID 279897 — `/tmp/pyldin601-cpu-edisk.tWnvI0/uart-live`, максимум 24 часа.
Отладка сохранена до проверки диска пользователем на плате.


## Обычная версия без отладки, 3 октября

После подтверждения пользователем исправной работы электронного диска
удалена аппаратная отладка, записан JED
`build/diamond/release-clean/impl1/pyldin601_classic_impl1.jed`. SHA-256:
`7e7a7dacf6da195cae8219abf4a3d83ae87bb1c01c21169bb1d935046aea8ffc`.
FLASH Verify ID / Erase,Program,Verify и JTAG Chain Verification успешны.
Wall time 65.52 секунды, FTDI JTAGENB high до и после. Исходники/JED/TRACE
сверены, SD не менялась. Логи/XCF/result — `build/hardware-release-clean`.
Подробности изменений, ресурсов и проверок — [RELEASE.md](RELEASE.md).

Capture PID 279897 остановлен: 586 пакетов, 0 bad frames, только reason 0.
Полная копия — `build/hardware-cpu-edisk/uart-live`. Новый capture не
запускается: в обычной версии TX UART удерживается в idle.
