PYTHON ?= python3
IVERILOG ?= iverilog
VVP ?= vvp
NVC ?= nvc
CC ?= cc
NATIVE ?= ../native
EMUSRC ?= ../pyldin601/src
UNIAS ?= unias
HD_TEST_SD ?= build/sd-models/sd-after.img
BUILD := build
RTL := $(wildcard rtl/*.v)
BENCHES := hg frequency_controls timer_tick memory arbiter arbiter_contract boot_ports boot_header spi_registers sram sd keyboard keyboard_queue keyboard_pacing keyboard_layout keyboard_navigation fdc fdc_sd video video_viewport video_mode_switch video_text video_cursor video_underscore pal_timing pal_encoder pal_rgb332 video_colour video_601a transparent_video sram_stress
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
.PHONY: test-setup
test-setup: fixtures
	$(CC) -O2 -I$(EMUSRC) tests/test_firmware.c -o $(BUILD)/test_firmware
	$(PYTHON) tests/run_setup.py
.PHONY: test-sd-init
test-sd-init: fixtures
	$(CC) -O2 -I$(EMUSRC) tests/test_firmware.c -o $(BUILD)/test_firmware
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
	$(PYTHON) tests/prepare_runtime.py
	$(NVC) --std=2008 --work=work:$(BUILD)/runtime-irq --ieee-warnings=off -a rtl/cpu6800.vhd $(RTL) tests/fast_clock.v tests/tb_runtime_irq.v tests/tb_runtime_irq.vhd -e -j tb_runtime_irq -r tb_runtime_irq > $(BUILD)/runtime-irq.log 2>&1
	@cat $(BUILD)/runtime-irq.log
	@$(PYTHON) -c "from pathlib import Path; assert 'PASS actual HDL CPU/native BIOS IRQ' in Path('build/runtime-irq.log').read_text()"

.PHONY: test-keyboard-bios
test-keyboard-bios: test-mixed-clock fixtures $(STABILITY_IMAGE)
	$(CC) -O2 -I$(EMUSRC) tests/prepare_keyboard_bios.c -o $(BUILD)/prepare_keyboard_bios
	@set -e; for model in 601 601a; do $(BUILD)/prepare_keyboard_bios $(STABILITY_IMAGE) $$model; $(NVC) --std=2008 --work=work:$(BUILD)/keyboard-bios-$$model --ieee-warnings=off -a rtl/cpu6800.vhd $(RTL) tests/fast_clock.v tests/tb_keyboard_bios.v tests/tb_keyboard_bios.vhd; for speed in 0 1 2 3; do $(PYTHON) tests/prepare_runtime.py --prefix keyboard --speed $$speed; $(NVC) --std=2008 --work=work:$(BUILD)/keyboard-bios-$$model --ieee-warnings=off -e -j -gSPEED=$$speed tb_keyboard_bios -r tb_keyboard_bios > $(BUILD)/keyboard-bios-$$model-$$speed.log 2>&1; cat $(BUILD)/keyboard-bios-$$model-$$speed.log; $(PYTHON) -c "from pathlib import Path; assert 'PASS actual HDL CPU/native BIOS' in Path('build/keyboard-bios-$$model-$$speed.log').read_text()"; done; done

.PHONY: test-runtime-turbo
test-runtime-turbo: test-mixed-clock fixtures $(STABILITY_IMAGE)
	$(CC) -O2 -I$(EMUSRC) tests/prepare_runtime.c -o $(BUILD)/prepare_runtime
	$(BUILD)/prepare_runtime $(STABILITY_IMAGE) rollover
	$(PYTHON) tests/prepare_runtime.py
	$(NVC) --std=2008 --work=work:$(BUILD)/runtime-turbo --ieee-warnings=off -a rtl/cpu6800.vhd $(RTL) tests/fast_clock.v tests/tb_runtime_irq.v tests/tb_runtime_irq.vhd
	@set -e; for speed in 0 1 2 3; do $(NVC) --std=2008 --work=work:$(BUILD)/runtime-turbo --ieee-warnings=off -e -j -gSPEED=$$speed tb_runtime_irq -r tb_runtime_irq > $(BUILD)/runtime-turbo-$$speed.log 2>&1; cat $(BUILD)/runtime-turbo-$$speed.log; $(PYTHON) -c "from pathlib import Path; assert 'PASS actual HDL CPU/native BIOS IRQ' in Path('build/runtime-turbo-$$speed.log').read_text()"; done

test: test-hd6303 test-python test-rtl test-gfx test-cpu test-cpu-interrupts test-boot-lockstep test-firmware test-setup test-sd-init test-board-syntax test-handoff
firmware: | $(BUILD)
	$(PYTHON) tools/make_ps2.py --source firmware/ps2_set2.csv --output rtl/ps2_set2.mem
	$(PYTHON) tools/make_font.py --source $(NATIVE)/Bios/video.roz --output rtl/font_boot.mem
	$(PYTHON) tools/make_pal.py --output rtl/pal_waveform.mem
	$(PYTHON) tools/make_boot.py
	$(PYTHON) tools/asm6800.py firmware/loader.asm --output $(BUILD)/loader.bin --origin 0x2000
$(BUILD):
	mkdir -p $(BUILD)
test-python:
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
	@set -e; for bench in $(BENCHES); do $(IVERILOG) -g2012 -s tb_$$bench -o $(BUILD)/tb_$$bench $(RTL) tests/sd_test_host.v tests/pal_viewport_reference.v tests/tb_$$bench.v; $(VVP) $(BUILD)/tb_$$bench; done
	$(IVERILOG) -g2012 -s tb_transparent_video -Ptb_transparent_video.MODEL_A=1 -o $(BUILD)/tb_transparent_video-a $(RTL) tests/fast_clock.v tests/tb_transparent_video.v
	$(VVP) $(BUILD)/tb_transparent_video-a
	$(VVP) $(BUILD)/tb_sd +sdsc
	$(VVP) $(BUILD)/tb_sd +badcrc
test-cpu: | $(BUILD)
	$(PYTHON) tests/prepare_cpu.py
	$(CC) -O2 -I$(EMUSRC) tests/test_cpu_reference.c -o $(BUILD)/cpu_reference
	$(BUILD)/cpu_reference $(BUILD)/cpu.bin $(BUILD)/cpu.expected.mem
	$(NVC) --std=2008 --work=work:$(BUILD)/cpu-test --ieee-warnings=off -a rtl/cpu6800.vhd tests/tb_cpu.vhd -e tb_cpu -r tb_cpu
fixtures: firmware
	$(PYTHON) tests/prepare_images.py $(NATIVE) $(BUILD)
test-firmware: fixtures
	$(CC) -O2 -I$(EMUSRC) tests/test_firmware.c -o $(BUILD)/test_firmware
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
image: firmware
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
	$(PYTHON) tools/asm6800.py firmware/sram_test.asm --origin 0xf000 --size 4096 --output $(BUILD)/sram-test.bin --mem $(BUILD)/sram-test.mem
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
test-hd6303: test-cpu test-hd6303-edges
	$(BUILD)/cpu_reference $(BUILD)/cpu.bin $(BUILD)/classic-hd.expected.mem hd6303
	cp $(BUILD)/cpu.mem $(BUILD)/classic-hd.mem
	$(NVC) --std=2008 --work=work:$(BUILD)/cpu-test --ieee-warnings=off -e -gPREFIX=classic-hd -gHD=true tb_cpu -r tb_cpu
	$(PYTHON) tests/prepare_hd6303.py
	$(BUILD)/cpu_reference $(BUILD)/hd6303.bin $(BUILD)/hd6303.expected.mem hd6303
	$(NVC) --std=2008 --work=work:$(BUILD)/cpu-test --ieee-warnings=off -e -gPREFIX=hd6303 -gHD=true -gLAST_RESULT=57343 tb_cpu -r tb_cpu

.PHONY: hd6303-apps test-hd6303-apps hd6303-test-image
hd6303-apps: | $(BUILD)
	$(PYTHON) tools/build_hd6303_tests.py --unias "$(UNIAS)" --output $(BUILD)/hd6303-apps
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
	$(PYTHON) tools/build_hg.py --unias "$(UNIAS)"
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
	$(PYTHON) tools/build_gfx.py --unias "$(UNIAS)"
test-gfx: firmware
	$(IVERILOG) -g2012 -s tb_gfx -o $(BUILD)/tb_gfx $(RTL) tests/fast_clock.v tests/pal_viewport_reference.v tests/tb_gfx.v
	$(VVP) $(BUILD)/tb_gfx
test-gfx-app: gfx-apps
	$(PYTHON) tests/run_gfx_app.py --nvc "$(NVC)"
