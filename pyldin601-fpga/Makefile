PYTHON ?= python3
IVERILOG ?= iverilog
VVP ?= vvp
NVC ?= nvc
CC ?= cc
NATIVE ?= ../native
EMUSRC ?= ../pyldin601/src
CVM_TOOLCHAIN ?= $(abspath ../../../FPGA/hd6303-toolchain)
UNIAS ?= $(CVM_TOOLCHAIN)/unias
export UNIAS
FAT_RAMMAN ?= 0
export FAT_RAMMAN
HD_TEST_SD ?= build/sd-models/sd-after.img
BUILD := build
RTL := $(wildcard rtl/*.v)
BENCHES := hg frequency_controls timer_tick audio_control memory arbiter arbiter_contract boot_ports boot_header spi_registers sram keyboard keyboard_raw ps2_raw video video_viewport video_mode_switch video_text video_cursor video_underscore pal_timing pal_encoder pal_rgb332 video_colour video_601a transparent_video sram_stress
.PHONY: test firmware test-python test-rtl test-cpu fixtures test-firmware test-system image test-board-syntax test-handoff test-stage1 sram-diagnostic test-sram-diagnostic
.PHONY: test-native-stability test-stage1-a
.PHONY: test-runtime-irq
.PHONY: test-boot-lockstep test-cpu-interrupts
LOCKSTEP_IMAGE ?= $(STABILITY_IMAGE)
test-boot-lockstep: fixtures $(LOCKSTEP_IMAGE)
	$(PYTHON) tests/prepare_boot_lockstep.py
	$(CC) -O2 -I$(EMUSRC) tests/prepare_boot_lockstep.c -o $(BUILD)/prepare_boot_lockstep
	$(BUILD)/prepare_boot_lockstep $(LOCKSTEP_IMAGE)
	$(NVC) --std=2008 --work=work:$(BUILD)/boot-lockstep --ieee-warnings=off -a $(BUILD)/cpu6800_lockstep.vhd tests/tb_boot_lockstep.vhd -e tb_boot_lockstep -r tb_boot_lockstep > $(BUILD)/boot-lockstep.log 2>&1
	@cat $(BUILD)/boot-lockstep.log
	@$(PYTHON) -c "from pathlib import Path; assert 'PASS 500000 consecutive native BIOS/ROM instructions' in Path('build/boot-lockstep.log').read_text()"
test-cpu-interrupts: fixtures
	$(PYTHON) tests/prepare_boot_lockstep.py
	$(PYTHON) tests/prepare_cpu_interrupts.py
	$(NVC) --std=2008 --work=work:$(BUILD)/cpu-interrupts --ieee-warnings=off -a $(BUILD)/cpu6800_lockstep.vhd $(BUILD)/cpu-interrupts-labels.vhd tests/tb_cpu_interrupts.vhd
	$(PYTHON) tests/run_cpu_interrupts.py --nvc $(NVC)
.PHONY: test-mixed-clock
.PHONY: test-boot-console
test-boot-console: test-firmware
	$(PYTHON) tests/prepare_boot_console.py
	$(IVERILOG) -g2012 -s tb_boot_console -o $(BUILD)/tb_boot_console $(RTL) tests/tb_boot_console.v
	$(VVP) $(BUILD)/tb_boot_console
.PHONY: test-setup
.PHONY: test-shell
.PHONY: test-shell-boot
test: test-shell-boot
test-shell-boot: fixtures memory-test
	$(PYTHON) tests/run_shell_boot.py --cc "$(CC)"
.PHONY: test-rom-modules
test: test-rom-modules
test-rom-modules: fixtures
	$(CC) -O2 -I$(EMUSRC) tests/test_rom_modules.c -o $(BUILD)/test_rom_modules
	@set -e; for model in 601 601a; do for cpu in mc6800 hd6303; do for mode in no-pages no-parts no-raw no-shell no-kernel no-game relocated no-e0; do $(BUILD)/test_rom_modules $$model $$cpu $$mode; done; done; done
test-shell: fixtures
	$(CC) -O2 -I$(EMUSRC) tests/test_shell_codec.c -o $(BUILD)/test_shell_codec -lm
	$(BUILD)/test_shell_codec
	$(CC) -O2 -DCOMPACT_FIXTURE -I$(EMUSRC) tests/test_shell_rom.c -o $(BUILD)/test_shell_rom
	@set -e; for model in 601 601a; do for cpu in mc6800 hd6303; do $(BUILD)/test_shell_rom $$model $$cpu; done; done
test-setup: fixtures
	$(CC) -O2 -DCOMPACT_FIXTURE -I$(EMUSRC) tests/test_firmware.c -o $(BUILD)/test_firmware
	$(PYTHON) tests/run_setup.py
.PHONY: test-sd-init
test-sd-init: fixtures
	$(CC) -O2 -DCOMPACT_FIXTURE -I$(EMUSRC) tests/test_firmware.c -o $(BUILD)/test_firmware
	$(PYTHON) tests/run_sd_init.py
test-mixed-clock: | $(BUILD)
	$(NVC) --work=work:$(BUILD)/mixed-clock -a tests/fast_clock.v tests/tb_fast_clock.v -e tb_fast_clock -r tb_fast_clock > $(BUILD)/mixed-clock.log 2>&1
	@cat $(BUILD)/mixed-clock.log
	@$(PYTHON) -c "from pathlib import Path; assert 'PASS mixed HDL clocks' in Path('build/mixed-clock.log').read_text()"
.PHONY: test-turbo
test-turbo: firmware
	$(IVERILOG) -g2012 -s tb_turbo_memory -o $(BUILD)/tb_turbo_memory $(RTL) tests/fast_clock.v tests/tb_turbo_memory.v
	$(VVP) $(BUILD)/tb_turbo_memory
	$(IVERILOG) -g2012 -s tb_turbo_memory -Ptb_turbo_memory.ADDR_DELAY=1 -Ptb_turbo_memory.DATA_DELAY=1 -Ptb_turbo_memory.CONTROL_DELAY=1 -Ptb_turbo_memory.WE_DELAY=10 -o $(BUILD)/tb_turbo_memory-skew $(RTL) tests/fast_clock.v tests/tb_turbo_memory.v
	$(VVP) $(BUILD)/tb_turbo_memory-skew
	$(IVERILOG) -g2012 -s tb_turbo_memory -Ptb_turbo_memory.WE_RISE=0 -Ptb_turbo_memory.WE_FALL=10 -Ptb_turbo_memory.FAST_OFFSET=5.208 -o $(BUILD)/tb_turbo_memory-short-we $(RTL) tests/fast_clock.v tests/tb_turbo_memory.v
	$(VVP) $(BUILD)/tb_turbo_memory-short-we
	$(IVERILOG) -g2012 -s tb_turbo_memory -Ptb_turbo_memory.WE_DELAY=0 -Ptb_turbo_memory.FAST_OFFSET=5.208 -o $(BUILD)/tb_turbo_memory-setup $(RTL) tests/fast_clock.v tests/tb_turbo_memory.v
	$(VVP) $(BUILD)/tb_turbo_memory-setup
	@set -e; for model in 0 1; do for speed in 0 1 2 3; do $(IVERILOG) -g2012 -s tb_transparent_video -Ptb_transparent_video.MODEL_A=$$model -Ptb_transparent_video.SPEED=$$speed -o $(BUILD)/tb_transparent_video-turbo $(RTL) tests/fast_clock.v tests/tb_transparent_video.v; $(VVP) $(BUILD)/tb_transparent_video-turbo; done; done

.PHONY: test-memory-bus
test-memory-bus: firmware
	$(IVERILOG) -g2012 -s tb_memory_bus_audit -o $(BUILD)/tb_memory_bus_audit $(RTL) tests/fast_clock.v tests/tb_memory_bus_audit.v
	$(VVP) $(BUILD)/tb_memory_bus_audit
	$(IVERILOG) -g2012 -s tb_memory_bus_audit -Ptb_memory_bus_audit.ADDR_DELAY=1 -Ptb_memory_bus_audit.DATA_DELAY=1 -Ptb_memory_bus_audit.CONTROL_DELAY=1 -Ptb_memory_bus_audit.WE_DELAY=10 -o $(BUILD)/tb_memory_bus_audit-skew $(RTL) tests/fast_clock.v tests/tb_memory_bus_audit.v
	$(VVP) $(BUILD)/tb_memory_bus_audit-skew
STABILITY_IMAGE ?= build/stability-sd.img
IDLE_SECONDS ?= 14400
test-native-stability: fixtures $(STABILITY_IMAGE)
	$(CC) -O2 -I$(EMUSRC) tests/test_native_stability.c -o $(BUILD)/test_native_stability
	$(BUILD)/test_native_stability $(STABILITY_IMAGE) $(IDLE_SECONDS)
$(BUILD)/stability-sd.img: | $(BUILD)
	$(PYTHON) tools/make_sd.py --native $(NATIVE) --disk-a $(NATIVE)/Floppy/system.imz --output $@
test-runtime-irq: test-mixed-clock fixtures $(STABILITY_IMAGE)
	$(CC) -O2 -I$(EMUSRC) tests/prepare_runtime.c -o $(BUILD)/prepare_runtime
	$(BUILD)/prepare_runtime $(STABILITY_IMAGE) rollover
	UNIAS="$(UNIAS)" $(PYTHON) tests/prepare_runtime.py
	$(NVC) --std=2008 --work=work:$(BUILD)/runtime-irq --ieee-warnings=off -a rtl/cpu6800.vhd $(RTL) tests/fast_clock.v tests/tb_runtime_irq.v tests/tb_runtime_irq.vhd -e -j tb_runtime_irq -r tb_runtime_irq > $(BUILD)/runtime-irq.log 2>&1
	@cat $(BUILD)/runtime-irq.log
	@$(PYTHON) -c "from pathlib import Path; assert 'PASS actual HDL CPU/native BIOS IRQ' in Path('build/runtime-irq.log').read_text()"

.PHONY: test-keyboard-bios
.PHONY: test-keyboard-rom
test-keyboard-rom: fixtures
	$(CC) -O2 -I$(EMUSRC) tests/test_keyboard_rom.c -o $(BUILD)/test_keyboard_rom
	@set -e; for model in 601 601a; do for cpu in mc6800 hd6303; do $(BUILD)/test_keyboard_rom $(BUILD)/test-sd.img $$model $$cpu; done; done
	@set -e; for model in 601 601a; do for cpu in mc6800 hd6303; do $(BUILD)/test_keyboard_rom $(BUILD)/test-sd.img $$model $$cpu swapped; done; done
	$(CC) -O2 -I$(EMUSRC) tests/test_boot_keyboard.c -o $(BUILD)/test_boot_keyboard
	@set -e; for mode in auto save8 save-left exit save-part4 save-part-left; do $(BUILD)/test_boot_keyboard $(BUILD)/boot.bin $(BUILD)/models-sd.img $$mode; done
	@set -e; for mode in auto save8 save-left exit save-part4 save-part-left; do BOOT_FAST_TAPS=1 $(BUILD)/test_boot_keyboard $(BUILD)/boot.bin $(BUILD)/models-sd.img $$mode; done
test-keyboard-bios: test-mixed-clock fixtures $(STABILITY_IMAGE)
	$(CC) -O2 -I$(EMUSRC) tests/prepare_keyboard_bios.c -o $(BUILD)/prepare_keyboard_bios
	@set -e; for model in 601 601a; do $(BUILD)/prepare_keyboard_bios $(STABILITY_IMAGE) $$model; $(NVC) --std=2008 --work=work:$(BUILD)/keyboard-bios-$$model --ieee-warnings=off -a rtl/cpu6800.vhd $(RTL) tests/fast_clock.v tests/tb_keyboard_bios.v tests/tb_keyboard_bios.vhd; for speed in 0 1 2 3; do UNIAS="$(UNIAS)" $(PYTHON) tests/prepare_runtime.py --prefix keyboard --speed $$speed --music-irq; $(NVC) --std=2008 --work=work:$(BUILD)/keyboard-bios-$$model --ieee-warnings=off -e -j -gSPEED=$$speed tb_keyboard_bios -r tb_keyboard_bios > $(BUILD)/keyboard-bios-$$model-$$speed.log 2>&1; cat $(BUILD)/keyboard-bios-$$model-$$speed.log; $(PYTHON) -c "from pathlib import Path; assert 'PASS actual HDL CPU/native BIOS' in Path('build/keyboard-bios-$$model-$$speed.log').read_text()"; done; done

.PHONY: test-runtime-turbo
test-runtime-turbo: test-mixed-clock fixtures $(STABILITY_IMAGE)
	$(CC) -O2 -I$(EMUSRC) tests/prepare_runtime.c -o $(BUILD)/prepare_runtime
	$(BUILD)/prepare_runtime $(STABILITY_IMAGE) rollover
	UNIAS="$(UNIAS)" $(PYTHON) tests/prepare_runtime.py
	$(NVC) --std=2008 --work=work:$(BUILD)/runtime-turbo --ieee-warnings=off -a rtl/cpu6800.vhd $(RTL) tests/fast_clock.v tests/tb_runtime_irq.v tests/tb_runtime_irq.vhd
	@set -e; for speed in 0 1 2 3; do $(NVC) --std=2008 --work=work:$(BUILD)/runtime-turbo --ieee-warnings=off -e -j -gSPEED=$$speed tb_runtime_irq -r tb_runtime_irq > $(BUILD)/runtime-turbo-$$speed.log 2>&1; cat $(BUILD)/runtime-turbo-$$speed.log; $(PYTHON) -c "from pathlib import Path; assert 'PASS actual HDL CPU/native BIOS IRQ' in Path('build/runtime-turbo-$$speed.log').read_text()"; done

test: test-keyboard-rom test-hd6303 test-python test-rtl test-ram-pages test-ram-pages-bios test-ram-pages-ycode test-ram-manager test-memory-app test-audio-app test-audio-irq test-gfxmusic test-gamebios test-gamebios-rtl test-gfx test-ham-pal test-ham-layers test-ay test-partitions test-boot-partitions test-raw-sd test-extension-services test-storage-software test-cpu test-cpu-interrupts test-boot-lockstep test-firmware test-setup test-sd-init test-board-syntax test-handoff
.PHONY: game-apps test-gamebios test-gamebios-rtl test-game-perf
.PHONY: test-xonix
test-xonix: fixtures game-apps
	$(PYTHON) tests/run_xonix.py --cc "$(CC)"
GAME_PERF_ARGS ?= --frames 3
game-apps: | $(BUILD)
	$(MAKE) -f firmware/Makefile game UNIAS="$(UNIAS)" CC="$(CC)"
test-gamebios: fixtures
	$(PYTHON) tests/run_gamebios.py --unias "$(UNIAS)" --cc "$(CC)"
test-gamebios-rtl: fixtures
	$(PYTHON) tests/run_gamebios_rtl.py --unias "$(UNIAS)" --cc "$(CC)" --nvc "$(NVC)"
test-game-perf: fixtures game-apps
	$(PYTHON) tests/run_game_perf.py --unias "$(UNIAS)" --cc "$(CC)" --nvc "$(NVC)" $(GAME_PERF_ARGS)
.PHONY: test-ram-pages-ycode
.PHONY: memory-test test-memory-app
memory-test: | $(BUILD)
	$(MAKE) -f firmware/Makefile memory UNIAS="$(UNIAS)" CC="$(CC)"
test-memory-app: fixtures memory-test
	$(PYTHON) tests/run_memory_app.py --cc "$(CC)"
.PHONY: nc-apps test-nc test-nc-editor
test: test-nc
nc-apps: | $(BUILD)
	$(MAKE) -f firmware/Makefile nc UNIAS="$(UNIAS)" CC="$(CC)"
test-nc: fixtures nc-apps
	$(PYTHON) tests/run_nc.py --cc "$(CC)"
	$(PYTHON) tests/run_nc_editor.py --cc "$(CC)"
	$(PYTHON) tests/render_nc.py
test-nc-editor: fixtures nc-apps
	$(PYTHON) tests/run_nc_editor.py --cc "$(CC)"
	$(PYTHON) tests/render_nc.py
.PHONY: test-ram-manager
.PHONY: ramloader-apps test-ramloader
.PHONY: cvm-apps test-cvm test-native-assembly test-native-firmware test-c-modules test-object-tools test-hg-object-tools
test: test-cvm
cvm-apps: ramloader-apps
	$(PYTHON) tools/build_cvm.py --toolchain "$(CVM_TOOLCHAIN)"
test-cvm: fixtures cvm-apps
	$(PYTHON) tests/run_cvm.py --toolchain "$(CVM_TOOLCHAIN)" --cc "$(CC)"
test-hg-object-tools: fixtures cvm-apps hg-apps
	$(PYTHON) tests/run_hg_object_tools.py --toolchain "$(CVM_TOOLCHAIN)" --cc "$(CC)"
test-object-tools: fixtures cvm-apps romdisk-extract
	$(PYTHON) tests/run_object_tools.py --toolchain "$(CVM_TOOLCHAIN)" --cc "$(CC)"
test-native-assembly: fixtures cvm-apps
	$(PYTHON) tests/run_native_assembly.py --toolchain "$(CVM_TOOLCHAIN)" --cc "$(CC)"
test-native-firmware: fixtures cvm-apps hg-apps nc-apps ramloader-apps
	$(PYTHON) tests/run_native_firmware.py --toolchain "$(CVM_TOOLCHAIN)" --cc "$(CC)"
test-c-modules: fixtures cvm-apps hg-apps
	$(PYTHON) tests/run_c_modules.py --toolchain "$(CVM_TOOLCHAIN)" --cc "$(CC)"

test: test-ramloader
ramloader-apps: | $(BUILD)
	$(MAKE) -f firmware/Makefile ramloader UNIAS="$(UNIAS)" CC="$(CC)"
test-ramloader: fixtures ramloader-apps
	$(PYTHON) tests/run_ramloader.py --cc "$(CC)"
test-ram-manager: fixtures memory-test
	$(PYTHON) tests/run_ram_manager.py --unias "$(UNIAS)" --cc "$(CC)"
test-ram-pages-ycode: fixtures romdisk-extract
	$(PYTHON) tests/run_ram_pages_ycode.py --cc "$(CC)"
.PHONY: test-ram-pages test-ram-pages-bios
test-ram-pages: | $(BUILD)
	$(IVERILOG) -g2012 -s tb_ram_pages -o $(BUILD)/tb_ram_pages $(RTL) tests/tb_ram_pages.v
	$(VVP) $(BUILD)/tb_ram_pages
test-ram-pages-bios: fixtures
	$(PYTHON) tests/prepare_ram_pages_abi.py --unias $(UNIAS)
	$(NVC) --std=2008 --work=work:$(BUILD)/ram-pages-abi --ieee-warnings=off -a rtl/cpu6800.vhd tests/tb_ram_pages_abi.vhd
	@set -e; for model in BIOS BIOS_A; do for hd in false true; do $(NVC) --std=2008 --work=work:$(BUILD)/ram-pages-abi --ieee-warnings=off -e -gMODEL=$$model -gHD=$$hd tb_ram_pages_abi -r tb_ram_pages_abi; done; done
	$(CC) -O2 -I$(EMUSRC) tests/test_ram_pages_monitor.c -o $(BUILD)/test_ram_pages_monitor
	@set -e; for model in 601 601a; do for cpu in mc6800 hd6303; do $(BUILD)/test_ram_pages_monitor $(BUILD)/test-sd.img $$model $$cpu; done; done
firmware: | $(BUILD)
	$(MAKE) -f firmware/Makefile firmware UNIAS="$(UNIAS)" CC="$(CC)"
$(BUILD):
	mkdir -p $(BUILD)
test-python: firmware game-apps romdisk-extract
	$(PYTHON) -m unittest discover -s tests -p 'test_*.py' -v
test-rtl: fixtures
	$(CC) -O2 -I$(EMUSRC) tests/prepare_video_reference.c -o $(BUILD)/prepare_video_reference
	$(BUILD)/prepare_video_reference
	$(CC) -O2 -I$(EMUSRC) tests/prepare_keyboard_reference.c -o $(BUILD)/prepare_keyboard_reference
	$(BUILD)/prepare_keyboard_reference
	$(CC) -O2 -I$(EMUSRC) tests/prepare_colour_reference.c -o $(BUILD)/prepare_colour_reference
	$(BUILD)/prepare_colour_reference
	$(CC) -O2 -I$(EMUSRC) tests/prepare_601a_reference.c -o $(BUILD)/prepare_601a_reference
	$(BUILD)/prepare_601a_reference
	@set -e; for bench in $(BENCHES); do $(IVERILOG) -g2012 -s tb_$$bench -o $(BUILD)/tb_$$bench $(RTL) tests/pal_viewport_reference.v tests/tb_$$bench.v; $(VVP) $(BUILD)/tb_$$bench; done
	$(IVERILOG) -g2012 -s tb_transparent_video -Ptb_transparent_video.MODEL_A=1 -o $(BUILD)/tb_transparent_video-a $(RTL) tests/fast_clock.v tests/tb_transparent_video.v
	$(VVP) $(BUILD)/tb_transparent_video-a
test-cpu: | $(BUILD)
	$(PYTHON) tests/prepare_cpu.py
	$(CC) -O2 -I$(EMUSRC) tests/test_cpu_reference.c -o $(BUILD)/cpu_reference
	$(BUILD)/cpu_reference $(BUILD)/cpu.bin $(BUILD)/cpu.expected.mem
	$(NVC) --std=2008 --work=work:$(BUILD)/cpu-test --ieee-warnings=off -a rtl/cpu6800.vhd tests/tb_cpu.vhd -e tb_cpu -r tb_cpu
.PHONY: test-cpx
test-cpx: | $(BUILD)
	$(CC) -O2 -I$(EMUSRC) tests/test_cpu_reference.c -o $(BUILD)/cpx_reference
	$(PYTHON) tests/run_cpx.py --nvc "$(NVC)" --reference $(BUILD)/cpx_reference
fixtures: firmware
	$(MAKE) -f firmware/Makefile extension UNIAS="$(UNIAS)" CC="$(CC)"
	cp ../native-src/BIOS_A.ROM $(BUILD)/partitions/BIOS_A-BASE.ROM
	$(PYTHON) tests/prepare_images.py $(NATIVE) $(BUILD)
.PHONY: test-partitions test-raw-sd test-extension-services test-runtime-session romdisk-extract
test-direct-sd: test-raw-sd test-partitions
# Historical ROM-disk extraction is tested separately; no ROM/RAM drives ship.
test-romdisk: fixtures
	$(PYTHON) tools/extract_romdisk.py --output build/romdisk-check
romdisk-extract: fixtures
	$(PYTHON) tools/extract_romdisk.py
test-extension-services: fixtures
	$(CC) -O2 -I$(EMUSRC) tests/test_extension_services.c -o $(BUILD)/test_extension_services
	@set -e; for model in 601 601a; do for cpu in mc6800 hd6303; do $(BUILD)/test_extension_services $$model $$cpu; done; done
test-runtime-session: test-mixed-clock fixtures
	mkdir -p $(BUILD)/monitor-debug
	$(CC) -O2 -I$(EMUSRC) tests/prepare_monitor.c -o $(BUILD)/prepare_monitor
	$(BUILD)/prepare_monitor images/sd.img dir > $(BUILD)/monitor-debug/native-session.log 2>&1
	UNIAS="$(UNIAS)" $(PYTHON) tests/prepare_runtime.py --prefix session
	$(PYTHON) -c "from pathlib import Path; p=Path('images/sd.img').read_bytes()[34816*512:(34816+2880)*512]; Path('build/session-disk-a.mem').write_text(''.join('%02x\\n'%v for v in p))"
	$(NVC) --std=2008 --work=work:$(BUILD)/runtime-session --ieee-warnings=off -a rtl/cpu6800.vhd $(RTL) tests/fast_clock.v tests/tb_runtime_session.v tests/tb_runtime_session.vhd -e -j tb_runtime_session -r tb_runtime_session > $(BUILD)/monitor-debug/runtime-session.log 2>&1
	@tail -8 $(BUILD)/monitor-debug/runtime-session.log
	@$(PYTHON) -c "from pathlib import Path; assert 'PASS actual VHDL CPU/PS2/banked INT17/direct SD' in Path('build/monitor-debug/runtime-session.log').read_text()"
test-firmware: fixtures
	$(CC) -O2 -DCOMPACT_FIXTURE -I$(EMUSRC) tests/test_firmware.c -o $(BUILD)/test_firmware
	$(BUILD)/test_firmware $(BUILD)/boot.bin $(BUILD)/test-sd.img
	$(BUILD)/test_firmware $(BUILD)/boot.bin $(BUILD)/models-sd.img 601a
	$(BUILD)/test_firmware $(BUILD)/boot.bin $(BUILD)/models-sd.img hd6303
	$(BUILD)/test_firmware $(BUILD)/boot.bin $(BUILD)/models-sd.img 601a-hd6303
	$(BUILD)/test_firmware $(BUILD)/boot.bin $(BUILD)/models-sd.img both-enter
	$(BUILD)/test_firmware $(BUILD)/boot.bin $(BUILD)/models-sd.img both-key1
	$(BUILD)/test_firmware $(BUILD)/boot.bin $(BUILD)/models-sd.img enter
	$(BUILD)/test_firmware $(BUILD)/boot.bin $(BUILD)/models-sd.img key1
	$(BUILD)/test_firmware $(BUILD)/boot.bin $(BUILD)/wrong-model.img 601a-reject
	$(BUILD)/test_firmware $(BUILD)/boot.bin $(BUILD)/missing-model.img 601a-reject
	$(BUILD)/test_firmware $(BUILD)/boot.bin $(BUILD)/fragmented.img
	$(BUILD)/test_firmware $(BUILD)/boot.bin $(BUILD)/test-sd.img sdsc
	$(BUILD)/test_firmware $(BUILD)/boot.bin $(BUILD)/corrupt-rom.img reject
	$(BUILD)/test_firmware $(BUILD)/boot.bin $(BUILD)/short-chain.img reject
	$(BUILD)/test_firmware $(BUILD)/boot.bin $(BUILD)/test-sd.img no-sd
	$(BUILD)/test_firmware $(BUILD)/boot.bin $(BUILD)/test-sd.img sram-fault
	$(CC) -O2 -I$(EMUSRC) tests/test_bios_io.c -o $(BUILD)/test_bios_io
	$(BUILD)/test_bios_io
# Full mixed VHDL/Verilog simulation is much slower than the C firmware tests.
test-system: test-mixed-clock fixtures
	$(PYTHON) -c "from pathlib import Path; p=Path('build/test-sd.img').read_bytes()[:4194304]; Path('build/boot-sd.mem').write_text(''.join('%02x\\n'%v for v in p))"
	$(NVC) --std=2008 --work=work:$(BUILD)/system-test --ieee-warnings=off -a -D FULL_SYSTEM=1 rtl/cpu6800.vhd $(RTL) tests/fast_clock.v tests/tb_system.v tests/tb_system.vhd -e tb_system -r tb_system > $(BUILD)/system-test.log 2>&1
	@cat $(BUILD)/system-test.log
	@$(PYTHON) -c "from pathlib import Path; assert 'PASS actual HDL CPU+SRAM+SPI boot' in Path('build/system-test.log').read_text()"
image: romdisk-extract
	$(PYTHON) tools/make_sd.py --native $(NATIVE) --disk-a $(NATIVE)/Floppy/system.imz --output $(BUILD)/sd.img

test-board-syntax: | $(BUILD)
	$(NVC) --std=2008 --work=machxo2:$(BUILD)/machxo2 -a tests/machxo2_syntax.vhd
	$(NVC) --std=2008 --work=work:$(BUILD)/board-syntax --map=machxo2:$(BUILD)/machxo2 -a rtl/classic_pll.vhd rtl/cpu6800.vhd rtl/pyldin601_classic.vhd

test-handoff: test-mixed-clock fixtures
	$(PYTHON) tests/prepare_handoff.py
	$(NVC) --std=2008 --work=work:$(BUILD)/handoff --ieee-warnings=off -a -D HANDOFF_CHECK=1 -D FULL_SYSTEM=1 rtl/cpu6800.vhd $(RTL) tests/fast_clock.v tests/tb_system.v tests/tb_system.vhd -e tb_system -r tb_system --stop-time=2ms > $(BUILD)/handoff.log 2>&1
	@cat $(BUILD)/handoff.log
	@$(PYTHON) -c "from pathlib import Path; assert 'PASS actual HDL CPU handoff/ROM lock/warm reset' in Path('build/handoff.log').read_text()"

test-stage1: test-mixed-clock fixtures
	$(PYTHON) -c "from pathlib import Path; p=Path('build/test-sd.img').read_bytes()[:4194304]; Path('build/boot-sd.mem').write_text(''.join('%02x\n'%v for v in p))"
	$(NVC) --std=2008 --work=work:$(BUILD)/stage1 --ieee-warnings=off -a rtl/cpu6800.vhd $(RTL) tests/fast_clock.v tests/tb_system.v tests/tb_system.vhd -e tb_system -r tb_system --stop-time=500ms > $(BUILD)/stage1.log 2>&1
	@cat $(BUILD)/stage1.log
	@$(PYTHON) -c "from pathlib import Path; assert 'MILESTONE actual HDL CPU loaded LOADER.BIN over SD SPI' in Path('build/stage1.log').read_text()"

test-stage1-a: test-mixed-clock fixtures
	$(PYTHON) -c "from pathlib import Path; p=Path('build/models-sd.img').read_bytes()[:4194304]; Path('build/boot-sd.mem').write_text(''.join('%02x\n'%v for v in p))"
	$(NVC) --std=2008 --work=work:$(BUILD)/stage1-a --ieee-warnings=off -a -D BOOT_MODEL_A=1 rtl/cpu6800.vhd $(RTL) tests/fast_clock.v tests/tb_system.v tests/tb_system.vhd -e tb_system -r tb_system --stop-time=500ms > $(BUILD)/stage1-a.log 2>&1
	@cat $(BUILD)/stage1-a.log
	@$(PYTHON) -c "from pathlib import Path; assert 'MILESTONE actual HDL CPU loaded LOADER.BIN over SD SPI' in Path('build/stage1-a.log').read_text()"

sram-diagnostic: | $(BUILD)
	$(MAKE) -f firmware/Makefile sram UNIAS="$(UNIAS)" CC="$(CC)"
test-sram-diagnostic: test-mixed-clock sram-diagnostic
	$(CC) -O2 -I$(EMUSRC) tests/test_sram_diagnostic.c -o $(BUILD)/test_sram_diagnostic
	$(BUILD)/test_sram_diagnostic
	$(BUILD)/test_sram_diagnostic fault
	$(PYTHON) tests/prepare_sram_diagnostic.py
	$(NVC) --std=2008 --work=work:$(BUILD)/sram-diagnostic --ieee-warnings=off -a rtl/cpu6800.vhd $(RTL) tests/fast_clock.v tests/tb_sram_diagnostic.v tests/tb_sram_diagnostic.vhd -e -j tb_sram_diagnostic -r tb_sram_diagnostic > $(BUILD)/sram-diagnostic-hdl.log 2>&1
	@cat $(BUILD)/sram-diagnostic-hdl.log
	@$(PYTHON) -c "from pathlib import Path; assert 'PASS actual HDL MC6800 executes all five SRAM patterns' in Path('build/sram-diagnostic-hdl.log').read_text()"
	$(NVC) --std=2008 --work=work:$(BUILD)/sram-diagnostic-fault --ieee-warnings=off -a -D SRAM_DIAGNOSTIC_FAULT=1 rtl/cpu6800.vhd $(RTL) tests/fast_clock.v tests/tb_sram_diagnostic.v tests/tb_sram_diagnostic.vhd -e -j tb_sram_diagnostic -r tb_sram_diagnostic > $(BUILD)/sram-diagnostic-fault-hdl.log 2>&1
	@cat $(BUILD)/sram-diagnostic-fault-hdl.log
	@$(PYTHON) -c "from pathlib import Path; assert 'PASS actual HDL MC6800 diagnostic detects delayed SRAM corruption' in Path('build/sram-diagnostic-fault-hdl.log').read_text()"

DIAMOND_HOME ?= $(HOME)/.local/lscc/diamond/3.14
DIAMOND_LIBSTDCPP ?= /lib/x86_64-linux-gnu/libstdc++.so.6
.PHONY: diamond
diamond: firmware
	LD_PRELOAD="$(DIAMOND_LIBSTDCPP)" "$(DIAMOND_HOME)/bin/lin64/diamondc" build-diamond.tcl

.PHONY: test-hd6303
test-hd6303: test-cpu test-cpx test-hd6303-edges
	$(BUILD)/cpu_reference $(BUILD)/cpu.bin $(BUILD)/classic-hd.expected.mem hd6303
	cp $(BUILD)/cpu.mem $(BUILD)/classic-hd.mem
	$(NVC) --std=2008 --work=work:$(BUILD)/cpu-test --ieee-warnings=off -e -gPREFIX=classic-hd -gHD=true tb_cpu -r tb_cpu
	$(PYTHON) tests/prepare_hd6303.py
	$(BUILD)/cpu_reference $(BUILD)/hd6303.bin $(BUILD)/hd6303.expected.mem hd6303
	$(NVC) --std=2008 --work=work:$(BUILD)/cpu-test --ieee-warnings=off -e -gPREFIX=hd6303 -gHD=true -gLAST_RESULT=57343 tb_cpu -r tb_cpu

.PHONY: hd6303-apps test-hd6303-apps hd6303-test-image
hd6303-apps: | $(BUILD)
	$(PYTHON) tests/hd6303/build_tests.py --unias "$(UNIAS)" --output $(BUILD)/hd6303-apps
test-hd6303-apps: hd6303-apps
	$(CC) -O2 -I$(EMUSRC) tests/test_hd6303_apps.c -o $(BUILD)/test_hd6303_apps
	$(PYTHON) tests/run_hd6303_apps.py --nvc "$(NVC)"
hd6303-test-image: hd6303-apps
	$(PYTHON) tools/add_disk_files.py --image "$(HD_TEST_SD)" --drive B --files $(BUILD)/hd6303-apps --output $(BUILD)/sd-hd6303-tests.img

.PHONY: test-hd6303-edges
test-hd6303-edges: fixtures
	$(PYTHON) tests/prepare_boot_lockstep.py
	$(PYTHON) tests/prepare_hd6303_edges.py
	$(NVC) --std=2008 --work=work:$(BUILD)/hd-edges --ieee-warnings=off -a $(BUILD)/cpu6800_lockstep.vhd $(BUILD)/hd-edge-labels.vhd tests/tb_hd6303_edges.vhd
	@set -e; for scenario in 0 1 2 3 4 5; do $(NVC) --std=2008 --work=work:$(BUILD)/hd-edges --ieee-warnings=off -e -gSCENARIO=$$scenario tb_hd6303_edges -r tb_hd6303_edges; done

# Both ROM bundles use the same classic machine peripherals; ISA selection is independent.
.PHONY: test-stage1-hd
test-stage1-hd: test-mixed-clock fixtures
	$(PYTHON) -c "from pathlib import Path; p=Path('build/models-sd.img').read_bytes()[:4194304]; Path('build/boot-sd.mem').write_text(''.join('%02x\n'%v for v in p))"
	$(NVC) --std=2008 --work=work:$(BUILD)/stage1-hd --ieee-warnings=off -a -D BOOT_HD6303=1 rtl/cpu6800.vhd $(RTL) tests/fast_clock.v tests/tb_system.v tests/tb_system.vhd -e tb_system -r tb_system --stop-time=500ms > $(BUILD)/stage1-hd.log 2>&1
	@cat $(BUILD)/stage1-hd.log
	@$(PYTHON) -c "from pathlib import Path; assert 'MILESTONE actual HDL CPU loaded LOADER.BIN over SD SPI' in Path('build/stage1-hd.log').read_text()"
	$(NVC) --std=2008 --work=work:$(BUILD)/stage1-a-hd --ieee-warnings=off -a -D BOOT_HD6303=1 -D BOOT_MODEL_A=1 rtl/cpu6800.vhd $(RTL) tests/fast_clock.v tests/tb_system.v tests/tb_system.vhd -e tb_system -r tb_system --stop-time=500ms > $(BUILD)/stage1-a-hd.log 2>&1
	@cat $(BUILD)/stage1-a-hd.log
	@$(PYTHON) -c "from pathlib import Path; assert 'MILESTONE actual HDL CPU loaded LOADER.BIN over SD SPI' in Path('build/stage1-a-hd.log').read_text()"

.PHONY: test-setup-hdl
test-setup-hdl: test-mixed-clock fixtures
	$(PYTHON) -c "from pathlib import Path; p=Path('build/models-sd.img').read_bytes()[:4194304]; Path('build/boot-sd.mem').write_text(''.join('%02x\n'%v for v in p))"
	$(NVC) --std=2008 --work=work:$(BUILD)/setup-hdl --ieee-warnings=off -a -D BOOT_SAVE=1 -D BOOT_HD6303=1 -D BOOT_MODEL_A=1 rtl/cpu6800.vhd $(RTL) tests/fast_clock.v tests/tb_system.v tests/tb_system.vhd -e tb_system -r tb_system --stop-time=500ms > $(BUILD)/setup-hdl.log 2>&1
	@cat $(BUILD)/setup-hdl.log
	@$(PYTHON) -c "from pathlib import Path; assert 'MILESTONE actual HDL CPU loaded LOADER.BIN over SD SPI' in Path('build/setup-hdl.log').read_text()"

.PHONY: test-handoff-fast
test-handoff-fast: test-mixed-clock fixtures
	@set -e; for setting in 12 14 15; do $(PYTHON) tests/prepare_handoff.py $$setting; model=""; if [ $$setting -eq 15 ]; then model="-D BOOT_MODEL_A=1"; fi; $(NVC) --std=2008 --work=work:$(BUILD)/handoff-fast-$$setting --ieee-warnings=off -a -D HANDOFF_CHECK=1 -D HANDOFF_SETTING=$$setting -D FULL_SYSTEM=1 $$model rtl/cpu6800.vhd $(RTL) tests/fast_clock.v tests/tb_system.v tests/tb_system.vhd -e tb_system -r tb_system --stop-time=2ms > $(BUILD)/handoff-fast-$$setting.log 2>&1; cat $(BUILD)/handoff-fast-$$setting.log; $(PYTHON) -c "from pathlib import Path; assert 'PASS actual HDL CPU handoff/ROM lock/warm reset' in Path('build/handoff-fast-$$setting.log').read_text()"; done

HG_ISA ?= 0
.PHONY: hg-apps hg-host test-hg-host test-hg test-hg-hdl
hg-host:
	$(MAKE) -C host/hg
test-hg-host:
	$(MAKE) -C host/hg test
hg-apps: | $(BUILD)
	$(MAKE) -f firmware/Makefile hg UNIAS="$(UNIAS)" CC="$(CC)"
test-hg: fixtures hg-apps test-hg-host
	$(PYTHON) tests/test_hg_host.py
	$(IVERILOG) -g2012 -s tb_hg -o $(BUILD)/tb_hg $(RTL) tests/tb_hg.v
	$(VVP) $(BUILD)/tb_hg
	$(PYTHON) tests/run_hg.py --cc "$(CC)"
test-hg-hdl: fixtures hg-apps
	$(PYTHON) tests/run_hg.py --hdl --isa "$(HG_ISA)" --nvc "$(NVC)" --cc "$(CC)"

.PHONY: gfx-apps test-gfx test-gfx-app
.PHONY: test-view
.PHONY: test-sprites
test-sprites: gfx-apps fixtures
	$(PYTHON) tests/prepare_sprites.py
	$(CC) -O2 -I$(EMUSRC) tests/test_sprites_unidos.c -o $(BUILD)/test_sprites_unidos
	$(BUILD)/test_sprites_unidos $(BUILD)/sprites/sd.img 601
	$(BUILD)/test_sprites_unidos $(BUILD)/sprites/sd.img 601a
	$(PYTHON) tests/run_sprites_app.py --nvc $(NVC)
test-view: gfx-apps fixtures
	$(PYTHON) tests/test_palette_coefficients.py
	$(PYTHON) tests/prepare_view.py
	$(CC) -O2 -I$(EMUSRC) tests/test_view_unidos.c -o $(BUILD)/test_view_unidos
	$(BUILD)/test_view_unidos $(BUILD)/view/sd.img 601
	$(BUILD)/test_view_unidos $(BUILD)/view/sd.img 601a
	$(PYTHON) tests/run_view_app.py --nvc $(NVC)
	$(IVERILOG) -g2012 -s tb_pal_palette -o $(BUILD)/tb_pal_palette rtl/classic_pal_encoder.v tests/tb_pal_palette.v
	$(VVP) $(BUILD)/tb_pal_palette
gfx-apps: | $(BUILD)
	$(MAKE) -f firmware/Makefile gfx UNIAS="$(UNIAS)" CC="$(CC)"
test-gfx: firmware
	$(IVERILOG) -g2012 -s tb_gfx -o $(BUILD)/tb_gfx $(RTL) tests/fast_clock.v tests/pal_viewport_reference.v tests/tb_gfx.v
	$(VVP) $(BUILD)/tb_gfx
.PHONY: test-gfx-recovery
test-gfx-recovery: firmware
	$(IVERILOG) -g2012 -s tb_gfx -Ptb_gfx.RECOVERY_ONLY=1 -o $(BUILD)/tb_gfx_recovery $(RTL) tests/fast_clock.v tests/pal_viewport_reference.v tests/tb_gfx.v
	$(VVP) $(BUILD)/tb_gfx_recovery
test-gfx-app: gfx-apps
	$(PYTHON) tests/run_gfx_app.py --nvc "$(NVC)"

# HAM formats share the existing waveform RAM; verify all colour states and
# clock phases before exercising the real PGM on the production CPU/SRAM.
.PHONY: test-ham test-ham-pal test-ham-layers
test-ham-layers: firmware
	$(PYTHON) tests/run_ham_layers.py --iverilog "$(IVERILOG)" --vvp "$(VVP)"
test-ham-pal: firmware
	$(PYTHON) tests/test_ham_tables.py
	$(IVERILOG) -g2012 -s tb_pal_ham -o $(BUILD)/ham/tb_pal_ham rtl/classic_pal_encoder.v tests/tb_pal_ham.v
	$(VVP) $(BUILD)/ham/tb_pal_ham
	@set -e; for phase in 1 2.604 5.208 7.812 10.415; do $(IVERILOG) -g2012 -s tb_pal_ham -Ptb_pal_ham.FULL=0 -Ptb_pal_ham.FAST_OFFSET=$$phase -o $(BUILD)/ham/tb_pal_ham-phase rtl/classic_pal_encoder.v tests/tb_pal_ham.v; $(VVP) $(BUILD)/ham/tb_pal_ham-phase; done
test-ham: gfx-apps fixtures test-ham-pal
	$(PYTHON) tests/prepare_ham.py
	$(CC) -O2 -I$(EMUSRC) tests/test_ham_unidos.c -o $(BUILD)/test_ham_unidos
	$(BUILD)/test_ham_unidos $(BUILD)/ham/sd.img 601
	$(BUILD)/test_ham_unidos $(BUILD)/ham/sd.img 601a
	$(PYTHON) tests/run_ham_app.py --nvc $(NVC)

.PHONY: test-clip-sprites
# CHIP HDL defaults test all four CPU speeds; --models/--speeds permit scoped runs.
test-clip-sprites: gfx-apps fixtures
	$(PYTHON) tests/prepare_clip_symbols.py
	$(CC) -O2 -I$(EMUSRC) -I$(BUILD)/clip-sprites tests/test_gfx_clip.c -o $(BUILD)/test_gfx_clip
	$(BUILD)/test_gfx_clip $(BUILD)/gfx/CLIPSPR.PGM
	$(PYTHON) tests/prepare_clip_sprites.py
	$(CC) -O2 -I$(EMUSRC) tests/test_clip_sprites_unidos.c -o $(BUILD)/test_clip_sprites_unidos
	$(BUILD)/test_clip_sprites_unidos $(BUILD)/clip-sprites/sd.img 601
	$(BUILD)/test_clip_sprites_unidos $(BUILD)/clip-sprites/sd.img 601a
	$(PYTHON) tests/run_clip_sprites_app.py --nvc $(NVC)

.PHONY: test-ay test-ay-app
.PHONY: audio-apps test-audio-app test-audio-irq test-gfxmusic test-gfxmusic-rtl
audio-apps: | $(BUILD)
	$(MAKE) -f firmware/Makefile audio UNIAS="$(UNIAS)" CC="$(CC)"
test-audio-app: audio-apps fixtures
	$(PYTHON) tests/prepare_audio.py
	$(PYTHON) tests/run_audio_app.py --cc "$(CC)"
test-audio-irq: test-audio-app
	$(PYTHON) tests/run_audio_irq.py --unias "$(UNIAS)" --nvc "$(NVC)"
test-gfxmusic: audio-apps fixtures
	$(PYTHON) tests/prepare_audio.py
	$(PYTHON) tests/prepare_gfxmusic.py
	$(PYTHON) tests/run_gfxmusic.py --cc "$(CC)"
test-gfxmusic-rtl: test-gfxmusic
	$(PYTHON) tests/run_gfxmusic_rtl.py --unias "$(UNIAS)" --nvc "$(NVC)"
test-ay: firmware
	$(IVERILOG) -g2012 -s tb_ay8910 -o $(BUILD)/tb_ay8910 rtl/classic_ay8910.v tests/tb_ay8910.v
	$(VVP) $(BUILD)/tb_ay8910
test-ay-app: gfx-apps fixtures
	$(PYTHON) tests/prepare_ay.py
	$(CC) -O2 -I$(EMUSRC) tests/test_ay_unidos.c -o $(BUILD)/test_ay_unidos
	$(BUILD)/test_ay_unidos 601
	$(BUILD)/test_ay_unidos 601a

.PHONY: ham8conv test-ham8conv test-hview test-hview-app
HAM_IMAGE_CFLAGS = $(shell pkg-config --cflags libjpeg libpng)
HAM_IMAGE_LIBS = $(shell pkg-config --libs libjpeg libpng)
ham8conv: $(BUILD)/ham8conv
$(BUILD)/ham8conv: tools/ham8conv.c | $(BUILD)
	$(CC) -O2 -Wall -Wextra -Wpedantic $(HAM_IMAGE_CFLAGS) $< -o $@ $(HAM_IMAGE_LIBS) -lm
test-ham8conv: ham8conv
	$(PYTHON) tests/test_ham8conv.py --cc "$(CC)"
test-hview: gfx-apps fixtures
	$(PYTHON) tests/prepare_hview.py
	$(CC) -O2 -I$(EMUSRC) tests/test_hview_unidos.c -o $(BUILD)/test_hview_unidos
	$(BUILD)/test_hview_unidos $(BUILD)/hview/sd.img 601
	$(BUILD)/test_hview_unidos $(BUILD)/hview/sd.img 601a
test-hview-app: gfx-apps
	$(PYTHON) tests/prepare_hview.py
	$(PYTHON) tests/run_hview_app.py --nvc "$(NVC)" --unias "$(UNIAS)"

.PHONY: storage-apps test-partitions test-fat16 test-free-space test-mount test-raw-sd test-storage-software
test: test-fat16 test-free-space test-mount
test-fat16: fixtures
	$(CC) -O2 -DEXPECT_FAT_RAMMAN=$(FAT_RAMMAN) -I$(EMUSRC) tests/test_fat16.c -o $(BUILD)/test_fat16
	$(CC) -O2 -I$(EMUSRC) tests/test_fat16_tools.c -o $(BUILD)/test_fat16_tools
	$(CC) -O2 -I$(EMUSRC) tests/test_fdisk_ui.c -o $(BUILD)/test_fdisk_ui
	$(PYTHON) tests/run_fat16.py
test-free-space: fixtures
	$(CC) -O2 -I$(EMUSRC) tests/test_free_space.c -o $(BUILD)/test_free_space
	$(PYTHON) tests/run_free_space.py
test-mount: fixtures
	$(CC) -O2 -I$(EMUSRC) tests/test_mount.c -o $(BUILD)/test_mount
	$(PYTHON) tests/run_mount.py
test-storage-software: fixtures hg-apps romdisk-extract
	$(PYTHON) tests/run_storage_gd.py --cc "$(CC)"
storage-apps: | $(BUILD)
	$(MAKE) -f firmware/Makefile roms storage UNIAS="$(UNIAS)" CC="$(CC)"
test-partitions: fixtures
	$(PYTHON) tests/prepare_partitions.py
	$(CC) -O2 -I$(EMUSRC) tests/test_partitions.c -o $(BUILD)/test_partitions
	@set -e; for model in 601 601a; do for cpu in mc6800 hd6303; do for card in sdhc sdsc; do $(BUILD)/test_partitions $(BUILD)/partitions/sd-test.img $$model $$cpu $$card; done; done; done
test-raw-sd: fixtures
	$(CC) -O2 -I$(EMUSRC) tests/test_raw_sd.c -o $(BUILD)/test_raw_sd
	@set -e; for model in 601 601a; do for cpu in mc6800 hd6303; do for card in sdhc sdsc; do $(BUILD)/test_raw_sd $$model $$cpu $$card; done; done; done

.PHONY: test-boot-partitions
test-boot-partitions: fixtures
	$(PYTHON) tests/prepare_partitions.py
	$(CC) -O2 -I$(EMUSRC) tests/test_boot_partitions.c -o $(BUILD)/test_boot_partitions
	$(PYTHON) tests/run_boot_partitions.py

.PHONY: game-objects
game-objects:
	$(MAKE) -f firmware/Makefile game-objects UNIAS="$(UNIAS)"
