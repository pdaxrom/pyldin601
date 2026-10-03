# Проверка MC6800 и сравнение с pyldin2012, 3 октября 2026

Дополнительно введён внешний выбор MC6800/HD6303 ISA и второе boot-меню;
[описание и результаты новых проверок](HD6303.md). Режим MC6800 по умолчанию
сохраняет перечисленные ниже исправления.

Исправления CPU входят в текущую версию [601/601A](MODELS.md).
Ресурсы, JED и UART в разделе Diamond ниже относятся к первоначальной
cpu-conformance сборке, когда электронный диск ещё был отключён.
В текущей версии он включён, аппаратная отладка удалена.

В CPU найдены воспроизводимые ошибки, независимые от электрических
таймингов SRAM. После прошивки пользователь подтвердил целый баннер и
несколько DIR с возвратом приглашения без сбоев. Длительная работа в простое
ещё не проверена. Отсутствие BIOS mismatch по UART не проверяет исполнение CPU.

## Ошибки и исправления

1. CLR/CLRA/CLRB сохраняли прежний V. Исправлен сброс V. При возвращении
   только этой ошибки в текущий CPU сравнение штатного BIOS падает на
   состоянии 64693, после CLR по F058: PC=F05A, CCR=D6 вместо D4.
   Журнал: `build/boot-lockstep-clr-before.log`.
2. Биты 6/7 CCR могли изменяться при ALU/TAP и загрузке RTI. Теперь это
   постоянные единицы; остальные шесть флагов сохраняют штатные функции.
3. SWI не выставлял I после сохранения исходного CCR. Сравнение с исходным
   эмулятором останавливалось на первом таком SWI: состояние 205969,
   PC=F189, CCR=C0 вместо D0. `build/boot-lockstep-swi-before.log`.
4. Вектор прерывания повторно выбирался по живым IRQ/NMI после семи
   записей стека. IRQ, пришедший во время SWI, перенаправлял готовый кадр
   на IRQ handler. В UniBIOS за SWI находится байт номера функции;
   после ошибочного RTI этот байт мог исполняться как opcode.
   Архив прежней реально прошитой версии даёт `IRQ stole the SWI frame`
   в 705 ns: `build/cpu-interrupts-before.log`.
   Теперь причина фиксируется при принятии IRQ/NMI или декодировании
   SWI/WAI. Ни живые входы, ни opcode, прочитанный без исполнения при
   принятии IRQ, не меняют вектор. Исходный CCR сохраняется до установки I.
5. WAI принудительно очищал I. Теперь сохраняется маска вызывающего кода:
   при I=1 выход требует NMI, при I=0 разрешён IRQ. NMI также устанавливает
   маску перед входом в обработчик. Reset выставляет I=1.

Семантика CLR, постоянных битов CCR, reset и ожидания/маски прерываний
сверена с первичной документацией Motorola: [M6800 Systems Reference and
Data Sheets, May 1975](https://vtda.org/docs/computing/Motorola/M6800SystemsReferenceDataSheets_May75.pdf),
MC6800, печатные страницы 13–21. SWI также сверяется с оригинальным
`../pyldin601/src/core/mc6800.c`.

Сам C-эмулятор имеет ограничения: reset оставляет I=0, вход IRQ не
выставляет I. В boot-сравнении исправляется только начальное I в тестовом
адаптере по документации; исходник эмулятора и ROM не изменяются. Для
маски при входе IRQ/NMI/WAI используются отдельные проверки по спецификации.
Сравнение только с эмулятором не считается полной сертификацией MC6800.

## Проверки production CPU

- `make test-boot-lockstep LOCKSTEP_IMAGE=build/sd-text.img`: 500000
  исполненных инструкций неизменённого native BIOS/ROM, 500001 состояния
  PC/SP/X/A/B/всех восьми битов CCR и конечные байты RAM вне I/O E600–E6FF.
  Для этого прогона IRQ/клавиши не вводятся; I/O read replay взят из
  эмулятора. CPU и его ALU/state machine не подменяются моделью C.
  Только simulation-копия CPU получает наблюдающие порты регистров.
  Это проверка CPU, а не внешней SRAM, SD или долговременной работы DOS.
- `make test-cpu`: 2820 результатов сравнено с оригинальным C core;
  флаги задаются после LDA/LDX, чтобы N/Z/V не исчезали из начальных условий.
  Проверены immediate/direct/indexed/extended ALU, RMW memory, все 16
  сочетаний N/Z/V/C для 14 условных ветвлений, CPX, подпрограммы, стек,
  SWI/IRQ/RTI. `build/cpu-fixed-flags.log`.
- `make test-cpu-interrupts`: 24 прогона actual VHDL. IRQ приходит на 18
  разных тактах SWI; проверяются порядок обработчиков, I при входе,
  сохранённые CCR/PC, пропуск inline service byte и восстановление A/B/X/SP.
  Отдельно IRQ принимается при fetch ещё не исполненных SWI/WAI и снимается
  во время записи стека. Проверены reset и WAI с IRQ/NMI.
  `build/cpu-interrupts.log`.
- Actual VHDL CPU + production CPU/video/контроллер SRAM: 20 штатных PAL IRQ,
  переход через 02:00:00, сохранность заголовка и 172800 видеочтений;
  RAM изменения совпали с эмулятором. `build/cpu-fixed-runtime-irq.log`.
  Fixture теперь сохраняет найденный SP; отключение электронного диска
  меняет размещение DOS и не должно ломать тест из-за прежнего B3B4.
- Board syntax и actual VHDL handoff/lock/warm reset прошли.
  `build/cpu-conformance-regression.log`.

Полное соответствие длительности каждой инструкции, все NMI edge cases и
длительный прогон DIR на физической плате здесь не объявляются проверенными.
Новый CPU не меняет слоты арбитра и не вводит runtime HOLD для видео.

## Старый проект

Изучен [pyldin2012](https://github.com/pdaxrom/pyldin2012/tree/c61753eee544db23a98af5b38ae2609293f21e31),
commit c61753eee544db23a98af5b38ae2609293f21e31. Локальная копия:
`build/reference-pyldin2012`. Quartus-проект для Cyclone II EP2C8,
50 MHz → 25 MHz, с SRAM, VGA/MC6845, PS/2 и SD.

В [pyldin2012.vhd](https://github.com/pdaxrom/pyldin2012/blob/c61753eee544db23a98af5b38ae2609293f21e31/pyldin2012.vhd)
`vramclock` отдаёт SRAM видео и выставляет ram_hold при конфликте с CPU;
в CPU Idle→Read/Write тоже применяется HOLD. Результат чтения CPU
отдельно сохраняется в ram_data_out. Это полезное разделение данных, но
старое расписание не является прозрачным чередованием фаз.

По требованию пользователя оно не перенесено. В текущем классическом
проекте CPU/video используют фиксированные слоты 24 MHz, с независимым
CPU read register и неизменным адресом/payload принятой транзакции.
Рабочая последовательность физических выводов uJ11 также сравнена;
описание и проверки — в [RAM-ARBITRATION.md](RAM-ARBITRATION.md).

Старый [cpu68.vhd](https://github.com/pdaxrom/pyldin2012/blob/c61753eee544db23a98af5b38ae2609293f21e31/cpu68.vhd)
использует ту же Kent CPU68 v0.8 с описанными CLR/CCR/SWI ошибками.
Его давняя работа не доказывает обработку редкого совпадения IRQ/SWI.

## Diamond исходной cpu-conformance сборки

Обычный JED: `build/diamond/cpu-conformance/impl1/pyldin601_classic_impl1.jed`.
SHA-256: `3c4c79674f3afdab1da1dd69dab31ff6a626ac80aa5062c2be8e2d43f9c1d74c`.
Архив: `build/diamond/source-cpu-conformance.tar.gz` и `.sha256.json`.
Linux: `/tmp/pyldin601-cpu-conformance.oN1L4u`.

6398/6864 LUT, 3262/3432 slices, 2339/7209 registers, 14/26 EBR, 1/2 PLL.
Setup/hold negative slack 0, unconstrained paths 0. System→CPU MAXDELAY
покрывает 2072 пути: worst 15.323 ns, margin 4.677 ns к 20 ns.
Электронный диск отключён; SD на плате не перезаписывалась.
FLASH Verify ID и Erase,Program,Verify успешны; JTAGENB через FTDI высокий
до и после. Журналы — `build/hardware-cpu-conformance`, Programmer 56 sec,
wall 67.46 sec. Пассивный UART PID 277762, максимум 24 часа:
`/tmp/pyldin601-cpu-conformance.oN1L4u/uart-live`.
Пользователь подтвердил целый баннер и несколько нормальных DIR.
